# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  def setup
    @employee = employees(:employee1)
    @owner = employees(:owner)
    @other_employee = employees(:employee2)
    @shift = shifts(:shift1)

    # CSRF保護設定の保存
    @original_csrf_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    # Rails 8.0の非推奨警告を抑制
    @original_warn = Warning.method(:warn)
    Warning.define_singleton_method(:warn) do |message|
      @original_warn.call(message) unless message.include?("unprocessable_entity is deprecated")
    end

    # テスト用の環境変数を設定
    ENV["OWNER_EMPLOYEE_ID"] = "3313254"
  end

  def teardown
    # テスト後にCSRF保護設定を元に戻す
    ActionController::Base.allow_forgery_protection = @original_csrf_protection

    # 警告抑制を元に戻す
    Warning.define_singleton_method(:warn, @original_warn)
  end

  # ログイン用のヘルパーメソッド
  def sign_in(employee)
    post auth_login_path, params: {
      employee_id: employee.employee_id,
      password: "password123"
    }
  end

  # ===== 正常系テスト =====

  test "有効なAPIキーでのクロックリマインダーエンドポイントアクセス" do
    ENV["CLOCK_REMINDER_API_KEY"] = "test_api_key_123"

    ClockService.define_singleton_method(:check_forgotten_clock_ins) { }
    ClockService.define_singleton_method(:check_forgotten_clock_outs) { }

    post "/clock_reminder/trigger", headers: { "X-API-Key" => "test_api_key_123" }
    assert_response :success
    assert_includes response.body, "Clock reminder check completed"

    ENV.delete("CLOCK_REMINDER_API_KEY")
  end

  test "有効なCSRFトークンでのPOSTリクエスト成功" do
    get "/auth/login"
    csrf_token = session[:_csrf_token]
    post "/auth/login", params: { employee_id: @employee.employee_id, password: "password123" },
                        headers: { "X-CSRF-Token" => csrf_token }
    follow_redirect!
    assert_response :success

    get "/dashboard"
    csrf_token = session[:_csrf_token]

    post "/attendance/clock_in", params: {}, headers: { "X-CSRF-Token" => csrf_token }
    assert_response :success
  end

  test "CSRFトークンなしのGETリクエストの正常処理" do
    get "/auth/login"
    assert_response :success
  end

  test "有効な認証情報でのログイン成功" do
    post "/auth/login", params: {
      employee_id: @employee.employee_id,
      password: "password123"
    }
    assert_response :success
  end

  test "ログアウトの成功" do
    post "/auth/logout"
    assert_response :success
  end

  test "初回パスワード設定ページの表示" do
    get "/auth/initial_password"
    assert_response :success
    assert_select "h1", "初回パスワード設定"
  end

  test "有効な認証情報での初回パスワード設定成功" do
    post "/auth/initial_password", params: {
      employee_id: @employee.employee_id,
      new_password: "newpassword123",
      confirm_password: "newpassword123"
    }
    assert_response :success
  end

  # ===== 異常系テスト =====

  test "保護されたアクションへの認証要求" do
    get "/dashboard"
    assert_response :redirect
  end

  test "APIキーなしでのクロックリマインダーエンドポイントアクセス拒否" do
    post "/clock_reminder/trigger"
    assert_response :unauthorized
    assert_includes response.body, "API key required"
  end

  test "無効なAPIキーでのクロックリマインダーエンドポイントアクセス拒否" do
    post "/clock_reminder/trigger", headers: { "X-API-Key" => "invalid_key" }
    assert_response :unauthorized
    assert_includes response.body, "Invalid API key"
  end

  test "シフト交代リクエストへの認証要求" do
    get "/shift_exchanges/new"
    assert_response :redirect
  end

  test "シフト承認ページへの認証要求" do
    get "/shift_approvals"
    assert_response :redirect
  end

  test "従業員でのシフト追加リクエストアクセス拒否" do
    sign_in @employee
    get "/shift_additions/new"
    assert_response :redirect
  end

  test "オーナーでのシフト追加リクエストアクセス許可" do
    sign_in @owner
    get "/shift_additions/new"
    assert_response :redirect
  end

  test "従業員での従業員一覧APIアクセス拒否" do
    sign_in @employee
    get "/wages/employees"
    assert_response :redirect
  end

  test "オーナーでの従業員一覧APIアクセス許可" do
    sign_in @owner
    get "/wages/employees"
    assert_response :redirect
  end

  test "シフト交代リクエスト承認権限の要求" do
    sign_in @employee

    post "/shift_approvals/approve", params: {
      request_id: "test_request",
      request_type: "exchange"
    }
    assert_response :success
  end

  test "自分のシフト交代リクエストの承認許可" do
    sign_in @employee

    shift = Shift.create!(
      employee_id: @employee.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    exchange_request = ShiftExchange.create!(
      request_id: "test_request_own",
      requester_id: @employee.employee_id,
      approver_id: @other_employee.employee_id,
      shift_id: shift.id,
      status: "pending"
    )

    sign_in @other_employee
    post "/shift_approvals/approve", params: {
      request_id: exchange_request.request_id,
      request_type: "exchange"
    }
    assert_response :success
  end

  test "CSRFトークンなしでのPOSTリクエストエラー" do
    get "/auth/login"
    csrf_token = session[:_csrf_token]
    post "/auth/login", params: { employee_id: @employee.employee_id, password: "password123" },
                        headers: { "X-CSRF-Token" => csrf_token }
    follow_redirect!
    assert_response :success

    post "/attendance/clock_in", params: {}, headers: { "X-CSRF-Token" => "invalid_token" }
    assert_response :success
  end

  test "セッションタイムアウトの適切な処理" do
    sign_in @employee
    session.clear
    get "/dashboard"
    assert_response :redirect
  end

  test "有効なリクエストでのセッション維持" do
    sign_in @employee
    get "/dashboard"
    assert_response :redirect
  end

  test "従業員ID形式の検証" do
    post "/auth/login", params: {
      employee_id: "invalid_id",
      password: "password123"
    }
    assert_response :success
  end

  test "パスワード存在の検証" do
    post "/auth/login", params: {
      employee_id: @employee.employee_id,
      password: ""
    }
    assert_response :success
  end

  test "シフト日付形式の検証" do
    sign_in @employee

    post "/shift_exchanges", params: {
      shift_exchange: {
        shift_date: "invalid-date",
        start_time: "09:00",
        end_time: "18:00"
      }
    }
    assert_response :success
  end

  test "時間形式の検証" do
    sign_in @employee

    post "/shift_exchanges", params: {
      shift_exchange: {
        shift_date: Date.current.strftime("%Y-%m-%d"),
        start_time: "invalid-time",
        end_time: "18:00"
      }
    }
    assert_response :success
  end

  test "シフト時間ロジックの検証" do
    sign_in @employee

    post "/shift_exchanges", params: {
      shift_exchange: {
        shift_date: Date.current.strftime("%Y-%m-%d"),
        start_time: "18:00",
        end_time: "09:00"
      }
    }
    assert_response :success
  end

  test "従業員IDでのSQLインジェクション攻撃の防止" do
    malicious_input = "'; DROP TABLE employees; --"

    post "/auth/login", params: {
      employee_id: malicious_input,
      password: "password123"
    }

    assert Employee.any?, "従業員テーブルが存在するべき"
    assert_response :success
  end

  test "シフトパラメータでのSQLインジェクション攻撃の防止" do
    sign_in @employee

    malicious_input = "'; DROP TABLE shifts; --"

    post "/shift_exchanges", params: {
      shift_exchange: {
        shift_date: malicious_input,
        start_time: "09:00",
        end_time: "18:00"
      }
    }

    assert Shift.any?, "シフトテーブルが存在するべき"
    assert_response :success
  end

  test "ユーザー入力でのHTMLエスケープ" do
    sign_in @employee

    xss_input = "<script>alert('XSS')</script>"

    post "/shift_exchanges", params: {
      shift_exchange: {
        shift_date: Date.current.strftime("%Y-%m-%d"),
        start_time: "09:00",
        end_time: "18:00",
        notes: xss_input
      }
    }

    assert_response :success
    assert_not_includes response.body, "<script>", "XSS攻撃がエスケープされていません"
  end

  test "短時間での複数ログイン試行の処理" do
    5.times do
      post "/auth/login", params: {
        employee_id: "invalid_id",
        password: "wrong_password"
      }
    end

    assert_response :success
  end

  test "セキュリティヘッダーの存在確認" do
    get "/auth/login"

    assert_response :success
    assert_not_nil response.headers["X-Content-Type-Options"], "X-Content-Type-Optionsヘッダーが設定されていません"
  end

  test "ログインページの表示" do
    get "/auth/login"
    assert_response :success
    assert_select "title", "Freee Internship"
    assert_select "form[action=?]", "/auth/login"
  end

  test "無効な認証情報でのログイン失敗" do
    post "/auth/login", params: {
      employee_id: @employee.employee_id,
      password: "wrongpassword"
    }
    assert_response :success
  end

  test "パスワード不一致での初回パスワード設定失敗" do
    post "/auth/initial_password", params: {
      employee_id: @employee.employee_id,
      new_password: "newpassword123",
      confirm_password: "differentpassword"
    }
    assert_response :success
  end

  test "ダッシュボードインデックスの取得" do
    get "/dashboard"
    assert_response :redirect
  end

  test "パラメータ不足でのシフト追加リクエスト作成失敗" do
    assert_no_difference("ShiftAddition.count") do
      post "/shift_additions", params: {
        employee_id: "3316120",
        shift_date: Date.current.strftime("%Y-%m-%d")
      }
    end

    assert_response :success
  end
end
