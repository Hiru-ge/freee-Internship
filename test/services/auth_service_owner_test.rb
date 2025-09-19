# frozen_string_literal: true

require "test_helper"

class AuthServiceOwnerTest < ActiveSupport::TestCase
  def setup
    @original_owner_id = ENV["OWNER_EMPLOYEE_ID"]
    ENV.delete("OWNER_EMPLOYEE_ID")
  end

  def teardown
    if @original_owner_id
      ENV["OWNER_EMPLOYEE_ID"] = @original_owner_id
    else
      ENV.delete("OWNER_EMPLOYEE_ID")
    end
  end

  test "should return false when OWNER_EMPLOYEE_ID is not set" do
    # 環境変数が設定されていない場合
    ENV.delete("OWNER_EMPLOYEE_ID")

    result = AuthService.is_owner?("3313254")
    assert_equal false, result
  end

  test "should return employee role when employee_id does not match OWNER_EMPLOYEE_ID" do
    # 環境変数を設定
    ENV["OWNER_EMPLOYEE_ID"] = "3313254"

    employee_info = { "id" => 3316116, "display_name" => "テスト太郎" }
    result = AuthService.determine_role_from_freee(employee_info)

    assert_equal "employee", result
  end

  test "should return owner role when employee_id matches OWNER_EMPLOYEE_ID" do
    # 環境変数を設定
    ENV["OWNER_EMPLOYEE_ID"] = "3313254"

    employee_info = { "id" => 3313254, "display_name" => "店長太郎" }
    result = AuthService.determine_role_from_freee(employee_info)

    assert_equal "owner", result
  end

  test "should return employee role when OWNER_EMPLOYEE_ID is not set" do
    # 環境変数が設定されていない場合
    ENV.delete("OWNER_EMPLOYEE_ID")

    employee_info = { "id" => 3313254, "display_name" => "店長太郎" }
    result = AuthService.determine_role_from_freee(employee_info)

    assert_equal "employee", result
  end
end
