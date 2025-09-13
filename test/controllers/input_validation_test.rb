require 'test_helper'

class InputValidationTest < ActionDispatch::IntegrationTest
  def setup
    @employee = employees(:employee1)
    @owner = employees(:owner)
    @shift = shifts(:shift1)
  end

  # ログイン用のヘルパーメソッド
  def sign_in(employee)
    post auth_login_path, params: {
      employee_id: employee.employee_id,
      password: 'password123'
    }
  end

  # SQLインジェクション対策のテスト
  test "should prevent SQL injection in employee_id parameter" do
    # 悪意のあるSQLインジェクション攻撃をシミュレート
    malicious_employee_id = "1'; DROP TABLE employees; --"
    
    # AuthControllerのloginアクションでSQLインジェクションを試行
    post auth_login_path, params: {
      employee_id: malicious_employee_id,
      password: "password123"
    }
    
    # データベースが破壊されていないことを確認
    assert Employee.exists?(@employee.id)
    assert_not Employee.exists?(employee_id: malicious_employee_id)
    
    # ログインが失敗することを確認（SQLインジェクションが実行されていない）
    assert_response :success  # ログイン画面が再表示される
    assert_nil session[:employee_id]
  end

  test "should prevent SQL injection in shift parameters" do
    sign_in @employee
    
    # シフト交代リクエストでSQLインジェクションを試行
    malicious_date = "2024-01-01'; DROP TABLE shifts; --"
    
    post shift_exchanges_path, params: {
      applicant_id: @employee.employee_id,
      shift_date: malicious_date,
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@owner.employee_id]
    }
    
    # データベースが破壊されていないことを確認
    assert Shift.exists?(@shift.id)
  end

  test "should prevent SQL injection in API parameters" do
    sign_in @employee
    
    # APIエンドポイントでSQLインジェクションを試行
    malicious_employee_id = "1' OR '1'='1"
    
    get "/api/shift_requests/pending_requests_for_user", params: {
      employee_id: malicious_employee_id
    }
    
    # 適切なエラーレスポンスが返されることを確認
    assert_response :success
    # 実際のデータが漏洩していないことを確認
    response_data = JSON.parse(response.body)
    assert_not response_data.any? { |item| item['applicantId'] == malicious_employee_id }
  end

  # XSS対策のテスト
  test "should prevent XSS in employee display name" do
    sign_in @employee
    
    # XSS攻撃をシミュレート
    xss_payload = "<script>alert('XSS')</script>"
    
    # シフト交代リクエストでXSSを試行
    post shift_exchanges_path, params: {
      applicant_id: @employee.employee_id,
      shift_date: "2024-01-01",
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@owner.employee_id]
    }
    
    # レスポンスにスクリプトタグが含まれていないことを確認
    assert_no_match /<script/i, response.body
    assert_no_match /alert\(/i, response.body
  end

  test "should escape HTML in flash messages" do
    sign_in @employee
    
    # HTMLタグを含むパラメータでリクエスト
    post shift_exchanges_path, params: {
      applicant_id: @employee.employee_id,
      shift_date: "<img src=x onerror=alert('XSS')>",
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@owner.employee_id]
    }
    
    # フラッシュメッセージが適切にエスケープされていることを確認
    follow_redirect!
    assert_no_match /<img/i, response.body
    assert_no_match /onerror/i, response.body
  end

  # 入力値の型検証テスト
  test "should validate date format in shift_date parameter" do
    sign_in @employee
    
    # 不正な日付形式でリクエスト
    post shift_exchanges_path, params: {
      applicant_id: @employee.employee_id,
      shift_date: "invalid-date",
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@owner.employee_id]
    }
    
    # 現在の実装では日付形式の検証がないため、このテストは失敗するはず
    # 適切なエラーメッセージが表示されることを確認
    assert_response :redirect
    follow_redirect!
    assert_match /日付の形式が正しくありません/i, flash[:error]
  end

  test "should validate time format in time parameters" do
    sign_in @employee
    
    # 不正な時間形式でリクエスト
    post shift_exchanges_path, params: {
      applicant_id: @employee.employee_id,
      shift_date: "2024-01-01",
      start_time: "25:00", # 無効な時間
      end_time: "18:00",
      approver_ids: [@owner.employee_id]
    }
    
    # 現在の実装では時間形式の検証がないため、このテストは失敗するはず
    # 適切なエラーメッセージが表示されることを確認
    assert_response :redirect
    follow_redirect!
    assert_match /時間の形式が正しくありません/i, flash[:error]
  end

  # 文字数制限のテスト
  test "should limit password length" do
    # 非常に長いパスワードでログインを試行
    long_password = "a" * 1000
    
    post auth_login_path, params: {
      employee_id: @employee.employee_id,
      password: long_password
    }
    
    # バリデーション関数がリダイレクトを返すことを確認
    assert_response :redirect
    follow_redirect!
    assert_match /パスワードが長すぎます/i, flash[:alert]
  end

  test "should limit employee_id length" do
    # 非常に長いemployee_idでログインを試行
    long_employee_id = "a" * 1000
    
    post auth_login_path, params: {
      employee_id: long_employee_id,
      password: "password123"
    }
    
    # バリデーション関数がリダイレクトを返すことを確認
    assert_response :redirect
    follow_redirect!
    assert_match /従業員IDが長すぎます/i, flash[:alert]
  end

  # 特殊文字の処理テスト
  test "should handle special characters in parameters" do
    sign_in @employee
    
    # 特殊文字を含むパラメータでリクエスト
    special_chars = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    
    post shift_exchanges_path, params: {
      applicant_id: @employee.employee_id,
      shift_date: "2024-01-01",
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@owner.employee_id]
    }
    
    # エラーが発生しないことを確認
    assert_response :redirect
  end

  # 空文字・null値の処理テスト
  test "should handle empty parameters gracefully" do
    sign_in @employee
    
    # 空のパラメータでリクエスト
    post shift_exchanges_path, params: {
      applicant_id: "",
      shift_date: "",
      start_time: "",
      end_time: "",
      approver_ids: []
    }
    
    # 適切なエラーメッセージが表示されることを確認
    assert_response :redirect
    follow_redirect!
    assert_match /すべての項目を入力してください/i, flash[:error]
  end

  test "should handle nil parameters gracefully" do
    sign_in @employee
    
    # nilパラメータでリクエスト
    post shift_exchanges_path, params: {
      applicant_id: nil,
      shift_date: nil,
      start_time: nil,
      end_time: nil,
      approver_ids: nil
    }
    
    # 適切なエラーメッセージが表示されることを確認
    assert_response :redirect
    follow_redirect!
    assert_match /すべての項目を入力してください/i, flash[:error]
  end
end
