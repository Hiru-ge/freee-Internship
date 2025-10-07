# frozen_string_literal: true

class ShiftAddition < ApplicationRecord
  include ShiftBase

  validates :target_employee_id, presence: true
  validate :no_shift_overlap_validation, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_employee, ->(employee_id) { where(target_employee_id: employee_id) }

  def self.create_request_for(requester_id:, target_employee_ids:, shift_date:, start_time:, end_time:)
    raise ShiftBase::ValidationError, "必須項目が不足しています" if [requester_id, shift_date, start_time, end_time].any?(&:blank?)
    raise ShiftBase::ValidationError, "対象従業員を選択してください" if target_employee_ids.blank? || target_employee_ids.empty?

    parsed_data = parse_date_and_times(shift_date, start_time, end_time)
    validate_future_date(parsed_data[:date])
    validate_time_consistency(parsed_data[:start_time], parsed_data[:end_time])

    created_requests = []
    overlapping_employees = []

    target_employee_ids.each do |target_employee_id|
      if has_shift_overlap?(target_employee_id, parsed_data[:date], parsed_data[:start_time], parsed_data[:end_time])
        overlapping_employees << get_employee_display_name(target_employee_id)
        next
      end

      existing_request = find_by(
        requester_id: requester_id,
        target_employee_id: target_employee_id,
        shift_date: parsed_data[:date],
        start_time: parsed_data[:start_time],
        end_time: parsed_data[:end_time],
        status: %w[pending approved]
      )
      next if existing_request

      request = create!(
        request_id: generate_request_id("ADDITION"),
        requester_id: requester_id,
        target_employee_id: target_employee_id,
        shift_date: parsed_data[:date],
        start_time: parsed_data[:start_time],
        end_time: parsed_data[:end_time],
        status: "pending"
      )
      created_requests << request
    end

    raise ValidationError, "送信可能な対象者がいません" if created_requests.empty?

    send_request_notifications(created_requests) unless Rails.env.test?
    RequestResult.new(created_requests, overlapping_employees)
  end

  def approve_by!(approver_id)
    raise AuthorizationError, "このリクエストを承認する権限がありません" unless target_employee_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      Shift.create!(
        employee_id: target_employee_id,
        shift_date: shift_date,
        start_time: start_time,
        end_time: end_time
      )

      approve_status!
      send_approval_notification unless Rails.env.test?
    end

    "シフト追加を承認しました"
  end

  def reject_by!(approver_id)
    raise AuthorizationError, "このリクエストを拒否する権限がありません" unless target_employee_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      reject_status!
      send_rejection_notification unless Rails.env.test?
    end

    "シフト追加を拒否しました"
  end

  class RequestResult
    attr_reader :requests, :overlapping_employees

    def initialize(requests, overlapping_employees = [])
      @requests = requests
      @overlapping_employees = overlapping_employees
    end

    def success_message
      if overlapping_employees.any?
        "リクエストを送信しました。一部の従業員（#{overlapping_employees.join(', ')}）は指定時間にシフトが入っているため、依頼可能な従業員のみに送信されました。"
      else
        "シフト追加リクエストを送信しました。承認をお待ちください。"
      end
    end

    def send_notifications!
      self
    end
  end

  private

  def self.generate_request_id(prefix = "ADDITION")
    super(prefix)
  end

  def self.send_request_notifications(requests)
    send_notification(EmailNotificationService.new, :send_shift_addition_request_notification, requests, {})
  end

  def send_approval_notification
    self.class.send_notification(EmailNotificationService.new, :send_shift_addition_approval_notification, self)
  end

  def send_rejection_notification
    self.class.send_notification(EmailNotificationService.new, :send_shift_addition_rejection_notification, self)
  end
end
