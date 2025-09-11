require "test_helper"

class ShiftExchangesControllerTest < ActionDispatch::IntegrationTest
  # シフト交代リクエスト画面の表示テスト（ログイン済み）
  test "should get new shift exchange request when logged in" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get new_shift_exchange_url
    assert_response :success
    assert_select "h1", "シフト交代リクエスト"
    assert_select "form[action=?]", shift_exchanges_path
  end

  # シフト交代リクエスト画面の表示テスト（未ログイン）
  test "should redirect to login when not logged in" do
    get new_shift_exchange_url
    assert_redirected_to login_url
  end

  # シフト交代リクエストの作成テスト
  test "should create shift exchange request" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    # テスト用のEmployeeレコードを作成（存在しない場合のみ）
    Employee.find_or_create_by(employee_id: '3316120') do |emp|
      emp.password_hash = BCrypt::Password.create('password123')
      emp.role = 'employee'
    end
    
    Employee.find_or_create_by(employee_id: '3317741') do |emp|
      emp.password_hash = BCrypt::Password.create('password123')
      emp.role = 'employee'
    end
    
    # テスト用のシフトデータを作成（申請者のシフト）
    shift = Shift.create!(
      employee_id: '3316120',
      shift_date: Date.current,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 承認者のシフトは作成しない（利用可能にするため）
    
    
    assert_difference('ShiftExchange.count', 1) do
      post shift_exchanges_url, params: {
        applicant_id: '3316120',
        shift_date: Date.current.strftime('%Y-%m-%d'),
        start_time: '09:00',
        end_time: '18:00',
        approver_ids: ['3317741']
      }
    end
    
    assert_redirected_to shifts_path
    assert_equal 'リクエストを送信しました。承認をお待ちください。', flash[:notice]
  end

  # シフト交代リクエストの作成テスト（パラメータ不足）
  test "should not create shift exchange request with missing parameters" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    assert_no_difference('ShiftExchange.count') do
      post shift_exchanges_url, params: {
        applicant_id: '3316120',
        shift_date: '',
        start_time: '09:00',
        end_time: '18:00',
        approver_ids: ['3317741']
      }
    end
    
    assert_redirected_to new_shift_exchange_path
    assert_equal 'すべての項目を入力してください。', flash[:error]
  end
end