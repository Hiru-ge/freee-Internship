class EmailNotificationService
  include FreeeApiHelper

  def initialize
    @freee_service = FreeeApiService.new(ENV.fetch("FREEE_ACCESS_TOKEN", nil), ENV.fetch("FREEE_COMPANY_ID", nil))
  end

  def send_shift_exchange_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      send_shift_exchange_request_email(
        request.requester_id,
        [request.approver_id],
        request.shift.shift_date,
        request.shift.start_time,
        request.shift.end_time
      )
    end
  end

  def send_shift_exchange_approval_notification(exchange_request)
    return if Rails.env.test?

    begin
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

  def send_shift_exchange_rejection_notification(exchange_request)
    return if Rails.env.test?

    begin
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

  def send_shift_addition_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      send_shift_addition_request_email(
        request.target_employee_id,
        request.shift_date,
        request.start_time,
        request.end_time
      )
    end
  end

  def send_shift_addition_approval_notification(addition_request)
    return if Rails.env.test?

    begin
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

  def send_shift_addition_rejection_notification(addition_request)
    return if Rails.env.test?

    begin
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

  def send_shift_deletion_request_notification(deletion_request)
    return if Rails.env.test?

    begin
      send_shift_deletion_request_email(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time,
        deletion_request.reason
      )
    rescue StandardError => e
      Rails.logger.error "シフト削除依頼通知送信エラー: #{e.message}"
    end
  end

  def send_shift_deletion_approval_notification(deletion_request)
    return if Rails.env.test?

    begin
      send_shift_deletion_approved_email(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト削除承認通知送信エラー: #{e.message}"
    end
  end

  def send_shift_deletion_rejection_notification(deletion_request)
    return if Rails.env.test?

    begin
      send_shift_deletion_denied_email(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "シフト削除拒否通知送信エラー: #{e.message}"
    end
  end
  def send_verification_code_notification(employee_id, employee_name)
    return if Rails.env.test?

    begin

      send_verification_code_email(employee_id, employee_name)
    rescue StandardError => e
      Rails.logger.error "認証コード通知送信エラー: #{e.message}"
    end
  end

  private

  def send_shift_exchange_request_email(requester_id, approver_ids, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    return unless requester

    approver_ids.each do |approver_id|
      approver = Employee.find_by(employee_id: approver_id)
      next unless approver

      requester_info = freee_api_service.get_employee_info(requester_id)
      approver_info = freee_api_service.get_employee_info(approver_id)

      requester_email = requester_info&.dig("profile_rule", "email")
      requester_name = requester_info&.dig("display_name") || requester.display_name
      approver_email = approver_info&.dig("profile_rule", "email")
      approver_name = approver_info&.dig("display_name") || approver.display_name

      ShiftMailer.shift_exchange_request(
        approver_email,
        approver_name,
        requester_name,
        shift_date,
        start_time,
        end_time
      ).deliver_now
    end
  end

  def send_shift_exchange_approved_email(requester_id, approver_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    approver = Employee.find_by(employee_id: approver_id)
    return unless requester && approver

    requester_info = freee_api_service.get_employee_info(requester_id)
    approver_info = freee_api_service.get_employee_info(approver_id)

    requester_email = requester_info&.dig("profile_rule", "email")
    requester_name = requester_info&.dig("display_name") || requester.display_name
    approver_name = approver_info&.dig("display_name") || approver.display_name

    ShiftMailer.shift_exchange_approved(
      requester_email,
      requester_name,
      approver_name,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  def send_shift_exchange_denied_email(requester_id, approver_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    approver = Employee.find_by(employee_id: approver_id)
    return unless requester && approver

    requester_info = freee_api_service.get_employee_info(requester_id)

    requester_email = requester_info&.dig("profile_rule", "email")
    requester_name = requester_info&.dig("display_name") || requester.display_name

    ShiftMailer.shift_exchange_denied(
      requester_email,
      requester_name
    ).deliver_now
  end

  def send_shift_addition_request_email(target_employee_id, shift_date, start_time, end_time)
    target_employee = Employee.find_by(employee_id: target_employee_id)
    return unless target_employee

    employee_info = freee_api_service.get_employee_info(target_employee_id)
    target_email = employee_info&.dig("profile_rule", "email")
    target_name = employee_info&.dig("display_name") || target_employee.display_name

    ShiftMailer.shift_addition_request(
      target_email,
      target_name,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end

  def send_shift_addition_approved_email(requester_id, target_employee_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    target_employee = Employee.find_by(employee_id: target_employee_id)
    return unless requester && target_employee

    # オーナーのメールアドレスと対象従業員の名前を取得
    owner_info = freee_api_service.get_employee_info(requester_id)
    owner_email = owner_info&.dig("profile_rule", "email")
    target_name = target_employee.display_name

    ShiftMailer.shift_addition_approved(
      owner_email,
      target_name,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end
  def send_shift_addition_denied_email(requester_id, target_employee_id, shift_date, start_time, end_time)
    requester = Employee.find_by(employee_id: requester_id)
    target_employee = Employee.find_by(employee_id: target_employee_id)
    return unless requester && target_employee

    owner_info = freee_api_service.get_employee_info(requester_id)
    owner_email = owner_info&.dig("profile_rule", "email")
    target_name = target_employee.display_name

    ShiftMailer.shift_addition_denied(
      owner_email,
      target_name
    ).deliver_now
  end
  def send_shift_deletion_request_email(employee_id, shift_date, start_time, end_time, reason)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    owner_id = ENV["OWNER_EMPLOYEE_ID"]
    return unless owner_id

    owner_info = freee_api_service.get_employee_info(owner_id)
    owner_email = owner_info&.dig("profile_rule", "email")
    owner_name = owner_info&.dig("display_name") || "オーナー"

    requester_info = freee_api_service.get_employee_info(employee_id)
    requester_name = requester_info&.dig("display_name") || employee.display_name

    ShiftMailer.shift_deletion_request(
      owner_email,
      owner_name,
      requester_name,
      shift_date,
      start_time,
      end_time,
      reason
    ).deliver_now
  end
  def send_shift_deletion_approved_email(employee_id, shift_date, start_time, end_time)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    employee_info = freee_api_service.get_employee_info(employee_id)
    requester_email = employee_info&.dig("profile_rule", "email")
    requester_name = employee_info&.dig("display_name") || employee.display_name

    ShiftMailer.shift_deletion_approved(
      requester_email,
      requester_name,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end
  def send_shift_deletion_denied_email(employee_id, shift_date, start_time, end_time)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    employee_info = freee_api_service.get_employee_info(employee_id)
    requester_email = employee_info&.dig("profile_rule", "email")
    requester_name = employee_info&.dig("display_name") || employee.display_name

    ShiftMailer.shift_deletion_denied(
      requester_email,
      requester_name,
      shift_date,
      start_time,
      end_time
    ).deliver_now
  end
  def send_verification_code_email(employee_id, employee_name)
    employee = Employee.find_by(employee_id: employee_id)
    return unless employee

    AuthMailer.verification_code(employee, employee_name).deliver_now
  end
end
