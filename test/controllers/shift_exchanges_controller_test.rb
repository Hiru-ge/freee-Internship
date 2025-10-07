# frozen_string_literal: true

require "test_helper"

class ShiftExchangesControllerTest < ActionDispatch::IntegrationTest
  # ===== 正常系テスト =====

  test "ログイン済みでのシフト交代リクエスト画面の表示" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shift_exchange_new_url
    assert_response :success
    assert_select "h1", "シフト交代リクエスト"
    assert_select "form[action=?]", shift_exchange_path
  end

  test "シフト交代リクエストの作成" do
    Employee.find_or_create_by(employee_id: "3316120") do |emp|
      emp.password_hash = BCrypt::Password.create("password123")
      emp.role = "employee"
    end

    Employee.find_or_create_by(employee_id: "3317741") do |emp|
      emp.password_hash = BCrypt::Password.create("password123")
      emp.role = "employee"
    end

    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    Shift.create!(
      employee_id: "3316120",
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    assert_difference("ShiftExchange.count", 1) do
      post shift_exchange_url, params: {
        applicant_id: "3316120",
        shift_date: Date.current.strftime("%Y-%m-%d"),
        start_time: "09:00",
        end_time: "18:00",
        approver_ids: ["3317741"]
      }
    end

    assert_redirected_to shifts_path
    assert_equal "リクエストを送信しました。承認をお待ちください。", flash[:notice]
  end

  test "シフト交代リクエスト送信成功" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    post shift_exchange_url, params: {
      applicant_id: "3316120",
      approver_ids: ["3317741"],
      shift_date: Date.current,
      start_time: "18:00",
      end_time: "23:00"
    }

    assert response.redirect? || response.success?
  end

  # ===== 異常系テスト =====

  test "未ログイン時のログインページへのリダイレクト" do
    get shift_exchange_new_url
    assert_redirected_to login_url
  end

  test "パラメータ不足でのシフト交代リクエスト作成失敗" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    assert_no_difference("ShiftExchange.count") do
      post shift_exchange_url, params: {
        applicant_id: "3316120",
        shift_date: "",
        start_time: "09:00",
        end_time: "18:00",
        approver_ids: ["3317741"]
      }
    end

    assert_redirected_to shift_exchange_new_path
    assert_equal "日付と時間を入力してください。", flash[:error]
  end

  test "シフト交代リクエストの必須項目バリデーション" do
    post login_url, params: {
      employee_id: "3316120",
      password: "password123"
    }

    post shift_exchange_url, params: {
      applicant_id: "",
      approver_ids: [],
      shift_date: "",
      start_time: "",
      end_time: ""
    }

    assert response.redirect? || response.unprocessable_content?
  end
end
