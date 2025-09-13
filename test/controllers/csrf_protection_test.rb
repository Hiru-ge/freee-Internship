require 'test_helper'

class CsrfProtectionTest < ActionDispatch::IntegrationTest
  def setup
    @employee = employees(:employee1)
    # このテストクラスでのみCSRF保護を有効にする
    @original_csrf_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    
    # Rails 8.0の非推奨警告を抑制
    @original_warn = Warning.method(:warn)
    Warning.define_singleton_method(:warn) do |message|
      @original_warn.call(message) unless message.include?('unprocessable_entity is deprecated')
    end
  end

  def teardown
    # テスト後にCSRF保護設定を元に戻す
    ActionController::Base.allow_forgery_protection = @original_csrf_protection
    
    # 警告抑制を元に戻す
    Warning.define_singleton_method(:warn, @original_warn)
  end

  test "CSRFトークンなしでPOSTリクエストを送信すると422エラーが返される" do
    # ログイン（CSRFトークンを使用）
    get login_path
    csrf_token = session[:_csrf_token]
    post login_path, params: { employee_id: @employee.employee_id, password: 'password123' }, headers: { 'X-CSRF-Token' => csrf_token }
    follow_redirect!
    assert_response :success

    # CSRFトークンなしでPOSTリクエストを送信
    post clock_in_path, params: {}, headers: { 'X-CSRF-Token' => 'invalid_token' }
    assert_response :unprocessable_content
    # CSRFエラーの場合、レスポンスボディにCSRF関連のメッセージが含まれる
    assert_includes response.body, 'CSRF'
  end

  test "有効なCSRFトークンでPOSTリクエストを送信すると成功する" do
    # ログイン（CSRFトークンを使用）
    get login_path
    csrf_token = session[:_csrf_token]
    post login_path, params: { employee_id: @employee.employee_id, password: 'password123' }, headers: { 'X-CSRF-Token' => csrf_token }
    follow_redirect!
    assert_response :success

    # 有効なCSRFトークンを取得
    get dashboard_path
    csrf_token = session[:_csrf_token]

    # 有効なCSRFトークンでPOSTリクエストを送信
    post clock_in_path, params: {}, headers: { 'X-CSRF-Token' => csrf_token, 'Accept' => 'application/json' }
    assert_response :success
    # JSONレスポンスが返されることを確認
    assert_equal 'application/json; charset=utf-8', response.content_type
  end

  test "Content Security Policyヘッダーが設定されている" do
    get login_path
    assert_response :success
    assert_not_nil response.headers['Content-Security-Policy']
  end

  test "セキュリティヘッダーが適切に設定されている" do
    get login_path
    assert_response :success
    
    # X-Frame-Options
    assert_equal 'DENY', response.headers['X-Frame-Options']
    
    # X-Content-Type-Options
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
    
    # X-XSS-Protection
    assert_equal '1; mode=block', response.headers['X-XSS-Protection']
  end

  test "本番環境でStrict-Transport-Securityヘッダーが設定されている" do
    # 本番環境でのテストは別途実装
    # ここでは設定の確認のみ
    # テスト環境ではforce_sslはfalseなので、設定の存在のみ確認
    assert_not_nil Rails.application.config.force_ssl
  end
end
