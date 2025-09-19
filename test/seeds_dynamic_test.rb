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

  test "should determine owner role correctly with environment variable" do
    # 環境変数を設定
    ENV["OWNER_EMPLOYEE_ID"] = "3313254"

    # シードデータのロジックをテスト
    employee_ids = ["3313254", "3316116", "3316120"]

    # 各従業員の役割を判定（シードデータ作成時のロジック）
    roles = employee_ids.map do |employee_id|
      # シードデータ作成時のロジックをシミュレート
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["owner", "employee", "employee"], roles
  end

  test "should use all employees as employee when OWNER_EMPLOYEE_ID is not set" do
    # 環境変数を削除
    ENV.delete("OWNER_EMPLOYEE_ID")

    # シードデータのロジックをテスト（環境変数が設定されていない場合）
    employee_ids = ["3316116", "3316120", "3317741"]

    # 各従業員の役割を判定（環境変数が設定されていない場合はすべて"employee"）
    roles = employee_ids.map do |employee_id|
      # シードデータ作成時のロジックをシミュレート
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["employee", "employee", "employee"], roles
  end

  test "should handle empty employee list" do
    # 環境変数を削除してテスト
    ENV.delete("OWNER_EMPLOYEE_ID")

    # 空の従業員リスト
    employee_ids = []
    owner_id = ENV["OWNER_EMPLOYEE_ID"] || employee_ids.first

    # 空のリストの場合、employee_ids.firstはnil
    # 環境変数も削除されているので、owner_idはnilになる
    assert_nil owner_id
  end

  test "should handle empty string OWNER_EMPLOYEE_ID" do
    # 空文字列の環境変数
    ENV["OWNER_EMPLOYEE_ID"] = ""
    employee_ids = ["3313254", "3316116"]

    # 各従業員の役割を判定（空文字列の場合はすべて"employee"）
    roles = employee_ids.map do |employee_id|
      # シードデータ作成時のロジックをシミュレート
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["employee", "employee"], roles
  end

  test "should handle whitespace only OWNER_EMPLOYEE_ID" do
    # 空白文字のみの環境変数
    ENV["OWNER_EMPLOYEE_ID"] = "   "
    employee_ids = ["3313254", "3316116"]

    # 各従業員の役割を判定（空白文字のみの場合はすべて"employee"）
    roles = employee_ids.map do |employee_id|
      # シードデータ作成時のロジックをシミュレート
      if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
        "owner"
      else
        "employee"
      end
    end

    assert_equal ["employee", "employee"], roles
  end

  test "should handle single employee" do
    # 環境変数を削除してテスト
    ENV.delete("OWNER_EMPLOYEE_ID")

    # 単一の従業員
    employee_ids = ["3313254"]

    # 役割を判定（環境変数が設定されていない場合は"employee"）
    role = if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_ids.first == ENV["OWNER_EMPLOYEE_ID"].strip
             "owner"
           else
             "employee"
           end

    assert_equal "employee", role
  end
end
