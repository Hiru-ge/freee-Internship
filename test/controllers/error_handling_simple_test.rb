require 'test_helper'

class ErrorHandlingSimpleTest < ActionController::TestCase
  tests AuthController

  test "should handle empty employee_id with proper error message" do
    post :login, params: { employee_id: '', password: 'test_password' }
    
    assert_equal '従業員IDを入力してください', flash[:error]
  end

  test "should handle empty password with proper error message" do
    post :login, params: { employee_id: 'test_employee', password: '' }
    
    assert_equal 'パスワードを入力してください', flash[:error]
  end

  test "should handle SQL injection attempts with user-friendly message" do
    post :login, params: { 
      employee_id: "'; DROP TABLE employees; --", 
      password: 'test_password' 
    }
    
    assert_equal '無効な文字が含まれています', flash[:error]
    assert_not_includes flash[:error], 'DROP TABLE'
  end

  test "should handle XSS attempts with appropriate message" do
    post :login, params: { 
      employee_id: '<script>alert("xss")</script>', 
      password: 'test_password' 
    }
    
    assert_equal '無効な文字が含まれています', flash[:error]
    assert_not_includes flash[:error], '<script>'
  end

  test "should maintain security headers on error responses" do
    post :login, params: { employee_id: '', password: '' }
    
    assert_equal 'DENY', response.headers['X-Frame-Options']
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
    assert_equal '1; mode=block', response.headers['X-XSS-Protection']
  end
end
