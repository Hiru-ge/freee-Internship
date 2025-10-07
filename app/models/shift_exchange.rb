# frozen_string_literal: true

class ShiftExchange < ApplicationRecord
  # カスタム例外クラス
  class ValidationError < StandardError; end
  class AuthorizationError < StandardError; end

  validates :request_id, presence: true, uniqueness: true
  validates :requester_id, presence: true
  validates :approver_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected cancelled] }

  belongs_to :shift, optional: true

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :for_requester, ->(requester_id) { where(requester_id: requester_id) }
  scope :for_approver, ->(approver_id) { where(approver_id: approver_id) }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def cancelled?
    status == "cancelled"
  end

  # クラスメソッド: リクエスト作成（サービス層から移行）
  def self.create_request_for(applicant_id:, approver_ids:, shift_date:, start_time:, end_time:)
    # バリデーション
    raise ValidationError, "必須項目が不足しています" if [applicant_id, shift_date, start_time, end_time].any?(&:blank?)
    raise ValidationError, "交代を依頼する相手を選択してください" if approver_ids.blank? || approver_ids.empty?

    # 日付・時間の解析
    parsed_date = Date.parse(shift_date.to_s)
    parsed_start_time = Time.zone.parse(start_time.to_s)
    parsed_end_time = Time.zone.parse(end_time.to_s)

    # 過去日付チェック
    raise ValidationError, "過去の日付のシフト交代依頼はできません" if parsed_date < Date.current

    # 時間の妥当性チェック
    raise ValidationError, "終了時間は開始時間より後である必要があります" if parsed_end_time <= parsed_start_time

    # シフトを検索または作成
    shift = find_or_create_shift(applicant_id, parsed_date, parsed_start_time, parsed_end_time)

    # 重複チェック
    available_approver_ids = []
    overlapping_employees = []
    existing_approver_names = []

    approver_ids.each do |approver_id|
      # 重複チェック
      if has_shift_overlap?(approver_id, parsed_date, parsed_start_time, parsed_end_time)
        employee_name = get_employee_display_name(approver_id)
        overlapping_employees << employee_name
        next
      end

      # 既存リクエストチェック
      existing_request = find_by(
        requester_id: applicant_id,
        approver_id: approver_id,
        shift_id: shift.id,
        status: "pending"
      )

      if existing_request
        employee_name = get_employee_display_name(approver_id)
        existing_approver_names << employee_name
        next
      end

      available_approver_ids << approver_id
    end

    # 送信可能な承認者がいない場合
    if available_approver_ids.empty?
      if existing_approver_names.any?
        raise ValidationError, "選択された従業員は全員、既に同じ時間帯のシフト交代依頼が存在します: #{existing_approver_names.join(', ')}"
      else
        raise ValidationError, "送信可能な承認者がいません"
      end
    end

    # リクエスト作成
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

    # 通知送信
    send_exchange_notifications(created_requests) unless Rails.env.test?

    # 結果オブジェクトを返す
    ExchangeResult.new(created_requests, overlapping_employees, existing_approver_names)
  end

  # インスタンスメソッド: 承認処理（サービス層から移行）
  def approve_by!(approver_id)
    raise AuthorizationError, "このリクエストを承認する権限がありません" unless self.approver_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?
    raise ValidationError, "シフトが削除されているため、承認できません" unless shift

    transaction do
      # 同一時間帯のシフトを承認者に作成（付け替え）
      Shift.create!(
        employee_id: approver_id,
        shift_date: shift.shift_date,
        start_time: shift.start_time,
        end_time: shift.end_time
      )

      # 元のシフトのshift_idを他のリクエストからクリア
      ShiftExchange.where(shift_id: shift.id).update_all(shift_id: nil)

      # 元のシフトを削除
      shift_date = shift.shift_date
      shift.destroy!

      # ステータス更新
      update!(status: "approved", responded_at: Time.current)

      # 同じ申請者の他の pending リクエストを拒否
      ShiftExchange.where(
        requester_id: requester_id,
        shift_id: nil,
        status: "pending"
      ).where.not(id: id).each(&:reject!)

      # 通知送信
      send_approval_notification unless Rails.env.test?

      "シフト交代リクエストを承認しました。#{shift_date&.strftime('%m/%d')}"
    end
  end

  # インスタンスメソッド: 拒否処理（サービス層から移行）
  def reject_by!(approver_id)
    raise AuthorizationError, "このリクエストを拒否する権限がありません" unless self.approver_id == approver_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      # ステータス更新
      update!(status: "rejected", responded_at: Time.current)

      # 通知送信
      send_rejection_notification unless Rails.env.test?
    end

    "シフト交代リクエストを拒否しました"
  end

  # インスタンスメソッド: キャンセル処理（サービス層から移行）
  def cancel_by!(requester_id)
    raise AuthorizationError, "このリクエストをキャンセルする権限がありません" unless self.requester_id == requester_id
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      # ステータス更新
      update!(status: "cancelled", responded_at: Time.current)
    end

    "シフト交代リクエストをキャンセルしました"
  end

  # 結果オブジェクト
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
      # 通知は既にcreate_request_for内で送信済み
      self
    end
  end

  private

  # クラスメソッド: シフト検索または作成
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
  def self.generate_request_id(prefix = "EXCHANGE")
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # クラスメソッド: 通知送信
  def self.send_exchange_notifications(requests)
    notification_service = EmailNotificationService.new
    notification_service.send_shift_exchange_request_notification(requests, {})
  rescue StandardError => e
    Rails.logger.warn "シフト交代通知メール送信スキップ: #{e.message}"
  end

  # 通知メソッド
  def send_approval_notification
    return unless shift

    notification_service = EmailNotificationService.new
    notification_service.send_shift_exchange_approval_notification(self)
  rescue StandardError => e
    Rails.logger.warn "シフト交代承認通知メール送信スキップ: #{e.message}"
  end

  def send_rejection_notification
    return unless shift

    notification_service = EmailNotificationService.new
    notification_service.send_shift_exchange_rejection_notification(self)
  rescue StandardError => e
    Rails.logger.warn "シフト交代拒否通知メール送信スキップ: #{e.message}"
  end
end
