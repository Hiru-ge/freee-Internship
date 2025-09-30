# frozen_string_literal: true

require "test_helper"

class EmployeeOwnerTest < ActiveSupport::TestCase
  def setup
    @original_owner_id = ENV["OWNER_EMPLOYEE_ID"]
    # 既存のEmployeeレコードを使用するか、新しいIDで作成
    @employee = Employee.find_by(employee_id: "3313254") || Employee.create!(
      employee_id: "3313254",
      password_hash: BCrypt::Password.create("password123"),
      role: "employee"
    )
  end

  def teardown
    if @original_owner_id
      ENV["OWNER_EMPLOYEE_ID"] = @original_owner_id
    else
      ENV.delete("OWNER_EMPLOYEE_ID")
    end
  end

  # ===== 正常系テスト =====

  test "役割がオーナーの場合にtrueを返す" do
    @employee.update!(role: "owner")
    assert_equal true, @employee.owner?
  end

  # ===== 異常系テスト =====

  test "役割が従業員の場合にfalseを返す" do
    @employee.update!(role: "employee")
    assert_equal false, @employee.owner?
  end

end
