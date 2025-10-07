# frozen_string_literal: true

class ShiftDeletion < ApplicationRecord
  include ShiftBase

  validates :requester_id, presence: true
  validates :shift_id, presence: true
  validates :reason, presence: true

  belongs_to :shift

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_requester, ->(requester_id) { where(requester_id: requester_id) }

  def approve!
    approve_status!
  end

  def reject!
    reject_status!
  end

  def self.create_request_for(shift_id:, requester_id:, reason:)
    raise ValidationError, "必須項目が不足しています" if [shift_id, requester_id, reason].any?(&:blank?)

    shift = Shift.find_by(id: shift_id)
    raise ValidationError, "シフトが見つかりません" unless shift

    raise AuthorizationError, "自分のシフトのみ欠勤申請が可能です" unless shift.employee_id == requester_id
    raise ValidationError, "過去のシフトの欠勤申請はできません" if shift.shift_date < Date.current

    existing_request = find_by(shift: shift, status: "pending")
    raise ValidationError, "このシフトは既に申請済みです" if existing_request

    shift_deletion = create!(
      request_id: generate_request_id("DELETION"),
      requester_id: requester_id,
      shift: shift,
      reason: reason,
      status: "pending"
    )

    send_request_notification(shift_deletion) unless Rails.env.test?
    DeletionResult.new(shift_deletion)
  end

  def approve_by!(approver_id)
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      shift.destroy!
      approve_status!
      send_approval_notification unless Rails.env.test?
    end

    "欠勤申請を承認しました"
  end

  def reject_by!(approver_id)
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      reject_status!
      send_rejection_notification unless Rails.env.test?
    end

    "欠勤申請を拒否しました"
  end

  class DeletionResult
    attr_reader :request

    def initialize(request)
      @request = request
    end

    def success_message
      "欠勤申請を送信しました。承認をお待ちください。"
    end

    def send_notifications!
      self
    end
  end

  private

  def self.generate_request_id(prefix = "DELETION")
    super(prefix)
  end

  def self.send_request_notification(shift_deletion)
    send_notification(EmailNotificationService.new, :send_shift_deletion_request_notification, shift_deletion)
  end

  def send_approval_notification
    self.class.send_notification(EmailNotificationService.new, :send_shift_deletion_approval_notification, self)
  end

  def send_rejection_notification
    self.class.send_notification(EmailNotificationService.new, :send_shift_deletion_rejection_notification, self)
  end
end
