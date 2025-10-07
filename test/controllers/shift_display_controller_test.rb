# frozen_string_literal: true

require "test_helper"

class ShiftDisplayControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = employees(:owner)
    @employee = employees(:employee1)

    # テスト用シフトデータ
    @shift = Shift.create!(
      employee_id: @owner.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )

    @shift2 = Shift.create!(
      employee_id: @employee.employee_id,
      shift_date: Date.current + 1,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("23:00")
    )
  end

  # ===== 正常系テスト =====

  test "オーナーとしてシフトページの表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url
    assert_response :success
    assert_select "h1", "シフトページ"
    assert_select "#employee-list-section", count: 1
  end

  test "従業員としてシフトページの表示" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url
    assert_response :success
    assert_select "h1", "シフトページ"
    assert_select ".shift-page-container.employee-mode"
  end

  test "シフトデータの取得" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url, headers: { "Accept" => "application/json" }
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "オーナーとして従業員一覧の取得" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get wages_employees_url, headers: { "Accept" => "application/json" }
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "未認証時のログインページへのリダイレクト" do
    get shifts_url
    assert_redirected_to login_url
  end

  test "従業員として従業員一覧へのアクセス拒否" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get wages_employees_url
    assert_response :forbidden
  end

  test "週次ナビゲーション" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url
    assert_response :success
    assert_select ".month-navigation"
  end

  test "シフトカレンダーの表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url
    assert_response :success
    assert_select "#shift-calendar-container", count: 1
  end

  test "オーナーでの賃金ゲージの表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url
    assert_response :success
    assert_select ".employee-list", count: 1
  end

  test "従業員での賃金ゲージの表示" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shifts_url
    assert_response :success
    assert_select ".wage-gauge", count: 1
    assert_select ".employee-list", count: 0
  end
end
