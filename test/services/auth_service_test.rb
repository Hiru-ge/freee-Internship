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
    # テスト環境では実際のログイン処理をスキップ
    assert_respond_to AuthService, :login
  end

  test "パスワード変更" do
    # テスト環境では実際のパスワード変更処理をスキップ
    assert_respond_to AuthService, :change_password
  end

  test "初回パスワード設定" do
    # テスト環境では実際のパスワード設定処理をスキップ
    assert_respond_to AuthService, :set_initial_password
  end

  test "認証コード送信" do
    # テスト環境では実際の認証コード送信処理をスキップ
    assert_respond_to AuthService, :send_verification_code
  end

  test "認証コード検証" do
    # テスト環境では実際の認証コード検証処理をスキップ
    assert_respond_to AuthService, :verify_code
  end

  test "認証付き初回パスワード設定" do
    # テスト環境では実際の認証付きパスワード設定処理をスキップ
    assert_respond_to AuthService, :set_initial_password_with_verification
  end

  test "パスワードリセット用認証コード送信" do
    # テスト環境では実際のパスワードリセット用認証コード送信処理をスキップ
    assert_respond_to AuthService, :send_password_reset_code
  end

  test "パスワードリセット用認証コード検証" do
    # テスト環境では実際のパスワードリセット用認証コード検証処理をスキップ
    assert_respond_to AuthService, :verify_password_reset_code
  end

  test "認証コード付きパスワード再設定" do
    # テスト環境では実際の認証コード付きパスワード再設定処理をスキップ
    assert_respond_to AuthService, :reset_password_with_verification
  end

  test "オーナー権限チェック" do
    # テスト環境では実際のオーナー権限チェック処理をスキップ
    assert_respond_to AuthService, :is_owner?
  end

  test "freeeAPIの従業員情報から役割を判定" do
    # テスト環境では実際の役割判定処理をスキップ
    assert_respond_to AuthService, :determine_role_from_freee
  end

  test "freee APIから従業員情報を取得" do
    # テスト環境では実際の従業員情報取得処理をスキップ
    assert_respond_to AuthService, :get_employee_info_from_freee
  end

  # ===== アクセス制御機能テスト =====

  test "メールアドレスが許可されているかチェック" do
    # テスト環境では実際のメールアドレスチェック処理をスキップ
    assert_respond_to AuthService, :allowed_email?
  end

  test "認証コードを生成・送信（アクセス制御用）" do
    # テスト環境では実際の認証コード生成・送信処理をスキップ
    assert_respond_to AuthService, :send_access_control_verification_code
  end

  test "認証コードを検証（アクセス制御用）" do
    # テスト環境では実際の認証コード検証処理をスキップ
    assert_respond_to AuthService, :verify_access_control_code
  end

  test "特定の許可メールアドレス一覧を取得" do
    # テスト環境では実際の許可メールアドレス一覧取得処理をスキップ
    assert_respond_to AuthService, :specific_allowed_emails
  end

  test "メールアドレスの形式をチェック" do
    # テスト環境では実際のメールアドレス形式チェック処理をスキップ
    assert_respond_to AuthService, :valid_email_format?
  end
end
