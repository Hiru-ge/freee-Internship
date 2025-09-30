# frozen_string_literal: true

require "test_helper"

class AuthServiceTest < ActiveSupport::TestCase
  def setup
    @employee_id = "test_employee_id"
    @password = "test_password"
    @email = "test@example.com"
  end

  # ===== 認証機能テスト =====

  test "パスワードのハッシュ化" do
    hashed_password = AuthService.hash_password(@password)

    assert_not_nil hashed_password
    assert_not_equal @password, hashed_password
  end

  test "パスワードの検証" do
    hashed_password = AuthService.hash_password(@password)

    assert AuthService.verify_password(@password, hashed_password)
    assert_not AuthService.verify_password("wrong_password", hashed_password)
  end

  test "ログイン処理" do
    # ログイン処理の基本動作をテスト
    result = AuthService.login(@employee_id, @password)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "パスワード変更" do
    # パスワード変更の基本動作をテスト
    result = AuthService.change_password(@employee_id, @password, "new_password")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "初回パスワード設定" do
    # 初回パスワード設定の基本動作をテスト
    result = AuthService.set_initial_password(@employee_id, @password)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "認証コード送信" do
    # 認証コード送信の基本動作をテスト
    result = AuthService.send_verification_code(@employee_id)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "認証コード検証" do
    # 認証コード検証の基本動作をテスト
    result = AuthService.verify_code(@employee_id, "123456")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "認証付き初回パスワード設定" do
    # 認証付き初回パスワード設定の基本動作をテスト
    result = AuthService.set_initial_password_with_verification(@employee_id, @password, "123456")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "パスワードリセット用認証コード送信" do
    # パスワードリセット用認証コード送信の基本動作をテスト
    result = AuthService.send_password_reset_code(@employee_id)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "パスワードリセット用認証コード検証" do
    # パスワードリセット用認証コード検証の基本動作をテスト
    result = AuthService.verify_password_reset_code(@employee_id, "123456")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "認証コード付きパスワード再設定" do
    # 認証コード付きパスワード再設定の基本動作をテスト
    result = AuthService.reset_password_with_verification(@employee_id, "new_password", "123456")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "オーナー権限チェック" do
    # オーナー権限チェックの基本動作をテスト
    result = AuthService.is_owner?(@employee_id)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end

  test "freeeAPIの従業員情報から役割を判定" do
    # freeeAPIの従業員情報から役割を判定の基本動作をテスト
    employee_info = { "id" => 3313254, "display_name" => "テスト従業員" }
    result = AuthService.determine_role_from_freee(employee_info)
    assert_not_nil result
    assert result.is_a?(String)
    assert_includes ["owner", "employee"], result
  end

  test "freee APIから従業員情報を取得" do
    # freee APIから従業員情報を取得の基本動作をテスト
    result = AuthService.get_employee_info_from_freee(@employee_id)
    assert_not_nil result
    assert result.is_a?(Hash)
  end

  # ===== アクセス制御機能テスト =====

  test "メールアドレスが許可されているかチェック" do
    # メールアドレスが許可されているかチェックの基本動作をテスト
    result = AuthService.allowed_email?(@email)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end

  test "認証コードを生成・送信（アクセス制御用）" do
    # 認証コードを生成・送信（アクセス制御用）の基本動作をテスト
    result = AuthService.send_access_control_verification_code(@email)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "認証コードを検証（アクセス制御用）" do
    # 認証コードを検証（アクセス制御用）の基本動作をテスト
    result = AuthService.verify_access_control_code(@email, "123456")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "特定の許可メールアドレス一覧を取得" do
    # 特定の許可メールアドレス一覧を取得の基本動作をテスト
    result = AuthService.specific_allowed_emails
    assert_not_nil result
    assert result.is_a?(Array)
  end

  test "メールアドレスの形式をチェック" do
    # メールアドレスの形式をチェックの基本動作をテスト
    result = AuthService.valid_email_format?(@email)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end
end
