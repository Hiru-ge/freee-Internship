# frozen_string_literal: true

require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  def setup
    @employee = Employee.new(
      employee_id: "EMP001",
      role: "employee",
      password_hash: "hashed_password"
    )
  end

  # ===== 正常系テスト =====

  test "line_id属性の存在確認" do
    assert @employee.respond_to?(:line_id)
    assert @employee.respond_to?(:line_id=)

    @employee.line_id = "line_user_123"
    assert_equal "line_user_123", @employee.line_id
    assert @employee.valid?

    @employee.line_id = nil
    assert_nil @employee.line_id
    assert @employee.valid?
  end

  test "nilのline_idの許可" do
    @employee.line_id = nil
    assert @employee.valid?
  end

  test "LINEアカウントとの紐付け" do
    line_id = "U1234567890abcdef"
    @employee.line_id = line_id
    assert_equal line_id, @employee.line_id
  end

  # ===== 異常系テスト =====

  test "line_idのユニーク制約" do
    line_id = "U1234567890abcdef"
    @employee.line_id = line_id
    @employee.save!

    duplicate_employee = Employee.new(
      employee_id: "EMP002",
      role: "employee",
      password_hash: "hashed_password",
      line_id: line_id
    )

    assert_not duplicate_employee.valid?
  end
end
