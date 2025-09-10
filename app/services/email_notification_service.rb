# メール通知サービスクラス
# シフト関連のメール送信を一元管理
class EmailNotificationService
  def initialize
    @freee_service = FreeeApiService.new(ENV['FREEE_ACCESS_TOKEN'], ENV['FREEE_COMPANY_ID'])
  end

  # 従業員情報を取得（メールアドレス付き）
  def get_employee_with_email(employee_id)
    all_employees = @freee_service.get_employees_full
    all_employees.find { |emp| emp['id'].to_s == employee_id.to_s }
  end

  # シフト交代依頼メールを送信
  def send_shift_exchange_request(applicant_id, approver_ids, shift_date, start_time, end_time)
    begin
      applicant_info = get_employee_with_email(applicant_id)
      return false unless applicant_info&.dig('email')

      approver_ids.each do |approver_id|
        approver_info = get_employee_with_email(approver_id)
        next unless approver_info&.dig('email')

        ShiftMailer.shift_exchange_request(
          approver_info['email'],
          approver_info['display_name'],
          applicant_info['display_name'],
          shift_date,
          start_time,
          end_time
        ).deliver_now
      end
      true
    rescue => e
      Rails.logger.error "シフト交代依頼メール送信エラー: #{e.message}"
      false
    end
  end

  # シフト追加依頼メールを送信
  def send_shift_addition_request(target_employee_id, shift_date, start_time, end_time)
    begin
      target_employee_info = get_employee_with_email(target_employee_id)
      return false unless target_employee_info&.dig('email')

      ShiftMailer.shift_addition_request(
        target_employee_info['email'],
        target_employee_info['display_name'],
        shift_date,
        start_time,
        end_time
      ).deliver_now
      true
    rescue => e
      Rails.logger.error "シフト追加依頼メール送信エラー: #{e.message}"
      false
    end
  end

  # シフト交代承認メールを送信
  def send_shift_exchange_approved(requester_id, approver_id, shift_date, start_time, end_time)
    begin
      requester_info = get_employee_with_email(requester_id)
      approver_info = get_employee_with_email(approver_id)
      return false unless requester_info&.dig('email') && approver_info

      ShiftMailer.shift_exchange_approved(
        requester_info['email'],
        requester_info['display_name'],
        approver_info['display_name'],
        shift_date,
        start_time,
        end_time
      ).deliver_now
      true
    rescue => e
      Rails.logger.error "シフト交代承認メール送信エラー: #{e.message}"
      false
    end
  end

  # シフト交代否認メールを送信
  def send_shift_exchange_denied(requester_id)
    begin
      requester_info = get_employee_with_email(requester_id)
      return false unless requester_info&.dig('email')

      ShiftMailer.shift_exchange_denied(
        requester_info['email'],
        requester_info['display_name']
      ).deliver_now
      true
    rescue => e
      Rails.logger.error "シフト交代否認メール送信エラー: #{e.message}"
      false
    end
  end

  # シフト追加承認メールを送信
  def send_shift_addition_approved(owner_id, target_name, shift_date, start_time, end_time)
    begin
      owner_info = get_employee_with_email(owner_id)
      return false unless owner_info&.dig('email')

      ShiftMailer.shift_addition_approved(
        owner_info['email'],
        target_name,
        shift_date,
        start_time,
        end_time
      ).deliver_now
      true
    rescue => e
      Rails.logger.error "シフト追加承認メール送信エラー: #{e.message}"
      false
    end
  end

  # シフト追加否認メールを送信
  def send_shift_addition_denied(owner_id, target_name)
    begin
      owner_info = get_employee_with_email(owner_id)
      return false unless owner_info&.dig('email')

      ShiftMailer.shift_addition_denied(
        owner_info['email'],
        target_name
      ).deliver_now
      true
    rescue => e
      Rails.logger.error "シフト追加否認メール送信エラー: #{e.message}"
      false
    end
  end
end
