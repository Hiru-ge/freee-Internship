# frozen_string_literal: true

class ShiftDeletionService
  def initialize
    @notification_service = EmailNotificationService.new
  end

  # 欠勤申請の作成
  def create_deletion_request(shift_id, requester_id, reason)
    shift = Shift.find(shift_id)

    # 申請者のシフトかどうかチェック
    unless shift.employee_id == requester_id
      return { success: false, message: "自分のシフトのみ欠勤申請が可能です" }
    end

    # 過去のシフトの欠勤申請を防ぐ
    if shift.shift_date < Date.current
      return { success: false, message: "過去のシフトの欠勤申請はできません。" }
    end

    # 既に申請済みかチェック
    existing_request = ShiftDeletion.find_by(shift: shift, status: "pending")
    if existing_request
      return { success: false, message: "このシフトは既に申請済みです" }
    end

    # 欠勤申請を作成
    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_#{SecureRandom.hex(8)}",
      requester_id: requester_id,
      shift: shift,
      reason: reason,
      status: "pending"
    )

    # 通知を送信
    @notification_service.send_shift_deletion_request_notification(shift_deletion)

    { success: true, message: "欠勤申請を送信しました。承認をお待ちください。", shift_deletion: shift_deletion }
  rescue StandardError => e
    Rails.logger.error "欠勤申請作成エラー: #{e.message}"
    { success: false, message: "欠勤申請の送信に失敗しました" }
  end

  # 欠勤申請の承認
  def approve_deletion_request(request_id, approver_id)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    unless shift_deletion
      return { success: false, message: "リクエストが見つかりません" }
    end

    unless shift_deletion.pending?
      return { success: false, message: "このリクエストは既に処理済みです" }
    end

    # シフトを削除
    shift = shift_deletion.shift
    shift.destroy!

    # 申請を承認
    shift_deletion.approve!

    # 通知を送信
    @notification_service.send_shift_deletion_approval_notification(shift_deletion)

    { success: true, message: "欠勤申請を承認しました。" }
  rescue StandardError => e
    Rails.logger.error "欠勤申請承認エラー: #{e.message}"
    { success: false, message: "承認処理に失敗しました" }
  end

  # 欠勤申請の拒否
  def reject_deletion_request(request_id, approver_id)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    unless shift_deletion
      return { success: false, message: "リクエストが見つかりません" }
    end

    unless shift_deletion.pending?
      return { success: false, message: "このリクエストは既に処理済みです" }
    end

    # 申請を拒否
    shift_deletion.reject!

    # 通知を送信
    @notification_service.send_shift_deletion_rejection_notification(shift_deletion)

    { success: true, message: "欠勤申請を拒否しました。" }
  rescue StandardError => e
    Rails.logger.error "欠勤申請拒否エラー: #{e.message}"
    { success: false, message: "拒否処理に失敗しました" }
  end
end
