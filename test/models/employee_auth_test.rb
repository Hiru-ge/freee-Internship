# frozen_string_literal: true

require "test_helper"

class EmployeeAuthTest < ActiveSupport::TestCase
  def setup
    @employee = Employee.create!(
      employee_id: "123456",
      role: "employee",
      password_hash: Employee.hash_password("password123")
    )
  end

  def teardown
    # 外部キー制約を無効にしてからデータを削除
    ActiveRecord::Base.connection.disable_referential_integrity do
      Employee.delete_all
      VerificationCode.delete_all if defined?(VerificationCode)
      EmailVerificationCode.delete_all if defined?(EmailVerificationCode)
    end
    # 環境変数をリセット
    ENV["OWNER_EMPLOYEE_ID"] = @original_owner_id if defined?(@original_owner_id)
  end

  # === 基本的な認証機能テスト ===

  test "空の従業員IDでのログイン失敗" do
    assert_raises(Employee::ValidationError, "従業員IDが入力されていません") do
      Employee.authenticate_login("", "password123")
    end
  end

  test "空のパスワードでのログイン失敗" do
    assert_raises(Employee::ValidationError, "パスワードが入力されていません") do
      Employee.authenticate_login("123456", "")
    end
  end

  # === setup_initial_password テスト ===

  test "正常な初期パスワード設定" do
    employee = Employee.create!(employee_id: "789012", role: "employee", password_hash: nil)

    result = Employee.setup_initial_password("789012", "newpassword123", "newpassword123")
    assert_equal employee.id, result.id
    assert_not_nil result.password_hash
    assert_not_nil result.password_updated_at
  end

  test "パスワード不一致での初期パスワード設定失敗" do
    Employee.create!(employee_id: "789012", role: "employee", password_hash: nil)

    assert_raises(Employee::ValidationError, "パスワードが一致しません") do
      Employee.setup_initial_password("789012", "password123", "differentpassword")
    end
  end

  test "既にパスワード設定済みでの初期パスワード設定失敗" do
    assert_raises(Employee::ValidationError, "既にパスワードが設定されています") do
      Employee.setup_initial_password("123456", "newpassword123", "newpassword123")
    end
  end

  test "短すぎるパスワードでの初期パスワード設定失敗" do
    Employee.create!(employee_id: "789012", role: "employee", password_hash: nil)

    assert_raises(Employee::ValidationError, "パスワードは8文字以上128文字以下で入力してください") do
      Employee.setup_initial_password("789012", "short", "short")
    end
  end

  # === change_password! テスト ===

  test "正常なパスワード変更" do
    old_hash = @employee.password_hash
    @employee.change_password!("password123", "newpassword456", "newpassword456")

    @employee.reload
    assert_not_equal old_hash, @employee.password_hash
    assert_not_nil @employee.password_updated_at
  end

  test "間違った現在のパスワードでのパスワード変更失敗" do
    assert_raises(Employee::AuthenticationError, "現在のパスワードが正しくありません") do
      @employee.change_password!("wrongpassword", "newpassword456", "newpassword456")
    end
  end

  test "新しいパスワード不一致でのパスワード変更失敗" do
    assert_raises(Employee::ValidationError, "新しいパスワードが一致しません") do
      @employee.change_password!("password123", "newpassword456", "differentpassword")
    end
  end

  # === search_by_name テスト ===

  test "空の検索名での従業員検索" do
    results = Employee.search_by_name("")
    assert_equal [], results
  end

  # === ヘルパーメソッドテスト ===

  test "パスワードハッシュ化と検証" do
    password = "testpassword123"
    hashed = Employee.hash_password(password)

    assert_not_equal password, hashed
    assert Employee.verify_password(password, hashed)
    assert_not Employee.verify_password("wrongpassword", hashed)
  end

  test "パスワード形式バリデーション" do
    # 正常なパスワード
    assert_nothing_raised do
      Employee.validate_password_format("password123")
    end

    # 短すぎるパスワード
    assert_raises(Employee::ValidationError) do
      Employee.validate_password_format("short")
    end

    # 長すぎるパスワード
    assert_raises(Employee::ValidationError) do
      Employee.validate_password_format("a" * 129)
    end

    # 無効な文字を含むパスワード
    assert_raises(Employee::ValidationError) do
      Employee.validate_password_format("password@123")
    end
  end

  test "従業員名正規化" do
    assert_equal "tanakatarou", Employee.normalize_employee_name("Tanaka Tarou")
    assert_equal "tanakatarou", Employee.normalize_employee_name("  TANAKA TAROU  ")
    assert_equal "tanakatarou", Employee.normalize_employee_name("tanaka tarou")
  end

  test "Freee APIから役割決定" do
    # 実際のOWNER_EMPLOYEE_IDを使用
    owner_employee_id = ENV["OWNER_EMPLOYEE_ID"] || "3313254"
    
    # オーナー
    owner_info = {"id" => owner_employee_id}
    assert_equal "owner", Employee.determine_role_from_freee(owner_info)
    
    # 従業員
    employee_info = {"id" => "789012"}
    assert_equal "employee", Employee.determine_role_from_freee(employee_info)
  end

  # === 認証コード関連テスト（AuthServiceTestから移行） ===

  test "認証コード送信の成功" do
    # テスト環境では実際のFreee APIは呼ばれないため、スキップ
    skip "FreeeApiServiceのモックが必要なため、統合テストで実行"
  end

  test "存在しない従業員IDでの認証コード送信失敗" do
    # テスト環境では実際のFreee APIは呼ばれないため、スキップ
    skip "FreeeApiServiceのモックが必要なため、統合テストで実行"
  end

  test "認証コード検証の成功" do
    # VerificationCodeを作成
    VerificationCode.create!(
      employee_id: "123456",
      code: "123456",
      expires_at: 10.minutes.from_now
    )

    result = Employee.verify_code("123456", "123456")
    assert result[:success]
    assert_includes result[:message], "認証コードが確認されました"
  end

  test "無効な認証コードでの検証失敗" do
    assert_raises(Employee::AuthenticationError, "認証コードが正しくありません") do
      Employee.verify_code("123456", "000000")
    end
  end

  test "パスワードリセットコード送信の成功" do
    # テスト環境では実際のFreee APIは呼ばれないため、スキップ
    skip "FreeeApiServiceのモックが必要なため、統合テストで実行"
  end

  test "パスワードリセットコード検証の成功" do
    # VerificationCodeを作成
    VerificationCode.create!(
      employee_id: "123456",
      code: "123456",
      expires_at: 10.minutes.from_now
    )

    result = Employee.verify_password_reset_code("123456", "123456")
    assert result[:success]
    assert_includes result[:message], "認証コードが確認されました"
  end

  test "認証コード付きパスワードリセットの成功" do
    employee = Employee.create!(employee_id: "reset_test", role: "employee", password_hash: Employee.hash_password("oldpassword"))
    
    # VerificationCodeを作成
    VerificationCode.create!(
      employee_id: "reset_test",
      code: "123456",
      expires_at: 10.minutes.from_now
    )

    result = Employee.reset_password_with_verification("reset_test", "newpassword123", "123456")
    assert result[:success]
    assert_includes result[:message], "パスワードがリセットされました"
    
    employee.reload
    assert Employee.verify_password("newpassword123", employee.password_hash)
  end

  test "無効な認証コードでのパスワードリセット失敗" do
    Employee.create!(employee_id: "reset_fail_test", role: "employee", password_hash: Employee.hash_password("oldpassword"))
    
    assert_raises(Employee::AuthenticationError, "認証コードが正しくありません") do
      Employee.reset_password_with_verification("reset_fail_test", "newpassword123", "000000")
    end
  end

  # === アクセス制御関連テスト ===

  test "許可されたメールアドレスのアクセス制御認証コード送信" do
    # 環境変数を一時的に設定
    original_allowed = ENV["ALLOWED_EMAIL_ADDRESSES"]
    ENV["ALLOWED_EMAIL_ADDRESSES"] = "test@example.com"
    
    begin
      result = Employee.send_access_control_verification_code("test@example.com")
      assert result[:success]
      assert_includes result[:message], "認証コードを送信しました"
      assert result[:code].present?
    ensure
      ENV["ALLOWED_EMAIL_ADDRESSES"] = original_allowed
    end
  end

  test "許可されていないメールアドレスでのアクセス制御認証コード送信失敗" do
    original_allowed = ENV["ALLOWED_EMAIL_ADDRESSES"]
    ENV["ALLOWED_EMAIL_ADDRESSES"] = "allowed@example.com"
    
    begin
      assert_raises(Employee::ValidationError, "このメールアドレスは許可されていません") do
        Employee.send_access_control_verification_code("unauthorized@example.com")
      end
    ensure
      ENV["ALLOWED_EMAIL_ADDRESSES"] = original_allowed
    end
  end

  test "アクセス制御認証コード検証の成功（テスト環境）" do
    # EmailVerificationCodeを作成してテスト
    EmailVerificationCode.create!(
      email: "test@example.com",
      code: "123456",
      expires_at: 10.minutes.from_now
    )
    
    result = Employee.verify_access_control_code("test@example.com", "123456")
    assert result[:success]
    assert_includes result[:message], "認証コードが確認されました"
  end

  # === メールアドレス許可チェックテスト ===

  test "メールアドレス許可チェック - 完全一致" do
    original_allowed = ENV["ALLOWED_EMAIL_ADDRESSES"]
    ENV["ALLOWED_EMAIL_ADDRESSES"] = "test@example.com,admin@company.com"
    
    begin
      assert Employee.email_allowed?("test@example.com")
      assert Employee.email_allowed?("admin@company.com")
      assert_not Employee.email_allowed?("unauthorized@example.com")
    ensure
      ENV["ALLOWED_EMAIL_ADDRESSES"] = original_allowed
    end
  end

  test "メールアドレス許可チェック - ドメイン一致" do
    original_allowed = ENV["ALLOWED_EMAIL_ADDRESSES"]
    ENV["ALLOWED_EMAIL_ADDRESSES"] = "@example.com,specific@company.com"
    
    begin
      assert Employee.email_allowed?("anyone@example.com")
      assert Employee.email_allowed?("user@example.com")
      assert Employee.email_allowed?("specific@company.com")
      assert_not Employee.email_allowed?("user@unauthorized.com")
    ensure
      ENV["ALLOWED_EMAIL_ADDRESSES"] = original_allowed
    end
  end

  test "メールアドレス許可チェック - 空のメールアドレス" do
    assert_not Employee.email_allowed?("")
    assert_not Employee.email_allowed?(nil)
  end

  # === Freee API関連テスト ===

  test "Freee APIから従業員情報取得の成功" do
    # テスト環境では実際のFreee APIは呼ばれないため、スキップ
    skip "FreeeApiServiceのモックが必要なため、統合テストで実行"
  end

  test "Freee APIから従業員情報取得の失敗" do
    # テスト環境では実際のFreee APIは呼ばれないため、スキップ
    skip "FreeeApiServiceのモックが必要なため、統合テストで実行"
  end

  test "Freee API エラー時の適切な処理" do
    # テスト環境では実際のFreee APIは呼ばれないため、スキップ
    skip "FreeeApiServiceのモックが必要なため、統合テストで実行"
  end

  # === パスワード強度関連テスト（PasswordValidatorから移行） ===

  test "パスワード強度チェック" do
    # 弱いパスワード（スコア0-2）
    assert_equal :weak, Employee.password_strength("12345")      # 短い数字のみ
    assert_equal :weak, Employee.password_strength("abc")        # 短い英字のみ
    assert_equal :weak, Employee.password_strength("password")   # 小文字のみ
    assert_equal :weak, Employee.password_strength("12345678")   # 数字のみ

    # 普通のパスワード（スコア3-4）
    assert_equal :medium, Employee.password_strength("Password")    # 大文字+小文字+8文字以上
    assert_equal :medium, Employee.password_strength("password123") # 小文字+数字+8文字以上

    # 強いパスワード（スコア5-6）
    assert_equal :medium, Employee.password_strength("Password123")      # 大文字+小文字+数字+8文字以上（スコア4）
    assert_equal :strong, Employee.password_strength("MyPassword123")    # 大文字+小文字+数字+12文字以上（スコア5）

    # 非常に強いパスワード（記号は現在のバリデーションでは許可されていないため、実際には使用されない）
    # このテストは将来の拡張のために残しておく
    # assert_equal :very_strong, Employee.password_strength("MyP@ssw0rd123!")
  end

  test "パスワード強度メッセージ" do
    assert_equal "弱い", Employee.password_strength_message(:weak)
    assert_equal "普通", Employee.password_strength_message(:medium)
    assert_equal "強い", Employee.password_strength_message(:strong)
    assert_equal "非常に強い", Employee.password_strength_message(:very_strong)
    assert_equal "不明", Employee.password_strength_message(:unknown)
  end

  test "パスワード強度の色" do
    assert_equal "#f44336", Employee.password_strength_color(:weak)
    assert_equal "#ff9800", Employee.password_strength_color(:medium)
    assert_equal "#4caf50", Employee.password_strength_color(:strong)
    assert_equal "#2196f3", Employee.password_strength_color(:very_strong)
    assert_equal "#999", Employee.password_strength_color(:unknown)
  end
end
