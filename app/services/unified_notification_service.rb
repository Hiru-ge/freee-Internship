# frozen_string_literal: true

class UnifiedNotificationService
  def initialize
    @email_service = EmailNotificationService.new
  end

  # シフト交代依頼通知の送信
  def send_shift_exchange_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      # メール通知
      @email_service.send_shift_exchange_request(
        request.requester_id,
        [request.approver_id],
        request.shift.shift_date,
        request.shift.start_time,
        request.shift.end_time
      )

      # LINE通知は無効化
    end
  end

  # シフト追加依頼通知の送信
  def send_shift_addition_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      # メール通知
      @email_service.send_shift_addition_request(
        request.target_employee_id,
        request.shift_date,
        request.start_time,
        request.end_time
      )

      # LINE通知は無効化
    end
  end

  # シフト交代承認通知の送信
  def send_shift_exchange_approval_notification(exchange_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_exchange_approved(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト交代承認通知送信エラー: #{e.message}"
    end
  end

  # シフト交代拒否通知の送信
  def send_shift_exchange_rejection_notification(exchange_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_exchange_denied(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト交代拒否通知送信エラー: #{e.message}"
    end
  end

  # シフト追加承認通知の送信
  def send_shift_addition_approval_notification(addition_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_addition_approved(
        addition_request.requester_id,
        addition_request.target_employee_id,
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト追加承認通知送信エラー: #{e.message}"
    end
  end

  # シフト追加拒否通知の送信
  def send_shift_addition_rejection_notification(addition_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_addition_denied(
        addition_request.requester_id,
        addition_request.target_employee_id,
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト追加拒否通知送信エラー: #{e.message}"
    end
  end

  # 欠勤申請通知の送信
  def send_shift_deletion_request_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_deletion_request(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time,
        deletion_request.reason
      )
    rescue StandardError => e
      Rails.logger.error "欠勤申請通知送信エラー: #{e.message}"
    end
  end

  # 欠勤申請承認通知の送信
  def send_shift_deletion_approval_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_deletion_approved(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "欠勤申請承認通知送信エラー: #{e.message}"
    end
  end

  # 欠勤申請拒否通知の送信
  def send_shift_deletion_rejection_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      @email_service.send_shift_deletion_denied(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "欠勤申請拒否通知送信エラー: #{e.message}"
    end
  end

  # メール通知のみの送信
  def send_email_only(notification_type, *)
    case notification_type
    when :shift_exchange_request
      @email_service.send_shift_exchange_request(*)
    when :shift_addition_request
      @email_service.send_shift_addition_request(*)
    when :shift_exchange_approved
      @email_service.send_shift_exchange_approved(*)
    when :shift_exchange_denied
      @email_service.send_shift_exchange_denied(*)
    when :shift_addition_approved
      @email_service.send_shift_addition_approved(*)
    when :shift_addition_denied
      @email_service.send_shift_addition_denied(*)
    end
  end

  # LINE通知のみの送信
  def send_line_only(notification_type, *)
    case notification_type
    when :shift_exchange_request
      # LINE通知は無効化
    when :shift_addition_request
      # LINE通知は無効化
    when :shift_exchange_approval
      # LINE通知は無効化
    when :shift_addition_approval
      # LINE通知は無効化
    when :shift_addition_rejection
      # LINE通知は無効化
    end
  end
end
