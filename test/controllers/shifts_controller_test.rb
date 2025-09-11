require "test_helper"

class ShiftsControllerTest < ActionDispatch::IntegrationTest
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
    get shifts_url
    assert_redirected_to login_url
  end

  # シフトページの表示テスト（オーナー）
  test "should get index as owner" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get shifts_url
    assert_response :success
    assert_select "h1", "シフトページ"
    assert_select "#employee-list-section", count: 1  # オーナーは従業員一覧が表示される
  end

  # シフトページの表示テスト（従業員）
  test "should get index as employee" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get shifts_url
    assert_response :success
    assert_select "h1", "シフトページ"
    # 従業員モードのクラスが設定されていることを確認
    assert_select ".shift-page-container.employee-mode"
  end

  # シフトデータ取得APIテスト
  test "should get shift data" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get shifts_data_url, params: { week: Date.current.strftime('%Y-%m-%d') }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['shifts'].is_a?(Hash)
    assert json_response['year'].is_a?(Integer)
    assert json_response['month'].is_a?(Integer)
  end

  # 従業員一覧取得APIテスト（オーナーのみ）
  test "should get employees list as owner" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get shifts_employees_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    assert json_response.length > 0
  end

  # 従業員一覧取得APIテスト（従業員はアクセス不可）
  test "should not get employees list as employee" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get shifts_employees_url
    assert_response :forbidden
  end

  # 週次ナビゲーションテスト
  test "should navigate to different weeks" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    # 前週
    get shifts_data_url, params: { week: 1.week.ago.strftime('%Y-%m-%d') }
    assert_response :success
    
    # 次週
    get shifts_data_url, params: { week: 1.week.from_now.strftime('%Y-%m-%d') }
    assert_response :success
  end

  # シフト表の表示テスト
  test "should display shift calendar" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get shifts_url
    assert_response :success
    assert_select "#shift-calendar-container", count: 1
  end

  # 103万の壁ゲージの表示テスト（オーナー）
  test "should display wage gauge for owner" do
    post login_url, params: {
      employee_id: '3313254',
      password: 'password123'
    }
    
    get shifts_url
    assert_response :success
    assert_select ".wage-gauge", count: 0  # オーナーは個人ゲージは表示されない
    assert_select ".employee-list", count: 1  # 従業員一覧
  end

  # 103万の壁ゲージの表示テスト（従業員）
  test "should display wage gauge for employee" do
    post login_url, params: {
      employee_id: '3316120',
      password: 'password123'
    }
    
    get shifts_url
    assert_response :success
    assert_select ".wage-gauge", count: 1  # 個人ゲージのみ
    assert_select ".employee-list", count: 0  # 従業員一覧は表示されない
  end
end
