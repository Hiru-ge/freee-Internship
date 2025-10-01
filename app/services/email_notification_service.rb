# frozen_string_literal: true

# メール通知サービス
# シフト管理システムのメール通知を一元管理
class EmailNotificationService
  def initialize
    @freee_service = FreeeApiService.new(ENV.fetch("FREEE_ACCESS_TOKEN", nil), ENV.fetch("FREEE_COMPANY_ID", nil))
  end

  # ===== シフト交代通知 =====

  # シフト交代依頼通知の送信
  def send_shift_exchange_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      # メール通知
      send_shift_exchange_request_email(
        request.requester_id,
        [request.approver_id],
        request.shift.shift_date,
        request.shift.start_time,
        request.shift.end_time
      )
    end
  end

  # シフト交代承認通知の送信
  def send_shift_exchange_approval_notification(exchange_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_exchange_approved_email(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト交代承認通知送信エラー: #{e.message}"
    end
  end

  # シフト交代拒否通知の送信
  def send_shift_exchange_rejection_notification(exchange_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_exchange_denied_email(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト交代拒否通知送信エラー: #{e.message}"
    end
  end

  # ===== シフト追加通知 =====

  # シフト追加依頼通知の送信
  def send_shift_addition_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      # メール通知
      send_shift_addition_request_email(
        request.target_employee_id,
        request.shift_date,
        request.start_time,
        request.end_time
      )
    end
  end

  # シフト追加承認通知の送信
  def send_shift_addition_approval_notification(addition_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_addition_approved_email(
        addition_request.requester_id,
        addition_request.target_employee_id,
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト追加承認通知送信エラー: #{e.message}"
    end
  end

  # シフト追加拒否通知の送信
  def send_shift_addition_rejection_notification(addition_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_addition_denied_email(
        addition_request.requester_id,
        addition_request.target_employee_id,
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト追加拒否通知送信エラー: #{e.message}"
    end
  end

  # ===== シフト削除通知 =====

  # シフト削除依頼通知の送信
  def send_shift_deletion_request_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_deletion_request_email(
        deletion_request.employee_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time,
        deletion_request.reason
      )
    rescue StandardError => e
      Rails.logger.error "シフト削除依頼通知送信エラー: #{e.message}"
    end
  end

  # シフト削除承認通知の送信
  def send_shift_deletion_approval_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_deletion_approved_email(
        deletion_request.employee_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト削除承認通知送信エラー: #{e.message}"
    end
  end

  # シフト削除拒否通知の送信
  def send_shift_deletion_rejection_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_deletion_denied_email(
        deletion_request.employee_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト削除拒否通知送信エラー: #{e.message}"
    end
  end

  # ===== 認証通知 =====

  # 認証コード送信通知
  def send_verification_code_notification(employee_id, employee_name)
    return if Rails.env.test?

    begin
      # メール通知
      send_verification_code_email(employee_id, employee_name)
    rescue StandardError => e
      Rails.logger.error "認証コード通知送信エラー: #{e.message}"
    end
  end

  # ===== メール送信メソッド =====

  private

  # シフト交代依頼メール送信
  def send_shift_exchange_request_email(requester_id, approver_ids, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    return unless requester

    approver_ids.each do |approver_id|
      approver = Employee.find_by(employee_id: approver_id)
      next unless approver

      ShiftMailer.shift_exchange_request(
        requester,
        approver,
        shift_date,
        start_time,
        end_time
      ).deliver_now
    end
  end

  # シフト交代承認メール送信
  def send_shift_exchange_approved_email(requester_id, approver_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    approver = Employee.find_by(employee_id: approver_id)
    return unless requester && approver

    ShiftMailer.shift_exchange_approved(
      requester,
      approver,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # シフト交代拒否メール送信
  def send_shift_exchange_denied_email(requester_id, approver_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    approver = Employee.find_by(employee_id: approver_id)
    return unless requester && approver

    ShiftMailer.shift_exchange_denied(
      requester,
      approver,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # シフト追加依頼メール送信
  def send_shift_addition_request_email(target_employee_id, shift_date, start_time, end_time)
    target_employee = Employee.find_by(employee_id: target_employee_id)
    return unless target_employee

    ShiftMailer.shift_addition_request(
      target_employee,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # シフト追加承認メール送信
  def send_shift_addition_approved_email(requester_id, target_employee_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    target_employee = Employee.find_by(employee_id: target_employee_id)
    return unless requester && target_employee

    ShiftMailer.shift_addition_approved(
      requester,
      target_employee,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # シフト追加拒否メール送信
  def send_shift_addition_denied_email(requester_id, target_employee_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    target_employee = Employee.find_by(employee_id: target_employee_id)
    return unless requester && target_employee

    ShiftMailer.shift_addition_denied(
      requester,
      target_employee,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # シフト削除依頼メール送信
  def send_shift_deletion_request_email(employee_id, shift_date, start_time, end_time, reason)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    ShiftMailer.shift_deletion_request(
      employee,
      shift_date,
      start_time,
      end_time,
      reason
    ).deliver_now
  end

  # シフト削除承認メール送信
  def send_shift_deletion_approved_email(employee_id, shift_date, start_time, end_time)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    ShiftMailer.shift_deletion_approved(
      employee,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # シフト削除拒否メール送信
  def send_shift_deletion_denied_email(employee_id, shift_date, start_time, end_time)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    ShiftMailer.shift_deletion_denied(
      employee,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  # 認証コードメール送信
  def send_verification_code_email(employee_id, employee_name)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    AuthMailer.verification_code(employee, employee_name).deliver_now
  end
end
