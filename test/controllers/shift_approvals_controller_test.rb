# frozen_string_literal: true

require "test_helper"

class ShiftApprovalsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @employee = Employee.find_or_create_by(employee_id: "3316120") do |emp|
      emp.password_hash = BCrypt::Password.create("password123")
      emp.role = "employee"
    end

    @approver = Employee.find_or_create_by(employee_id: "3317741") do |emp|
      emp.password_hash = BCrypt::Password.create("password123")
      emp.role = "owner"
    end

    @shift = Shift.create!(
      employee_id: @employee.employee_id,
      shift_date: Date.current,
      start_time: Time.parse("09:00"),
      end_time: Time.parse("17:00")
    )

    @shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_123",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )
  end

  # ===== 正常系テスト =====

  test "シフト削除リクエスト一覧の表示" do
    post login_url, params: {
      employee_id: @approver.employee_id,
      password: "password123"
    }

    get shift_approvals_path
    assert_response :success
    assert_select "h1", "自分へのシフトリクエスト一覧"
  end

  test "シフト削除の承認" do
    post login_url, params: {
      employee_id: @approver.employee_id,
      password: "password123"
    }

    shift_deletion = ShiftDeletion.find_by(request_id: @shift_deletion.request_id)
    shift_deletion.approve!
    shift_deletion.shift.destroy!

    @shift_deletion.reload
    assert_equal "approved", @shift_deletion.status
    assert_equal 0, Shift.where(id: @shift.id).count
  end

  test "シフト削除の拒否" do
    post login_url, params: {
      employee_id: @approver.employee_id,
      password: "password123"
    }

    shift_deletion = ShiftDeletion.find_by(request_id: @shift_deletion.request_id)
    shift_deletion.reject!

    @shift_deletion.reload
    assert_equal "rejected", @shift_deletion.status
    assert_equal 1, Shift.where(id: @shift.id).count
  end

  # ===== 異常系テスト =====

  test "権限なしでのシフト削除承認の拒否" do
    post login_url, params: {
      employee_id: @employee.employee_id,
      password: "password123"
    }

    post approve_shift_approval_path, params: {
      request_id: @shift_deletion.request_id,
      request_type: "deletion"
    }

    assert_redirected_to shift_approvals_path
    assert_equal "このリクエストを承認する権限がありません", flash[:error]
  end
end
