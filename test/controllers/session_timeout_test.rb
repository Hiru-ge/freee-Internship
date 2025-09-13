require 'test_helper'

class SessionTimeoutTest < ActionDispatch::IntegrationTest
  def setup
    @employee = employees(:employee1)
    # パスワードを設定（フィクスチャで既に設定済み）
  end

  test "セッションが24時間後にタイムアウトする" do
    # ログイン
    post login_path, params: { employee_id: @employee.employee_id, password: 'password123' }
    assert_redirected_to dashboard_path
    assert session[:authenticated]
    assert session[:employee_id]
    assert session[:created_at]

    # セッションタイムアウト時間（24時間）+ 1時間後にアクセス
    travel_to (ApplicationController::SESSION_TIMEOUT_HOURS + 1).hours.from_now do
      # ダッシュボードにアクセス
      get dashboard_path
      assert_redirected_to login_path
      assert_equal 'セッションがタイムアウトしました。再度ログインしてください。', flash[:alert]
      assert_nil session[:authenticated]
      assert_nil session[:employee_id]
      assert_nil session[:created_at]
    end
  end

  test "セッションが24時間以内なら有効" do
    # ログイン
    post login_path, params: { employee_id: @employee.employee_id, password: 'password123' }
    assert_redirected_to dashboard_path
    assert session[:authenticated]
    assert session[:employee_id]

    # セッションタイムアウト時間（24時間）- 1時間後にアクセス（まだ有効）
    travel_to (ApplicationController::SESSION_TIMEOUT_HOURS - 1).hours.from_now do
      # ダッシュボードにアクセス
      get dashboard_path
      assert_response :success
      assert session[:authenticated]
      assert session[:employee_id]
    end
  end

  test "ログイン時にセッション作成時刻が記録される" do
    post login_path, params: { employee_id: @employee.employee_id, password: 'password123' }
    assert_redirected_to dashboard_path
    assert session[:created_at]
    assert_in_delta Time.current.to_i, session[:created_at], 5
  end

  test "セッションタイムアウト後は認証が必要なページにアクセスできない" do
    # ログイン
    post login_path, params: { employee_id: @employee.employee_id, password: 'password123' }

    # セッションタイムアウト時間（24時間）+ 1時間後にアクセス
    travel_to (ApplicationController::SESSION_TIMEOUT_HOURS + 1).hours.from_now do
      # 認証が必要なページにアクセス
      get shifts_path
      assert_redirected_to login_path
      assert_equal 'セッションがタイムアウトしました。再度ログインしてください。', flash[:alert]
    end
  end
end
