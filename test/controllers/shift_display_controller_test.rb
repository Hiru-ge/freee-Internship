# frozen_string_literal: true

require "test_helper"

class ShiftDisplayControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = employees(:owner)
    @employee = employees(:employee1)

    # テスト用シフトデータ
    @shift = Shift.create!(
      employee_id: "3316120",
      shift_date: Date.current,
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

    get shifts_data_url, params: { week: Date.current.strftime("%Y-%m-%d") }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["shifts"].is_a?(Hash)
    assert json_response["year"].is_a?(Integer)
    assert json_response["month"].is_a?(Integer)
  end

  test "オーナーとして従業員一覧の取得" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    get employees_wages_url
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    assert json_response.length.positive?
  end

  # ===== 異常系テスト =====

  test "未認証時のログインページへのリダイレクト" do
    get shifts_url
    assert_redirected_to login_url
  end

  test "従業員として従業員一覧へのアクセス拒否" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    get employees_wages_url
    assert_response :forbidden
  end

  test "週次ナビゲーション" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    get shifts_data_url, params: { week: 1.week.ago.strftime("%Y-%m-%d") }
    assert_response :success

    get shifts_data_url, params: { week: 1.week.from_now.strftime("%Y-%m-%d") }
    assert_response :success
  end

  test "シフトカレンダーの表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    get shifts_url
    assert_response :success
    assert_select "#shift-calendar-container", count: 1
  end

  test "オーナーでの賃金ゲージの表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    get shifts_url
    assert_response :success
    assert_select ".wage-gauge", count: 0
    assert_select ".employee-list", count: 1
  end

  test "従業員での賃金ゲージの表示" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    get shifts_url
    assert_response :success
    assert_select ".wage-gauge", count: 1
    assert_select ".employee-list", count: 0
  end
end
