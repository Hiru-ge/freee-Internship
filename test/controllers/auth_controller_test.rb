require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  test "should get login" do
    get auth_login_url
    assert_response :success
  end

  test "should get initial_password" do
    get auth_initial_password_url
    assert_response :success
  end

  test "should get password_change" do
    get auth_password_change_url
    assert_response :success
  end

  test "should get forgot_password" do
    get auth_forgot_password_url
    assert_response :success
  end
end
