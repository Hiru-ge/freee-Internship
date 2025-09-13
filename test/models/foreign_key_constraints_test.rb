require "test_helper"

class ForeignKeyConstraintsTest < ActiveSupport::TestCase
  # 外部キー制約のテスト
  # t-wadaのTDD手法に従い、まずテストを書いてから実装する

  test "shifts should have foreign key constraint to employees" do
    # 存在しないemployee_idでshiftを作成しようとするとエラーになることを確認
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Shift.create!(
        employee_id: "non_existent_employee",
        shift_date: Date.current,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end
  end

  test "shift_exchanges should have foreign key constraint to employees for requester" do
    # 存在しないrequester_idでshift_exchangeを作成しようとするとエラーになることを確認
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftExchange.create!(
        request_id: "test_request_1",
        requester_id: "non_existent_employee",
        approver_id: "3313254",
        shift_id: 1
      )
    end
  end

  test "shift_exchanges should have foreign key constraint to employees for approver" do
    # 存在しないapprover_idでshift_exchangeを作成しようとするとエラーになることを確認
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftExchange.create!(
        request_id: "test_request_2",
        requester_id: "3313254",
        approver_id: "non_existent_employee",
        shift_id: 1
      )
    end
  end

  test "shift_additions should have foreign key constraint to employees for target_employee" do
    # 存在しないtarget_employee_idでshift_additionを作成しようとするとエラーになることを確認
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftAddition.create!(
        request_id: "test_request_3",
        target_employee_id: "non_existent_employee",
        shift_date: Date.current,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end
  end

  test "shift_additions should have foreign key constraint to employees for requester" do
    # 存在しないrequester_idでshift_additionを作成しようとするとエラーになることを確認
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

  test "verification_codes should have foreign key constraint to employees" do
    # 存在しないemployee_idでverification_codeを作成しようとするとエラーになることを確認
    # Railsのバリデーションが先に実行されるため、RecordInvalidが発生する
    assert_raises(ActiveRecord::RecordInvalid) do
      VerificationCode.create!(
        employee_id: "non_existent_employee",
        code: "123456",
        expires_at: 1.hour.from_now
      )
    end
  end

  test "shifts should have foreign key constraint to employees for original_employee_id" do
    # 存在しないoriginal_employee_idでshiftを作成しようとするとエラーになることを確認
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

  test "shift_exchanges should have foreign key constraint to shifts" do
    # 存在しないshift_idでshift_exchangeを作成しようとするとエラーになることを確認
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ShiftExchange.create!(
        request_id: "test_request_5",
        requester_id: "3313254",
        approver_id: "3313254",
        shift_id: 99999
      )
    end
  end

  test "valid foreign key references should work" do
    # 有効な外部キー参照でレコードが作成できることを確認
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
end
