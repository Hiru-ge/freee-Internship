# frozen_string_literal: true

require "test_helper"

class DatabaseIndexesTest < ActiveSupport::TestCase
  # データベースインデックスの最適化テスト
  # t-wadaのTDD手法に従い、まずテストを書いてから実装する

  test "employees table should have unique index on employee_id" do
    # employee_idのユニークインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:employees)
    employee_id_index = indexes.find { |index| index.columns == ["employee_id"] }

    assert_not_nil employee_id_index, "employee_idのインデックスが存在しません"
    assert employee_id_index.unique, "employee_idのインデックスがユニークではありません"
  end

  test "shifts table should have index on employee_id" do
    # employee_idのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shifts)
    employee_id_index = indexes.find { |index| index.columns == ["employee_id"] }

    assert_not_nil employee_id_index, "shiftsテーブルのemployee_idインデックスが存在しません"
  end

  test "shifts table should have index on shift_date" do
    # shift_dateのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shifts)
    shift_date_index = indexes.find { |index| index.columns == ["shift_date"] }

    assert_not_nil shift_date_index, "shiftsテーブルのshift_dateインデックスが存在しません"
  end

  test "shifts table should have composite index on shift_date, start_time, end_time" do
    # 複合インデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shifts)
    composite_index = indexes.find { |index| index.columns == %w[shift_date start_time end_time] }

    assert_not_nil composite_index, "shiftsテーブルの複合インデックスが存在しません"
  end

  test "shift_exchanges table should have index on requester_id" do
    # requester_idのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shift_exchanges)
    requester_id_index = indexes.find { |index| index.columns == ["requester_id"] }

    assert_not_nil requester_id_index, "shift_exchangesテーブルのrequester_idインデックスが存在しません"
  end

  test "shift_exchanges table should have index on approver_id" do
    # approver_idのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shift_exchanges)
    approver_id_index = indexes.find { |index| index.columns == ["approver_id"] }

    assert_not_nil approver_id_index, "shift_exchangesテーブルのapprover_idインデックスが存在しません"
  end

  test "shift_exchanges table should have index on status" do
    # statusのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shift_exchanges)
    status_index = indexes.find { |index| index.columns == ["status"] }

    assert_not_nil status_index, "shift_exchangesテーブルのstatusインデックスが存在しません"
  end

  test "shift_additions table should have index on target_employee_id" do
    # target_employee_idのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shift_additions)
    target_employee_id_index = indexes.find { |index| index.columns == ["target_employee_id"] }

    assert_not_nil target_employee_id_index, "shift_additionsテーブルのtarget_employee_idインデックスが存在しません"
  end

  test "shift_additions table should have index on requester_id" do
    # requester_idのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shift_additions)
    requester_id_index = indexes.find { |index| index.columns == ["requester_id"] }

    assert_not_nil requester_id_index, "shift_additionsテーブルのrequester_idインデックスが存在しません"
  end

  test "shift_additions table should have index on status" do
    # statusのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:shift_additions)
    status_index = indexes.find { |index| index.columns == ["status"] }

    assert_not_nil status_index, "shift_additionsテーブルのstatusインデックスが存在しません"
  end

  test "verification_codes table should have index on employee_id" do
    # employee_idのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:verification_codes)
    employee_id_index = indexes.find { |index| index.columns == ["employee_id"] }

    assert_not_nil employee_id_index, "verification_codesテーブルのemployee_idインデックスが存在しません"
  end

  test "verification_codes table should have index on code" do
    # codeのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:verification_codes)
    code_index = indexes.find { |index| index.columns == ["code"] }

    assert_not_nil code_index, "verification_codesテーブルのcodeインデックスが存在しません"
  end

  test "verification_codes table should have index on expires_at" do
    # expires_atのインデックスが存在することを確認
    indexes = ActiveRecord::Base.connection.indexes(:verification_codes)
    expires_at_index = indexes.find { |index| index.columns == ["expires_at"] }

    assert_not_nil expires_at_index, "verification_codesテーブルのexpires_atインデックスが存在しません"
  end

  test "performance test for employee_id lookups" do
    # employee_idでの検索パフォーマンステスト
    employee = Employee.create!(
      employee_id: "perf_test_employee",
      password_hash: "hashed_password",
      role: "employee"
    )

    # 複数のshiftを作成
    10.times do |i|
      Shift.create!(
        employee_id: employee.employee_id,
        shift_date: Date.current + i.days,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end

    # employee_idでの検索が高速であることを確認（インデックスが効いている）
    start_time = Time.current
    shifts = Shift.where(employee_id: employee.employee_id)
    end_time = Time.current

    assert shifts.count == 10, "検索結果が期待値と異なります"
    assert (end_time - start_time) < 0.1, "検索が遅すぎます（インデックスが効いていない可能性）"
  end

  test "performance test for shift_date range queries" do
    # shift_dateでの範囲検索パフォーマンステスト
    employee = Employee.create!(
      employee_id: "perf_test_employee_2",
      password_hash: "hashed_password",
      role: "employee"
    )

    # 複数のshiftを作成
    30.times do |i|
      Shift.create!(
        employee_id: employee.employee_id,
        shift_date: Date.current + i.days,
        start_time: Time.parse("09:00"),
        end_time: Time.parse("17:00")
      )
    end

    # 日付範囲での検索が高速であることを確認
    start_time = Time.current
    shifts = Shift.where(shift_date: Date.current..(Date.current + 15.days))
    end_time = Time.current

    assert shifts.count == 16, "検索結果が期待値と異なります"
    assert (end_time - start_time) < 0.1, "検索が遅すぎます（インデックスが効いていない可能性）"
  end
end
