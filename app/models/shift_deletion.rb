# frozen_string_literal: true

class ShiftDeletion < ApplicationRecord
  include ShiftBase
  
  # カスタム例外クラス
  class ValidationError < StandardError; end
  class AuthorizationError < StandardError; end

  validates :request_id, presence: true, uniqueness: true
  validates :requester_id, presence: true
  validates :shift_id, presence: true
  validates :reason, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }

  belongs_to :shift

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_requester, ->(requester_id) { where(requester_id: requester_id) }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def approve!
    update!(status: "approved", responded_at: Time.current)
  end

  def reject!
    update!(status: "rejected", responded_at: Time.current)
  end

  # クラスメソッド: 欠勤申請作成（サービス層から移行）
  def self.create_request_for(shift_id:, requester_id:, reason:)
    # バリデーション
    raise ValidationError, "必須項目が不足しています" if [shift_id, requester_id, reason].any?(&:blank?)

    # シフト取得
    shift = Shift.find_by(id: shift_id)
    raise ValidationError, "シフトが見つかりません" unless shift

    # 権限チェック
    raise AuthorizationError, "自分のシフトのみ欠勤申請が可能です" unless shift.employee_id == requester_id

    # 過去日付チェック
    raise ValidationError, "過去のシフトの欠勤申請はできません" if shift.shift_date < Date.current

    # 既存リクエストチェック
    existing_request = find_by(shift: shift, status: "pending")
    raise ValidationError, "このシフトは既に申請済みです" if existing_request

    # リクエスト作成
    shift_deletion = create!(
      request_id: generate_request_id("DELETION"),
      requester_id: requester_id,
      shift: shift,
      reason: reason,
      status: "pending"
    )

    # 通知送信
    send_request_notification(shift_deletion) unless Rails.env.test?

    # 結果オブジェクトを返す
    DeletionResult.new(shift_deletion)
  end

  # インスタンスメソッド: 承認処理（サービス層から移行）
  def approve_by!(approver_id)
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      # シフト削除
      shift.destroy!

      # ステータス更新
      update!(status: "approved", responded_at: Time.current)

      # 通知送信
      send_approval_notification unless Rails.env.test?
    end

    "欠勤申請を承認しました"
  end

  # インスタンスメソッド: 拒否処理（サービス層から移行）
  def reject_by!(approver_id)
    raise ValidationError, "このリクエストは既に処理済みです" unless pending?

    transaction do
      # ステータス更新
      update!(status: "rejected", responded_at: Time.current)

      # 通知送信
      send_rejection_notification unless Rails.env.test?
    end

    "欠勤申請を拒否しました"
  end

  # 結果オブジェクト
  class DeletionResult
    attr_reader :request

    def initialize(request)
      @request = request
    end

    def success_message
      "欠勤申請を送信しました。承認をお待ちください。"
    end

    def send_notifications!
      # 通知は既にcreate_request_for内で送信済み
      self
    end
  end

  private

  # クラスメソッド: リクエストID生成
  def self.generate_request_id(prefix = "DELETION")
    "#{prefix}_#{SecureRandom.hex(8)}"
  end

  # クラスメソッド: リクエスト通知送信
  def self.send_request_notification(shift_deletion)
    EmailNotificationService.new.send_shift_deletion_request_notification(shift_deletion)
  rescue StandardError => e
    Rails.logger.error "欠勤申請通知送信エラー: #{e.message}"
  end

  # インスタンスメソッド: 承認通知送信
  def send_approval_notification
    EmailNotificationService.new.send_shift_deletion_approval_notification(self)
  rescue StandardError => e
    Rails.logger.error "欠勤申請承認通知送信エラー: #{e.message}"
  end

  # インスタンスメソッド: 拒否通知送信
  def send_rejection_notification
    EmailNotificationService.new.send_shift_deletion_rejection_notification(self)
  rescue StandardError => e
    Rails.logger.error "欠勤申請拒否通知送信エラー: #{e.message}"
  end
end
