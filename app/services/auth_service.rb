class AuthService
  include BCrypt

  def self.hash_password(password)
    BCrypt::Password.create(password)
  end

  def self.verify_password(password, hashed_password)
    BCrypt::Password.new(hashed_password) == password
  end

  def self.login(employee_id, password)
    freee_service = FreeeApiService.new(
      Rails.application.config.freee_api["access_token"],
      Rails.application.config.freee_api["company_id"]
    )

    employee_info = freee_service.get_employee_info(employee_id)
    return { success: false, message: "従業員IDが見つかりません" } unless employee_info
    employee = Employee.find_by(employee_id: employee_id)

    if employee.nil?
      employee = Employee.create!(
        employee_id: employee_id,
        role: determine_role_from_freee(employee_info),
        password_hash: nil,
        password_updated_at: nil,
        last_login_at: nil
      )
    end

    if employee.password_hash.blank?
      return { success: false, message: "パスワードが設定されていません。初回パスワード設定を行ってください。", needs_password_setup: true }
    end

    return { success: false, message: "パスワードが正しくありません" } unless verify_password(password, employee.password_hash)

    employee.update_last_login!

    { success: true, message: "ログインしました", employee: employee }
  rescue StandardError => e
    Rails.logger.error "ログインエラー: #{e.message}"
    { success: false, message: "ログイン中にエラーが発生しました" }
  end
  def self.change_password(employee_id, current_password, new_password)
    employee = Employee.find_by(employee_id: employee_id)

    return { success: false, message: "従業員IDが見つかりません" } if employee.nil?

    unless verify_password(current_password, employee.password_hash)
      return { success: false, message: "現在のパスワードが正しくありません" }
    end
    new_hashed_password = hash_password(new_password)
    employee.update_password!(new_hashed_password)

    { success: true, message: "パスワードが正常に変更されました" }
  rescue StandardError => e
    Rails.logger.error "パスワード変更エラー: #{e.message}"
    { success: false, message: "パスワードの変更中にエラーが発生しました" }
  end
  def self.set_initial_password(employee_id, password)
    employee = Employee.find_by(employee_id: employee_id)

    return { success: false, message: "従業員IDが見つかりません" } if employee.nil?
    hashed_password = hash_password(password)
    employee.update_password!(hashed_password)

    { success: true, message: "パスワードが正常に設定されました" }
  rescue StandardError => e
    Rails.logger.error "初回パスワード設定エラー: #{e.message}"
    { success: false, message: "パスワードの設定中にエラーが発生しました" }
  end
  def self.send_verification_code(employee_id)
    employee_info = get_employee_info_from_freee(employee_id)

    return { success: false, message: "従業員のメールアドレスが見つかりません" } if employee_info.nil? || employee_info[:email].blank?
    verification_code = VerificationCode.generate_code
    VerificationCode.where(employee_id: employee_id).delete_all
    VerificationCode.create!(
      employee_id: employee_id,
      code: verification_code,
      expires_at: 10.minutes.from_now
    )
    begin
      AuthMailer.verification_code(employee_info[:email], employee_info[:name], verification_code).deliver_now
      Rails.logger.info "初回パスワード設定用メール送信成功: #{employee_info[:email]}"
    rescue StandardError => e
      Rails.logger.error "メール送信エラー: #{e.message}"

    end

    { success: true, message: "認証コードを送信しました。メールの送信には数分かかる場合があります。" }
  rescue StandardError => e
    Rails.logger.error "認証コード送信エラー: #{e.message}"
    { success: false, message: "認証コードの送信に失敗しました" }
  end
  def self.verify_code(employee_id, input_code)
    verification_code = VerificationCode.find_valid_code(employee_id, input_code)

    return { success: false, message: "認証コードが正しくありません" } if verification_code.nil?

    { success: true, message: "認証が完了しました" }
  rescue StandardError => e
    Rails.logger.error "認証コード検証エラー: #{e.message}"
    { success: false, message: "認証に失敗しました" }
  end
  def self.set_initial_password_with_verification(employee_id, password, verification_code)

    verification_result = verify_code(employee_id, verification_code)
    return verification_result unless verification_result[:success]
    password_result = set_initial_password(employee_id, password)
    return password_result unless password_result[:success]
    VerificationCode.where(employee_id: employee_id).delete_all

    { success: true, message: "パスワードが正常に設定されました" }
  rescue StandardError => e
    Rails.logger.error "認証付き初回パスワード設定エラー: #{e.message}"
    { success: false, message: "パスワードの設定中にエラーが発生しました" }
  end
  def self.send_password_reset_code(employee_id)

    employee = Employee.find_by(employee_id: employee_id)
    return { success: false, message: "指定された従業員IDが見つかりません" } if employee.nil?
    employee_info = get_employee_info_from_freee(employee_id)

    return { success: false, message: "従業員のメールアドレスが見つかりません" } if employee_info.nil? || employee_info[:email].blank?
    verification_code = VerificationCode.generate_code
    VerificationCode.where(employee_id: employee_id).delete_all
    VerificationCode.create!(
      employee_id: employee_id,
      code: verification_code,
      expires_at: 10.minutes.from_now
    )
    begin
      AuthMailer.password_reset_code(employee_info[:email], employee_info[:name], verification_code).deliver_now
      Rails.logger.info "パスワードリセット用メール送信成功: #{employee_info[:email]}"
    rescue StandardError => e
      Rails.logger.error "メール送信エラー: #{e.message}"

    end

    { success: true, message: "認証コードを送信しました。メールの送信には数分かかる場合があります。メールをご確認ください。" }
  rescue StandardError => e
    Rails.logger.error "パスワードリセット用認証コード送信エラー: #{e.message}"
    { success: false, message: "認証コードの送信に失敗しました" }
  end
  def self.verify_password_reset_code(employee_id, code)
    verification_code = VerificationCode.find_valid_code(employee_id, code)

    return { success: false, message: "認証コードが正しくありません" } if verification_code.nil?

    return { success: false, message: "認証コードの有効期限が切れています" } if verification_code.expired?

    { success: true, message: "認証コードが正しく確認されました" }
  rescue StandardError => e
    Rails.logger.error "パスワードリセット用認証コード検証エラー: #{e.message}"
    { success: false, message: "認証に失敗しました" }
  end
  def self.reset_password_with_verification(employee_id, new_password, verification_code)

    verification = VerificationCode.find_valid_code(employee_id, verification_code)

    return { success: false, message: "認証コードが正しくありません" } if verification.nil?

    return { success: false, message: "認証コードの有効期限が切れています" } if verification.expired?
    validation_result = PasswordValidator.validate_password(new_password)
    return { success: false, message: validation_result[:errors].join(", ") } unless validation_result[:valid]
    password_hash = BCrypt::Password.create(new_password)
    employee = Employee.find_by(employee_id: employee_id)
    employee.update_password!(password_hash)
    verification.mark_as_used!

    { success: true, message: "パスワードが正常に再設定されました" }
  rescue StandardError => e
    Rails.logger.error "認証コード付きパスワード再設定エラー: #{e.message}"
    { success: false, message: "パスワードの再設定に失敗しました" }
  end
  def self.is_owner?(employee_id)

    owner_id = ENV["OWNER_EMPLOYEE_ID"]
    return false unless owner_id&.strip&.present?
    freee_service = FreeeApiService.new(
      Rails.application.config.freee_api["access_token"],
      Rails.application.config.freee_api["company_id"]
    )

    employee_info = freee_service.get_employee_info(employee_id)
    return false unless employee_info

    employee_info["id"].to_s == owner_id.strip
  rescue StandardError => e
    Rails.logger.error "オーナー権限チェックエラー: #{e.message}"
    false
  end
  def self.determine_role_from_freee(employee_info)

    owner_id = ENV["OWNER_EMPLOYEE_ID"]
    return "employee" unless owner_id&.strip&.present?

    employee_info["id"].to_s == owner_id.strip ? "owner" : "employee"
  end
  def self.get_employee_info_from_freee(employee_id)

    freee_service = FreeeApiService.new(
      Rails.application.config.freee_api["access_token"],
      Rails.application.config.freee_api["company_id"]
    )

    employee_info = freee_service.get_employee_info(employee_id)

    if employee_info && employee_info["email"].present?
      {
        name: employee_info["display_name"],
        email: employee_info["email"]
      }
    else

      all_employees = freee_service.get_all_employees
      target_employee = all_employees.find { |emp| emp["id"].to_s == employee_id.to_s }

      if target_employee && target_employee["email"].present?
        {
          name: target_employee["display_name"],
          email: target_employee["email"]
        }
      else

        {
          name: "従業員#{employee_id}",
          email: "employee#{employee_id}@example.com"
        }
      end
    end
  rescue StandardError => e
    Rails.logger.error "freee API連携エラー: #{e.message}"

    {
      name: "従業員#{employee_id}",
      email: "employee#{employee_id}@example.com"
    }
  end
  def self.allowed_email?(email)
    return false if email.blank?
    return false unless valid_email_format?(email)
    return true if specific_allowed_emails.include?(email.downcase)
    return true if email.downcase.end_with?("@freee.co.jp")

    false
  end
  def self.send_access_control_verification_code(email)
    return { success: false, message: "このメールアドレスはアクセスが許可されていません" } unless allowed_email?(email)
    if Rails.env.test? && email.downcase.end_with?("@freee.co.jp")
      return { success: false, message: "テスト環境では@freee.co.jpドメインへのメール送信は禁止されています" }
    end

    begin

      EmailVerificationCode.where(email: email).delete_all
      code = EmailVerificationCode.generate_code
      EmailVerificationCode.create!(
        email: email,
        code: code,
        expires_at: 10.minutes.from_now
      )
      AuthMailer.access_control_verification_code(email, code).deliver_now

      { success: true, message: "認証コードを送信しました。メールの送信には数分かかる場合があります。", code: code }
    rescue StandardError => e
      Rails.logger.error "認証コード送信エラー: #{e.message}"
      { success: false, message: "認証コードの送信に失敗しました" }
    end
  end
  def self.verify_access_control_code(email, code)
    return { success: false, message: "メールアドレスまたは認証コードが指定されていません" } if email.blank? || code.blank?
    verification_code = EmailVerificationCode.valid.for_email(email).find_by(code: code)

    if verification_code

      verification_code.destroy
      return { success: true, message: "認証が完了しました" }
    end
    expired_code = EmailVerificationCode.for_email(email).find_by(code: code)
    return { success: false, message: "認証コードの有効期限が切れています" } if expired_code
    { success: false, message: "認証コードが正しくありません" }
  end
  def self.specific_allowed_emails
    @specific_allowed_emails ||= begin
      emails = ENV["ALLOWED_EMAIL_ADDRESSES"] || ""
      emails.split(",").map(&:strip).map(&:downcase).reject(&:blank?)
    end
  end
  def self.valid_email_format?(email)
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
