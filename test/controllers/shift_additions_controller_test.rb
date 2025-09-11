require "test_helper"

class ShiftAdditionsControllerTest < ActionDispatch::IntegrationTest
  # シフト追加リクエスト画面の表示テスト（オーナーのみ）
  test "should get new shift addition request as owner" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get new_shift_addition_url
    assert_response :success
    assert_select "h1", "シフト追加リクエスト"
    assert_select "form[action=?]", shift_additions_path
  end

  # シフト追加リクエスト画面の表示テスト（従業員はアクセス不可）
  test "should not get new shift addition request as employee" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get new_shift_addition_url
    assert_redirected_to dashboard_path
    assert_equal 'このページにアクセスする権限がありません', flash[:error]
  end

  # シフト追加リクエストの作成テスト
  test "should create shift addition request" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    assert_difference('ShiftAddition.count', 1) do
      post shift_additions_url, params: {
        employee_id: '3316120',
        shift_date: Date.current.strftime('%Y-%m-%d'),
        start_time: '09:00',
        end_time: '18:00'
      }
    end
    
    assert_redirected_to shifts_path
    assert_equal 'シフト追加リクエストを送信しました。', flash[:notice]
  end

  # シフト追加リクエストの作成テスト（パラメータ不足）
  test "should not create shift addition request with missing parameters" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    assert_no_difference('ShiftAddition.count') do
      post shift_additions_url, params: {
        employee_id: '',
        shift_date: Date.current.strftime('%Y-%m-%d'),
        start_time: '09:00',
        end_time: '18:00'
      }
    end
    
    assert_redirected_to new_shift_addition_path
    assert_equal 'すべての項目を入力してください。', flash[:error]
  end
end