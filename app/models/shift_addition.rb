# frozen_string_literal: true

class ShiftAddition < ApplicationRecord
  # カスタム例外クラス
  class ValidationError < StandardError; end
  class AuthorizationError < StandardError; end

  validates :request_id, presence: true, uniqueness: true
  validates :target_employee_id, presence: true
  validates :shift_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }

  validate :end_time_after_start_time
  validate :future_date_only
  validate :no_shift_overlap, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_employee, ->(employee_id) { where(target_employee_id: employee_id) }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  # クラスメソッド: リクエスト作成（サービス層から移行）
  def self.create_request_for(requester_id:, target_employee_ids:, shift_date:, start_time:, end_time:)
    # バリデーション
    raise ValidationError, "必須項目が不足しています" if [requester_id, shift_date, start_time, end_time].any?(&:blank?)
    raise ValidationError, "対象従業員を選択してください" if target_employee_ids.blank? || target_employee_ids.empty?

    # 日付・時間の解析
    parsed_date = Date.parse(shift_date.to_s)
    parsed_start_time = Time.zone.parse(start_time.to_s)
    parsed_end_time = Time.zone.parse(end_time.to_s)

    # 過去日付チェック
    raise ValidationError, "過去の日付は指定できません" if parsed_date < Date.current

    # 時間の妥当性チェック
    raise ValidationError, "終了時間は開始時間より後である必要があります" if parsed_end_time <= parsed_start_time

    created_requests = []
    overlapping_employees = []

    target_employee_ids.each do |target_employee_id|
      # 重複チェック
      if has_shift_overlap?(target_employee_id, parsed_date, parsed_start_time, parsed_end_time)
        employee_name = get_employee_display_name(target_employee_id)
        overlapping_employees << employee_name
        next
      end

      # 既存リクエストチェック
      existing_request = find_by(
        requester_id: requester_id,
        target_employee_id: target_employee_id,
        shift_date: parsed_date,
        start_time: parsed_start_time,
        end_time: parsed_end_time,
        status: %w[pending approved]
      )
      next if existing_request

      # リクエスト作成
      request = create!(
        request_id: generate_request_id("ADDITION"),
        requester_id: requester_id,
        target_employee_id: target_employee_id,
        shift_date: parsed_date,
        start_time: parsed_start_time,
        end_time: parsed_end_time,
        status: "pending"
      )
      created_requests << request
    end

    raise ValidationError, "送信可能な対象者がいません" if created_requests.empty?

    # 通知送信
    self.send_request_notifications(created_requests) unless Rails.env.test?

    # 結果オブジェクトを返す
    RequestResult.new(created_requests, overlapping_employees)
  end

  # インスタンスメソッド: 承認処理（サービス層から移行）
  def approve_by!(approver_id)
    raise AuthorizationError, "このリクエストを承認する権限がありません" unless target_employee_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      # シフト作成
      Shift.create!(
        employee_id: target_employee_id,
        shift_date: shift_date,
        start_time: start_time,
        end_time: end_time
      )

      # ステータス更新
      update!(status: "approved", responded_at: Time.current)

      # 通知送信
      send_approval_notification unless Rails.env.test?
    end

    "シフト追加を承認しました"
  end

  # インスタンスメソッド: 拒否処理（サービス層から移行）
  def reject_by!(approver_id)
    raise AuthorizationError, "このリクエストを拒否する権限がありません" unless target_employee_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      # ステータス更新
      update!(status: "rejected", responded_at: Time.current)

      # 通知送信
      send_rejection_notification unless Rails.env.test?
    end

    "シフト追加を拒否しました"
  end

  # 結果オブジェクト
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
      # 通知は既にcreate_request_for内で送信済み
      self
    end
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    return unless end_time <= start_time

    errors.add(:end_time, "終了時間は開始時間より後である必要があります")
  end

  def future_date_only
    return unless shift_date

    return unless shift_date < Date.current

    errors.add(:shift_date, "過去の日付は指定できません")
  end

  def no_shift_overlap
    return unless target_employee_id && shift_date && start_time && end_time

    return unless self.class.has_shift_overlap?(target_employee_id, shift_date, start_time, end_time)

    errors.add(:base, "指定時間に既存のシフトが重複しています")
  end

  # クラスメソッド: 重複チェック
  def self.has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    existing_shifts.any? do |shift|
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
  end

  # クラスメソッド: 従業員名取得
  def self.get_employee_display_name(employee_id)
    employee = Employee.find_by(employee_id: employee_id)
    employee&.display_name || "ID: #{employee_id}"
  end

  # クラスメソッド: リクエストID生成
  def self.generate_request_id(prefix = "ADDITION")
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # クラスメソッド: 通知送信
  def self.send_request_notifications(requests)
    notification_service = EmailNotificationService.new
    notification_service.send_shift_addition_request_notification(requests, {})
  rescue StandardError => e
    Rails.logger.warn "シフト追加通知メール送信スキップ: #{e.message}"
  end

  def send_approval_notification
    notification_service = EmailNotificationService.new
    notification_service.send_shift_addition_approval_notification(self)
  rescue StandardError => e
    Rails.logger.warn "シフト追加承認通知メール送信スキップ: #{e.message}"
  end

  def send_rejection_notification
    notification_service = EmailNotificationService.new
    notification_service.send_shift_addition_rejection_notification(self)
  rescue StandardError => e
    Rails.logger.warn "シフト追加拒否通知メール送信スキップ: #{e.message}"
  end
end
