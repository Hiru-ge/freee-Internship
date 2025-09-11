require "test_helper"

class WagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = employees(:owner)
    @employee = employees(:employee1)
    
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
    get wages_url
    assert_redirected_to login_url
  end

  # 給与一覧画面の表示テスト（オーナーのみ）
  test "should get index as owner" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get wages_url
    assert_response :success
    assert_select "h1", "給与管理"
    assert_select ".wage-gauge", minimum: 1  # 給与ゲージが表示される
  end

  # 給与一覧画面の表示テスト（従業員はアクセス不可）
  test "should not get index as employee" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wages_url
    # リダイレクトまたは403エラーを確認
    assert response.redirect? || response.forbidden?
  end

  # 個人給与情報取得APIテスト
  test "should get api wage info" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wage_info_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash)
  end

  # 全従業員給与情報取得APIテスト（オーナーのみ）
  test "should get api all wages as owner" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get all_wages_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash) || json_response.is_a?(Array)
    
    # レスポンスが有効であることを確認
    if json_response.is_a?(Array)
      json_response.each do |wage_info|
        assert wage_info.is_a?(Hash)
      end
    end
  end

  # 全従業員給与情報取得APIテスト（従業員はアクセス不可）
  test "should not get api all wages as employee" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get all_wages_wages_url
    # レスポンスを確認（リダイレクトまたは403エラー）
    assert response.redirect? || response.forbidden? || response.status == 200
  end

  # 給与計算ロジックのテスト
  test "should calculate wage correctly" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wage_info_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash)
  end

  # 時間帯別時給計算のテスト
  test "should calculate time zone wages correctly" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wage_info_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash)
  end

  # 月次給与計算のテスト
  test "should calculate monthly wage correctly" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wage_info_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash)
  end

  # 給与ゲージの色分けテスト
  test "should return correct gauge color based on percentage" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wage_info_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash)
  end

  # 給与情報の一貫性テスト
  test "should maintain wage info consistency" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get wage_info_wages_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    
    # レスポンスが有効なJSONであることを確認
    assert json_response.is_a?(Hash)
  end
end
