# frozen_string_literal: true

require "test_helper"

class AccessControlControllerTest < ActionDispatch::IntegrationTest
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

  test "should get index" do
    get root_url
    assert_response :success
    assert_select "h1", text: "勤怠管理システム"
  end

  test "should redirect to home if already email authenticated" do
    # メールアドレス認証済みのセッションを設定
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_code_path

    # 認証コードを検証してメールアドレス認証を完了
    code = EmailVerificationCode.last.code
    post verify_code_path, params: { code: code }
    assert_redirected_to "/home"

    # 再度トップページにアクセス
    get root_url
    assert_redirected_to "/home"
  end

  test "should authenticate email for allowed address" do
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_code_path
    assert_equal "okita2710@gmail.com", session[:pending_email]
    assert_equal 1, ActionMailer::Base.deliveries.length
  end

  test "should authenticate email for @freee.co.jp domain" do
    post authenticate_email_path, params: { email: "test@freee.co.jp" }
    assert_response :success
    assert_nil session[:pending_email]
    assert_equal 0, ActionMailer::Base.deliveries.length
  end

  test "should not authenticate email for disallowed address" do
    post authenticate_email_path, params: { email: "unauthorized@gmail.com" }
    assert_response :success
    assert_nil session[:pending_email]
    assert_equal 0, ActionMailer::Base.deliveries.length
  end

  test "should show error for blank email" do
    post authenticate_email_path, params: { email: "" }
    assert_response :success
    assert_nil session[:pending_email]
  end

  test "should verify correct code" do
    # メールアドレス認証を開始
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_code_path

    # 認証コードを取得
    code = EmailVerificationCode.last.code

    # 認証コードを検証
    post verify_code_path, params: { code: code }
    assert_redirected_to "/home"
    assert session[:email_authenticated]
    assert_equal "okita2710@gmail.com", session[:authenticated_email]
    assert_not_nil session[:email_auth_expires_at]
    assert_nil session[:pending_email]
  end

  test "should not verify incorrect code" do
    # メールアドレス認証を開始
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_code_path

    # 間違った認証コードを検証
    post verify_code_path, params: { code: "000000" }
    assert_response :success
    assert_nil session[:email_authenticated]
    assert_not_nil session[:pending_email]
  end

  test "should not verify expired code" do
    # メールアドレス認証を開始
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_code_path

    # 認証コードを期限切れにする
    code_record = EmailVerificationCode.last
    code_record.update!(expires_at: 1.minute.ago)

    # 期限切れの認証コードを検証
    post verify_code_path, params: { code: code_record.code }
    assert_response :success
    assert_nil session[:email_authenticated]
    assert_not_nil session[:pending_email]
  end

  test "should show error for blank code" do
    # メールアドレス認証を開始
    post authenticate_email_path, params: { email: "okita2710@gmail.com" }
    assert_redirected_to verify_code_path

    # 空の認証コードを検証
    post verify_code_path, params: { code: "" }
    assert_response :success
    assert_nil session[:email_authenticated]
    assert_not_nil session[:pending_email]
  end

  test "should redirect to root if no pending email" do
    get verify_code_get_path
    assert_redirected_to root_path
  end

  test "should not send mail to @freee.co.jp domain in test environment" do
    post authenticate_email_path, params: { email: "test@freee.co.jp" }
    assert_response :success
    assert_nil session[:pending_email]
    assert_equal 0, ActionMailer::Base.deliveries.length
  end
end
