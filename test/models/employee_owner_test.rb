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

  test "should return true when role is owner" do
    @employee.update!(role: "owner")
    assert_equal true, @employee.owner?
  end

  test "should return false when role is employee" do
    @employee.update!(role: "employee")
    assert_equal false, @employee.owner?
  end

end
