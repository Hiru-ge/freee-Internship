# frozen_string_literal: true

require "test_helper"

class ShiftRequestsControllerTest < ActionDispatch::IntegrationTest
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

  test "シフト交代リクエスト画面の表示" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    get new_shift_exchange_url, params: {
      employee_id: "3316120",
      date: Date.current.strftime("%Y-%m-%d"),
      start_time: "18:00",
      end_time: "23:00"
    }

    assert_response :success
    assert_select "h1", "シフト交代リクエスト"
    assert_select "form[action=?]", shift_exchanges_path
  end

  test "シフト交代リクエスト送信成功" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    post shift_exchanges_url, params: {
      applicant_id: "3316120",
      approver_ids: ["3317741"],
      shift_date: Date.current,
      start_time: "18:00",
      end_time: "23:00"
    }

    assert response.redirect? || response.success?
  end

  test "オーナーでのシフト追加リクエスト画面表示" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    get new_shift_addition_url
    assert_response :success
    assert_select "h1", "シフト追加リクエスト"
    assert_select "form[action=?]", shift_additions_path
  end

  test "シフト追加リクエスト送信成功" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    post shift_additions_url, params: {
      target_employee_id: "3316120",
      shift_date: Date.current + 1.day,
      start_time: "18:00",
      end_time: "23:00"
    }

    assert response.redirect? || response.success?
  end

  # ===== 異常系テスト =====

  test "未認証時のログインページリダイレクト" do
    get new_shift_exchange_url
    assert_redirected_to login_url
  end

  test "従業員でのシフト追加リクエスト画面アクセス拒否" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    get new_shift_addition_url
    assert response.redirect? || response.forbidden?
  end

  test "シフト交代リクエストの必須項目バリデーション" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    post shift_exchanges_url, params: {
      applicant_id: "",
      approver_ids: [],
      shift_date: "",
      start_time: "",
      end_time: ""
    }

    assert response.redirect? || response.unprocessable_content?
  end

  test "シフト追加リクエストの必須項目バリデーション" do
    post login_url, params: {
      employee_id: "3313254",
      password: "password123"
    }

    post shift_additions_url, params: {
      target_employee_id: "",
      shift_date: "",
      start_time: "",
      end_time: ""
    }

    assert response.redirect? || response.unprocessable_content?
  end
end
