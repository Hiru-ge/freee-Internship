require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @employee = employees(:employee1)
  end

  test "should get index" do
    # ログインしてからダッシュボードにアクセス
    post login_auth_url, params: { employee_id: @employee.employee_id, password: 'password123' }
    get dashboard_url
    assert_response :success
  end
end
