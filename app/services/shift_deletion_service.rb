class ShiftDeletionService
  def initialize
    @notification_service = EmailNotificationService.new
  end
  def create_deletion_request(shift_id, requester_id, reason)
    shift = Shift.find(shift_id)
    unless shift.employee_id == requester_id
      return { success: false, message: "自分のシフトのみ欠勤申請が可能です" }
    end
    if shift.shift_date < Date.current
      return { success: false, message: "過去のシフトの欠勤申請はできません。" }
    end
    existing_request = ShiftDeletion.find_by(shift: shift, status: "pending")
    if existing_request
      return { success: false, message: "このシフトは既に申請済みです" }
    end
    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_#{SecureRandom.hex(8)}",
      requester_id: requester_id,
      shift: shift,
      reason: reason,
      status: "pending"
    )
    @notification_service.send_shift_deletion_request_notification(shift_deletion)

    { success: true, message: "欠勤申請を送信しました。承認をお待ちください。", shift_deletion: shift_deletion }
  rescue StandardError => e
    Rails.logger.error "欠勤申請作成エラー: #{e.message}"
    { success: false, message: "欠勤申請の送信に失敗しました" }
  end
  def approve_deletion_request(request_id, approver_id)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    unless shift_deletion
      return { success: false, message: "リクエストが見つかりません" }
    end

    unless shift_deletion.pending?
      return { success: false, message: "このリクエストは既に処理済みです" }
    end
    shift = shift_deletion.shift
    shift.destroy!
    shift_deletion.approve!
    @notification_service.send_shift_deletion_approval_notification(shift_deletion)

    { success: true, message: "欠勤申請を承認しました。" }
  rescue StandardError => e
    Rails.logger.error "欠勤申請承認エラー: #{e.message}"
    { success: false, message: "承認処理に失敗しました" }
  end
  def reject_deletion_request(request_id, approver_id)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    unless shift_deletion
      return { success: false, message: "リクエストが見つかりません" }
    end

    unless shift_deletion.pending?
      return { success: false, message: "このリクエストは既に処理済みです" }
    end
    shift_deletion.reject!
    @notification_service.send_shift_deletion_rejection_notification(shift_deletion)

    { success: true, message: "欠勤申請を拒否しました。" }
  rescue StandardError => e
    Rails.logger.error "欠勤申請拒否エラー: #{e.message}"
    { success: false, message: "拒否処理に失敗しました" }
  end
end
