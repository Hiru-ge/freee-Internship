# frozen_string_literal: true

require "test_helper"

class ShiftDeletionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @employee = Employee.find_or_create_by(employee_id: "3316120") do |emp|
      emp.password_hash = BCrypt::Password.create("password123")
      emp.role = "employee"
    end
    @shift = Shift.create!(
      employee_id: @employee.employee_id,
      shift_date: Date.current,
      start_time: Time.parse("09:00"),
      end_time: Time.parse("17:00")
    )
  end

  # ===== 正常系テスト =====

  test "ログイン時のシフト削除申請画面表示" do
    post login_url, params: {
      employee_id: @employee.employee_id,
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    get shift_deletion_new_path, params: { shift_id: @shift.id }
    assert_response :success
    assert_select "form"
  end

  test "有効なパラメータでのシフト削除申請作成" do
    post login_url, params: {
      employee_id: @employee.employee_id,
      password: "password123"
    }
    assert_redirected_to dashboard_url
    follow_redirect!

    assert_difference("ShiftDeletion.count") do
      post shift_deletion_path, params: {
        shift_deletion: {
          shift_id: @shift.id,
          reason: "体調不良のため欠勤します"
        }
      }
    end

    assert_redirected_to shifts_path
    assert_equal "欠勤申請を送信しました。承認をお待ちください。", flash[:success]
  end

  # ===== 異常系テスト =====

  test "無効なパラメータでのシフト削除申請作成失敗" do
    post login_url, params: {
      employee_id: @employee.employee_id,
      password: "password123"
    }

    assert_no_difference("ShiftDeletion.count") do
      post shift_deletion_path, params: {
        shift_deletion: {
          shift_id: @shift.id,
          reason: ""
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "未認証時のログインページリダイレクト" do
    get shift_deletion_new_path, params: { shift_id: @shift.id }
    assert_redirected_to login_url
  end
end
