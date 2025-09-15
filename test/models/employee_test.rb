require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  def setup
    @employee = Employee.new(
      employee_id: "EMP001",
      role: "employee",
      password_hash: "hashed_password"
    )
  end

  test "should have line_id attribute" do
    # line_idカラムが存在することを確認
    assert @employee.respond_to?(:line_id)
    assert @employee.respond_to?(:line_id=)
  end

  test "should allow nil line_id" do
    # line_idはNULL許可
    @employee.line_id = nil
    assert @employee.valid?
  end

  test "should validate line_id uniqueness" do
    # line_idのユニーク制約テスト
    line_id = "U1234567890abcdef"
    @employee.line_id = line_id
    @employee.save!
    
    duplicate_employee = Employee.new(
      employee_id: "EMP002",
      role: "employee",
      password_hash: "hashed_password",
      line_id: line_id
    )
    
    # 同じline_idは使用できない
    assert_not duplicate_employee.valid?
  end

  test "should link to line account" do
    # LINEアカウントとの紐付けテスト
    line_id = "U1234567890abcdef"
    @employee.line_id = line_id
    
    # まだline_idカラムがないため、このテストは失敗する
    assert_equal line_id, @employee.line_id
  end
end
