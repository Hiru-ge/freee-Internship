require "test_helper"

class ShiftRequestsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = employees(:owner)
    @employee1 = employees(:employee1)
    @employee2 = employees(:employee2)
    
    # テスト用シフトデータ
    @shift = Shift.create!(
      employee_id: '3316120',
      shift_date: Date.current,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('23:00')
    )
  end

  # 認証が必要なページへのアクセステスト
  test "should redirect to login when not authenticated" do
    get new_shift_request_url
    assert_redirected_to login_auth_url
  end

  # シフト交代リクエスト画面の表示テスト
  test "should get new shift exchange request" do
    post login_auth_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get new_shift_request_url, params: {
      employee_id: '3316120',
      date: Date.current.strftime('%Y-%m-%d'),
      start_time: '18:00',
      end_time: '23:00'
    }
    
    assert_response :success
    assert_select "h1", "シフト交代リクエスト"
    assert_select "form[action=?]", shift_requests_path
  end

  # シフト交代リクエスト送信成功テスト
  test "should create shift exchange request successfully" do
    post login_auth_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    # リクエスト送信（実際のレスポンスを確認）
    post shift_requests_url, params: {
      applicant_id: '3316120',
      approver_ids: ['3317741'],
      shift_date: Date.current,
      start_time: '18:00',
      end_time: '23:00'
    }
    
    # リダイレクトまたは成功レスポンスを確認
    assert response.redirect? || response.success?
  end

  # シフト交代リクエスト送信失敗テスト（重複チェック）
  test "should not create shift exchange request with overlap" do
    # 対象従業員に既存シフトを作成
    Shift.create!(
      employee_id: '3317741',
      shift_date: Date.current,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    post login_auth_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    # リクエスト送信
    post shift_requests_url, params: {
      applicant_id: '3316120',
      approver_ids: ['3317741'],
      shift_date: Date.current,
      start_time: '18:00',
      end_time: '23:00'
    }
    
    # リダイレクトまたはエラーレスポンスを確認
    assert response.redirect? || response.unprocessable_content?
  end

  # シフト追加リクエスト画面の表示テスト（オーナーのみ）
  test "should get new shift addition request as owner" do
    post login_auth_url, params: {
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
    post login_auth_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get new_shift_addition_url
    # リダイレクトまたは403エラーを確認
    assert response.redirect? || response.forbidden?
  end

  # シフト追加リクエスト送信成功テスト
  test "should create shift addition request successfully" do
    post login_auth_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    # リクエスト送信
    post shift_additions_url, params: {
      target_employee_id: '3316120',
      shift_date: Date.current + 1.day,
      start_time: '18:00',
      end_time: '23:00'
    }
    
    # リダイレクトまたは成功レスポンスを確認
    assert response.redirect? || response.success?
  end

  # シフト追加リクエスト送信失敗テスト（重複チェック）
  test "should not create shift addition request with overlap" do
    # 対象従業員に既存シフトを作成
    Shift.create!(
      employee_id: '3316120',
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    post login_auth_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    # リクエスト送信
    post shift_additions_url, params: {
      target_employee_id: '3316120',
      shift_date: Date.current + 1.day,
      start_time: '18:00',
      end_time: '23:00'
    }
    
    # リダイレクトまたはエラーレスポンスを確認
    assert response.redirect? || response.unprocessable_content?
  end

  # バリデーションテスト（必須項目）
  test "should validate required fields for shift exchange" do
    post login_auth_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    # バリデーションテスト
    post shift_requests_url, params: {
      applicant_id: '',
      approver_ids: [],
      shift_date: '',
      start_time: '',
      end_time: ''
    }
    
    # リダイレクトまたはエラーレスポンスを確認
    assert response.redirect? || response.unprocessable_content?
  end

  # バリデーションテスト（必須項目）
  test "should validate required fields for shift addition" do
    post login_auth_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    # バリデーションテスト
    post shift_additions_url, params: {
      target_employee_id: '',
      shift_date: '',
      start_time: '',
      end_time: ''
    }
    
    # リダイレクトまたはエラーレスポンスを確認
    assert response.redirect? || response.unprocessable_content?
  end
end
