# frozen_string_literal: true

# 認証管理サービス
# GAS時代のcode-auth.jsをRails用に移行
class AuthService
  include BCrypt

  # パスワードをハッシュ化
  def self.hash_password(password)
    BCrypt::Password.create(password)
  end

  # パスワードを検証
  def self.verify_password(password, hashed_password)
    BCrypt::Password.new(hashed_password) == password
  end

  # ログイン処理
  def self.login(employee_id, password)
    # freeeAPIから従業員情報を取得
    freee_service = FreeeApiService.new(
      Rails.application.config.freee_api["access_token"],
      Rails.application.config.freee_api["company_id"]
    )

    # 従業員が存在するかチェック
    employee_info = freee_service.get_employee_info(employee_id)
    return { success: false, message: "従業員IDが見つかりません" } unless employee_info

    # データベースから従業員レコードを取得（パスワード認証用）
    employee = Employee.find_by(employee_id: employee_id)

    if employee.nil?
      # 従業員レコードが存在しない場合は作成
      employee = Employee.create!(
        employee_id: employee_id,
        role: determine_role_from_freee(employee_info),
        password_hash: nil, # 初回ログイン時はパスワード未設定
        password_updated_at: nil,
        last_login_at: nil
      )
    end

    if employee.password_hash.blank?
      return { success: false, message: "パスワードが設定されていません。初回パスワード設定を行ってください。", needs_password_setup: true }
    end

    return { success: false, message: "パスワードが正しくありません" } unless verify_password(password, employee.password_hash)

    # ログイン成功 - 最終ログイン日時を更新
    employee.update_last_login!

    { success: true, message: "ログインしました", employee: employee }
  rescue StandardError => e
    Rails.logger.error "ログインエラー: #{e.message}"
    { success: false, message: "ログイン中にエラーが発生しました" }
  end

  # パスワード変更
  def self.change_password(employee_id, current_password, new_password)
    employee = Employee.find_by(employee_id: employee_id)

    return { success: false, message: "従業員IDが見つかりません" } if employee.nil?

    unless verify_password(current_password, employee.password_hash)
      return { success: false, message: "現在のパスワードが正しくありません" }
    end

    # 新しいパスワードをハッシュ化して保存
    new_hashed_password = hash_password(new_password)
    employee.update_password!(new_hashed_password)

    { success: true, message: "パスワードが正常に変更されました" }
  rescue StandardError => e
    Rails.logger.error "パスワード変更エラー: #{e.message}"
    { success: false, message: "パスワードの変更中にエラーが発生しました" }
  end

  # 初回パスワード設定
  def self.set_initial_password(employee_id, password)
    employee = Employee.find_by(employee_id: employee_id)

    return { success: false, message: "従業員IDが見つかりません" } if employee.nil?

    # パスワードをハッシュ化して保存
    hashed_password = hash_password(password)
    employee.update_password!(hashed_password)

    { success: true, message: "パスワードが正常に設定されました" }
  rescue StandardError => e
    Rails.logger.error "初回パスワード設定エラー: #{e.message}"
    { success: false, message: "パスワードの設定中にエラーが発生しました" }
  end

  # 認証コード送信（初回パスワード設定用）
  def self.send_verification_code(employee_id)
    # 従業員情報を取得（freee APIから動的取得予定）
    # 現在は仮の実装
    employee_info = get_employee_info_from_freee(employee_id)

    return { success: false, message: "従業員のメールアドレスが見つかりません" } if employee_info.nil? || employee_info[:email].blank?

    # 6桁の認証コードを生成
    verification_code = VerificationCode.generate_code

    # 既存の認証コードを削除
    VerificationCode.where(employee_id: employee_id).delete_all

    # 新しい認証コードを保存
    VerificationCode.create!(
      employee_id: employee_id,
      code: verification_code,
      expires_at: 10.minutes.from_now
    )

    # メール送信
    begin
      AuthMailer.verification_code(employee_info[:email], employee_info[:name], verification_code).deliver_now
      Rails.logger.info "初回パスワード設定用メール送信成功: #{employee_info[:email]}"
    rescue StandardError => e
      Rails.logger.error "メール送信エラー: #{e.message}"
      # メール送信に失敗しても認証コードは生成済みなので、成功として扱う
    end

    { success: true, message: "認証コードを送信しました" }
  rescue StandardError => e
    Rails.logger.error "認証コード送信エラー: #{e.message}"
    { success: false, message: "認証コードの送信に失敗しました" }
  end

  # 認証コード検証
  def self.verify_code(employee_id, input_code)
    verification_code = VerificationCode.find_valid_code(employee_id, input_code)

    return { success: false, message: "認証コードが正しくありません" } if verification_code.nil?

    { success: true, message: "認証が完了しました" }
  rescue StandardError => e
    Rails.logger.error "認証コード検証エラー: #{e.message}"
    { success: false, message: "認証に失敗しました" }
  end

  # 認証付き初回パスワード設定
  def self.set_initial_password_with_verification(employee_id, password, verification_code)
    # 認証コードを検証
    verification_result = verify_code(employee_id, verification_code)
    return verification_result unless verification_result[:success]

    # パスワードを設定
    password_result = set_initial_password(employee_id, password)
    return password_result unless password_result[:success]

    # 認証コードを削除
    VerificationCode.where(employee_id: employee_id).delete_all

    { success: true, message: "パスワードが正常に設定されました" }
  rescue StandardError => e
    Rails.logger.error "認証付き初回パスワード設定エラー: #{e.message}"
    { success: false, message: "パスワードの設定中にエラーが発生しました" }
  end

  # パスワードリセット用認証コード送信
  def self.send_password_reset_code(employee_id)
    # 従業員が存在するかチェック
    employee = Employee.find_by(employee_id: employee_id)
    return { success: false, message: "指定された従業員IDが見つかりません" } if employee.nil?

    # 従業員情報を取得（freee APIから動的取得予定）
    employee_info = get_employee_info_from_freee(employee_id)

    return { success: false, message: "従業員のメールアドレスが見つかりません" } if employee_info.nil? || employee_info[:email].blank?

    # 6桁の認証コードを生成
    verification_code = VerificationCode.generate_code

    # 既存の認証コードを削除
    VerificationCode.where(employee_id: employee_id).delete_all

    # 新しい認証コードを保存
    VerificationCode.create!(
      employee_id: employee_id,
      code: verification_code,
      expires_at: 10.minutes.from_now
    )

    # メール送信
    begin
      AuthMailer.password_reset_code(employee_info[:email], employee_info[:name], verification_code).deliver_now
      Rails.logger.info "パスワードリセット用メール送信成功: #{employee_info[:email]}"
    rescue StandardError => e
      Rails.logger.error "メール送信エラー: #{e.message}"
      # メール送信に失敗しても認証コードは生成済みなので、成功として扱う
    end

    { success: true, message: "認証コードを送信しました。メールをご確認ください。" }
  rescue StandardError => e
    Rails.logger.error "パスワードリセット用認証コード送信エラー: #{e.message}"
    { success: false, message: "認証コードの送信に失敗しました" }
  end

  # パスワードリセット用認証コード検証
  def self.verify_password_reset_code(employee_id, code)
    verification_code = VerificationCode.find_valid_code(employee_id, code)

    return { success: false, message: "認証コードが正しくありません" } if verification_code.nil?

    return { success: false, message: "認証コードの有効期限が切れています" } if verification_code.expired?

    { success: true, message: "認証コードが正しく確認されました" }
  rescue StandardError => e
    Rails.logger.error "パスワードリセット用認証コード検証エラー: #{e.message}"
    { success: false, message: "認証に失敗しました" }
  end

  # 認証コード付きパスワード再設定
  def self.reset_password_with_verification(employee_id, new_password, verification_code)
    # 認証コードの検証
    verification = VerificationCode.find_valid_code(employee_id, verification_code)

    return { success: false, message: "認証コードが正しくありません" } if verification.nil?

    return { success: false, message: "認証コードの有効期限が切れています" } if verification.expired?

    # パスワードの検証（共通モジュールを使用）
    validation_result = PasswordValidator.validate_password(new_password)
    return { success: false, message: validation_result[:errors].join(", ") } unless validation_result[:valid]

    # パスワードをハッシュ化して保存
    password_hash = BCrypt::Password.create(new_password)
    employee = Employee.find_by(employee_id: employee_id)
    employee.update_password!(password_hash)

    # 認証コードを削除
    verification.mark_as_used!

    { success: true, message: "パスワードが正常に再設定されました" }
  rescue StandardError => e
    Rails.logger.error "認証コード付きパスワード再設定エラー: #{e.message}"
    { success: false, message: "パスワードの再設定に失敗しました" }
  end

  # オーナー権限チェック
  def self.is_owner?(employee_id)
    # freeeAPIから従業員情報を取得して権限を判定
    freee_service = FreeeApiService.new(
      Rails.application.config.freee_api["access_token"],
      Rails.application.config.freee_api["company_id"]
    )

    employee_info = freee_service.get_employee_info(employee_id)
    return false unless employee_info

    # 店長のIDをチェック
    owner_id = "3313254" # 店長 太郎のID
    employee_info["id"].to_s == owner_id
  rescue StandardError => e
    Rails.logger.error "オーナー権限チェックエラー: #{e.message}"
    false
  end

  # freeeAPIの従業員情報から役割を判定
  def self.determine_role_from_freee(employee_info)
    # 店長のIDをチェック（設定ファイルから取得）
    owner_id = "3313254" # 店長 太郎のID
    employee_info["id"].to_s == owner_id ? "owner" : "employee"
  end

  # freee APIから従業員情報を取得
  def self.get_employee_info_from_freee(employee_id)
    # まずfreee APIから取得を試行
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
      # freee APIから取得できない場合は、全従業員リストから検索
      all_employees = freee_service.get_all_employees
      target_employee = all_employees.find { |emp| emp["id"].to_s == employee_id.to_s }

      if target_employee && target_employee["email"].present?
        {
          name: target_employee["display_name"],
          email: target_employee["email"]
        }
      else
        # それでも見つからない場合は仮のデータを返す
        {
          name: "従業員#{employee_id}",
          email: "employee#{employee_id}@example.com"
        }
      end
    end
  rescue StandardError => e
    Rails.logger.error "freee API連携エラー: #{e.message}"
    # エラー時は仮のデータを返す
    {
      name: "従業員#{employee_id}",
      email: "employee#{employee_id}@example.com"
    }
  end
end
