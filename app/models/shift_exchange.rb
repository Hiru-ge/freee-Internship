# frozen_string_literal: true

class ShiftExchange < ApplicationRecord
  include ShiftBase

  validates :requester_id, presence: true
  validates :approver_id, presence: true

  belongs_to :shift, optional: true

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :for_requester, ->(requester_id) { where(requester_id: requester_id) }
  scope :for_approver, ->(approver_id) { where(approver_id: approver_id) }

  def self.create_request_for(applicant_id:, approver_ids:, shift_date:, start_time:, end_time:)
    raise ValidationError, "必須項目が不足しています" if [applicant_id, shift_date, start_time, end_time].any?(&:blank?)
    raise ValidationError, "交代を依頼する相手を選択してください" if approver_ids.blank? || approver_ids.empty?

    parsed_data = parse_date_and_times(shift_date, start_time, end_time)
    validate_future_date(parsed_data[:date])
    validate_time_consistency(parsed_data[:start_time], parsed_data[:end_time])

    shift = find_or_create_shift(applicant_id, parsed_data[:date], parsed_data[:start_time], parsed_data[:end_time])

    available_approver_ids = []
    overlapping_employees = []
    existing_approver_names = []

    approver_ids.each do |approver_id|
      if has_shift_overlap?(approver_id, parsed_data[:date], parsed_data[:start_time], parsed_data[:end_time])
        overlapping_employees << get_employee_display_name(approver_id)
        next
      end

      existing_request = find_by(
        requester_id: applicant_id,
        approver_id: approver_id,
        shift_id: shift.id,
        status: "pending"
      )

      if existing_request
        existing_approver_names << get_employee_display_name(approver_id)
        next
      end

      available_approver_ids << approver_id
    end

    if available_approver_ids.empty?
      if existing_approver_names.any?
        raise ValidationError, "選択された従業員は全員、既に同じ時間帯のシフト交代依頼が存在します: #{existing_approver_names.join(', ')}"
      else
        raise ValidationError, "送信可能な承認者がいません"
      end
    end

    created_requests = []
    available_approver_ids.each do |approver_id|
      request = create!(
        request_id: generate_request_id("EXCHANGE"),
        requester_id: applicant_id,
        approver_id: approver_id,
        shift_id: shift.id,
        status: "pending"
      )
      created_requests << request
    end

    send_exchange_notifications(created_requests) unless Rails.env.test?
    ExchangeResult.new(created_requests, overlapping_employees, existing_approver_names)
  end

  def approve_by!(approver_id)
    raise AuthorizationError, "このリクエストを承認する権限がありません" unless self.approver_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?
    raise ValidationError, "シフトが削除されているため、承認できません" unless shift

    transaction do
      Shift.create!(
        employee_id: approver_id,
        shift_date: shift.shift_date,
        start_time: shift.start_time,
        end_time: shift.end_time
      )

      ShiftExchange.where(shift_id: shift.id).update_all(shift_id: nil)

      shift_date = shift.shift_date
      shift.destroy!

      approve_status!

      other_requests = ShiftExchange.joins(:shift)
        .where(
          requester_id: requester_id,
          status: "pending",
          shifts: {
            shift_date: shift.shift_date,
            start_time: shift.start_time,
            end_time: shift.end_time
          }
        ).where.not(id: id)
        .where.not(shift_id: nil)

      other_requests.update_all(
        status: "rejected",
        responded_at: Time.current
      )

      send_approval_notification unless Rails.env.test?

      "シフト交代リクエストを承認しました。#{shift_date&.strftime('%m/%d')}"
    end
  end

  def reject_by!(approver_id)
    raise AuthorizationError, "このリクエストを拒否する権限がありません" unless self.approver_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      reject_status!
      send_rejection_notification unless Rails.env.test?
    end

    "シフト交代リクエストを拒否しました"
  end

  def cancel_by!(requester_id)
    raise AuthorizationError, "このリクエストをキャンセルする権限がありません" unless self.requester_id == requester_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      cancel_status!
    end

    "シフト交代リクエストをキャンセルしました"
  end

  class ExchangeResult
    attr_reader :requests, :overlapping_employees, :existing_approver_names

    def initialize(requests, overlapping_employees = [], existing_approver_names = [])
      @requests = requests
      @overlapping_employees = overlapping_employees
      @existing_approver_names = existing_approver_names
    end

    def success_message
      messages = []

      if overlapping_employees.any?
        messages << "一部の従業員（#{overlapping_employees.join(', ')}）は指定時間にシフトが入っているため、依頼できませんでした。"
      end

      if existing_approver_names.any?
        messages << "一部の従業員（#{existing_approver_names.join(', ')}）には既に同じ時間帯のシフト交代依頼が存在するため、依頼できませんでした。"
      end

      if messages.any?
        "リクエストを送信しました。#{messages.join(' ')}依頼可能な従業員のみに送信されました。"
      else
        "リクエストを送信しました。承認をお待ちください。"
      end
    end

    def send_notifications!
      self
    end
  end

  private

  def self.find_or_create_shift(applicant_id, shift_date, start_time, end_time)
    shift = Shift.find_by(
      employee_id: applicant_id,
      shift_date: shift_date,
      start_time: start_time,
      end_time: end_time
    )

    shift ||= Shift.create!(
      employee_id: applicant_id,
      shift_date: shift_date,
      start_time: start_time,
      end_time: end_time
    )

    shift
  end

  def self.generate_request_id(prefix = "EXCHANGE")
    super(prefix)
  end

  def self.send_exchange_notifications(requests)
    send_notification(EmailNotificationService.new, :send_shift_exchange_request_notification, requests, {})
  end

  def send_approval_notification
    return unless shift
    self.class.send_notification(EmailNotificationService.new, :send_shift_exchange_approval_notification, self)
  end

  def send_rejection_notification
    return unless shift
    self.class.send_notification(EmailNotificationService.new, :send_shift_exchange_rejection_notification, self)
  end
end
