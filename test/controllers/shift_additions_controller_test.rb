# frozen_string_literal: true

require "test_helper"

class ShiftAdditionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = employees(:owner)
    @employee1 = employees(:employee1)
    @employee2 = employees(:employee2)

    # テスト用シフトデータ
    @shift = Shift.create!(
      employee_id: "3316120",
      shift_date: Date.current,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("23:00")
    )
  end

  # ===== 正常系テスト =====

  test "オーナーでのシフト追加リクエスト画面表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shift_addition_new_url
    assert_response :success
    assert_select "h1", "シフト追加リクエスト"
    assert_select "form[action=?]", shift_addition_path
  end

  test "シフト追加リクエスト送信成功" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    post shift_addition_url, params: {
      employee_id: "3316120",
      shift_date: Date.current + 1.day,
      start_time: "18:00",
      end_time: "23:00"
    }

    assert_response :redirect
  end

  # ===== 異常系テスト =====

  test "従業員でのシフト追加リクエスト画面アクセス拒否" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    get shift_addition_new_url
    assert response.redirect? || response.forbidden?
  end

  test "シフト追加リクエストの必須項目バリデーション" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    post shift_addition_url, params: {
      employee_id: "",
      shift_date: "",
      start_time: "",
      end_time: ""
    }

    assert_response :success
    assert_select "body[data-flash-error*='必須項目']"
  end
end
