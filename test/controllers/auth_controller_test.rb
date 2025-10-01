# frozen_string_literal: true

require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  def setup
    # テスト用の環境変数を設定
    ENV["ALLOWED_EMAIL_ADDRESSES"] = "okita2710@gmail.com"

    # メール送信をモック
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    # テスト後に環境変数をクリア
    ENV.delete("ALLOWED_EMAIL_ADDRESSES")
  end

  # ===== 正常系テスト =====

  test "トップページの表示" do
    get root_url
    assert_response :success
    assert_select "h1", text: "勤怠管理システム"
  end

  test "許可されたメールアドレスの認証" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_access_code_path
    assert_equal "okita2710@gmail.com", session[:pending_email]
    assert_equal 1, ActionMailer::Base.deliveries.length
  end

  test "freee.co.jpドメインのメールアドレス認証" do
    post authenticate_email_path, params: { email: "test@freee.co.jp" }
    assert_response :success
    assert_nil session[:pending_email]
    assert_equal 0, ActionMailer::Base.deliveries.length
  end

  test "正しい認証コードの検証" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_access_code_path

    code = EmailVerificationCode.last.code

    post verify_access_code_path, params: { code: code }
    assert_redirected_to "/home"
    assert session[:email_authenticated]
    assert_equal "okita2710@gmail.com", session[:authenticated_email]
    assert_not_nil session[:email_auth_expires_at]
    assert_nil session[:pending_email]
  end

  test "メール認証済み時のホームページリダイレクト" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_access_code_path

    code = EmailVerificationCode.last.code
    post verify_access_code_path, params: { code: code }
    assert_redirected_to "/home"

    get root_url
    assert_redirected_to "/home"
  end

  # ===== 異常系テスト =====

  test "許可されていないメールアドレスの認証拒否" do
    post authenticate_email_path, params: { email: "unauthorized@gmail.com" }
    assert_response :success
    assert_nil session[:pending_email]
    assert_equal 0, ActionMailer::Base.deliveries.length
  end

  test "空のメールアドレスのエラー表示" do
    post authenticate_email_path, params: { email: "" }
    assert_response :success
    assert_nil session[:pending_email]
  end

  test "間違った認証コードの検証失敗" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_access_code_path

    post verify_access_code_path, params: { code: "000000" }
    assert_response :success
    assert_nil session[:email_authenticated]
    assert_not_nil session[:pending_email]
  end

  test "期限切れ認証コードの検証失敗" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_access_code_path

    code_record = EmailVerificationCode.last
    code_record.update!(expires_at: 1.minute.ago)

    post verify_access_code_path, params: { code: code_record.code }
    assert_response :success
    assert_nil session[:email_authenticated]
    assert_not_nil session[:pending_email]
  end

  test "空の認証コードのエラー表示" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_access_code_path

    post verify_access_code_path, params: { code: "" }
    assert_response :success
    assert_nil session[:email_authenticated]
    assert_not_nil session[:pending_email]
  end

  test "保留メールなしでのルートページリダイレクト" do
    get verify_access_code_get_path
    assert_redirected_to root_path
  end

  test "テスト環境でのfreee.co.jpドメインメール送信停止" do
    post authenticate_email_path, params: { email: "test@freee.co.jp" }
    assert_response :success
    assert_nil session[:pending_email]
    assert_equal 0, ActionMailer::Base.deliveries.length
  end
end
