# frozen_string_literal: true

require "test_helper"

class SeedsDynamicTest < ActiveSupport::TestCase
  def setup
    @original_owner_id = ENV["OWNER_EMPLOYEE_ID"]
  end

  def teardown
    if @original_owner_id
      ENV["OWNER_EMPLOYEE_ID"] = @original_owner_id
    else
      ENV.delete("OWNER_EMPLOYEE_ID")
    end
  end

  # ===== 正常系テスト =====

  test "環境変数設定時のオーナー役割判定" do
    ENV["OWNER_EMPLOYEE_ID"] = "3313254"

    employee_ids = ["3313254", "3316116", "3316120"]

    roles = employee_ids.map do |employee_id|
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["owner", "employee", "employee"], roles
  end

  test "環境変数未設定時の全従業員employee役割判定" do
    ENV.delete("OWNER_EMPLOYEE_ID")

    employee_ids = ["3316116", "3316120", "3317741"]

    roles = employee_ids.map do |employee_id|
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["employee", "employee", "employee"], roles
  end

  test "単一従業員の役割判定" do
    ENV.delete("OWNER_EMPLOYEE_ID")

    employee_ids = ["3313254"]

    role = if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_ids.first == ENV["OWNER_EMPLOYEE_ID"].strip
             "owner"
           else
             "employee"
           end

    assert_equal "employee", role
  end

  # ===== 異常系テスト =====

  test "空の従業員リストの処理" do
    ENV.delete("OWNER_EMPLOYEE_ID")

    employee_ids = []
    owner_id = ENV["OWNER_EMPLOYEE_ID"] || employee_ids.first

    assert_nil owner_id
  end

  test "空文字列OWNER_EMPLOYEE_IDの処理" do
    ENV["OWNER_EMPLOYEE_ID"] = ""
    employee_ids = ["3313254", "3316116"]

    roles = employee_ids.map do |employee_id|
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["employee", "employee"], roles
  end

  test "空白文字のみOWNER_EMPLOYEE_IDの処理" do
    ENV["OWNER_EMPLOYEE_ID"] = "   "
    employee_ids = ["3313254", "3316116"]

    roles = employee_ids.map do |employee_id|
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["employee", "employee"], roles
  end
end
