# frozen_string_literal: true

require "test_helper"

class ForeignKeyConstraintsTest < ActiveSupport::TestCase
  # ===== 正常系テスト =====

  test "有効な外部キー参照でのレコード作成成功" do
    employee = Employee.create!(
      employee_id: "test_employee_1",
      password_hash: "hashed_password",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.parse("09:00"),
      end_time: Time.parse("17:00")
    )

    assert shift.persisted?
    assert_equal employee.employee_id, shift.employee_id
  end

  # ===== 異常系テスト =====

  test "存在しないemployee_idでのshift作成エラー" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Shift.create!(
        employee_id: "non_existent_employee",
        shift_date: Date.current,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end
  end

  test "存在しないrequester_idでのshift_exchange作成エラー" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftExchange.create!(
        request_id: "test_request_1",
        requester_id: "non_existent_employee",
        approver_id: "3313254",
        shift_id: 1
      )
    end
  end

  test "存在しないapprover_idでのshift_exchange作成エラー" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftExchange.create!(
        request_id: "test_request_2",
        requester_id: "3313254",
        approver_id: "non_existent_employee",
        shift_id: 1
      )
    end
  end

  test "存在しないtarget_employee_idでのshift_addition作成エラー" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftAddition.create!(
        request_id: "test_request_3",
        target_employee_id: "non_existent_employee",
        requester_id: "3313254",
        shift_date: Date.current,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end
  end

  test "存在しないrequester_idでのshift_addition作成エラー" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftAddition.create!(
        request_id: "test_request_4",
        target_employee_id: "3313254",
        requester_id: "non_existent_employee",
        shift_date: Date.current,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end
  end

  test "存在しないemployee_idでのverification_code作成エラー" do
    assert_raises(ActiveRecord::RecordInvalid) do
      VerificationCode.create!(
        employee_id: "non_existent_employee",
        code: "123456",
        expires_at: 1.hour.from_now
      )
    end
  end

  test "存在しないoriginal_employee_idでのshift作成エラー" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Shift.create!(
        employee_id: "3313254",
        original_employee_id: "non_existent_employee",
        shift_date: Date.current,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end
  end

  test "存在しないshift_idでのshift_exchange作成エラー" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftExchange.create!(
        request_id: "test_request_5",
        requester_id: "3313254",
        approver_id: "3313254",
        shift_id: 99_999
      )
    end
  end
end
