# frozen_string_literal: true

require "test_helper"

class ClockServiceTest < ActiveSupport::TestCase
  def setup
    @employee_id = "test_employee_id"
    @service = ClockService.new(@employee_id)
  end

  # ===== 打刻機能テスト =====

  test "出勤打刻" do
    # 出勤打刻の基本動作をテスト
    result = @service.clock_in
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "退勤打刻" do
    # 退勤打刻の基本動作をテスト
    result = @service.clock_out
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "打刻状態の取得" do
    # 打刻状態取得の基本動作をテスト
    result = @service.get_clock_status
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:can_clock_in)
    assert result.key?(:can_clock_out)
    assert result.key?(:message)
  end

  test "月次勤怠データの取得" do
    # 月次勤怠データ取得の基本動作をテスト
    result = @service.get_attendance_for_month(Date.current.year, Date.current.month)
    assert_not_nil result
    assert result.is_a?(Array)
  end

  # ===== 打刻リマインダー機能テスト =====

  test "出勤打刻忘れチェック" do
    # 出勤打刻忘れチェックの基本動作をテスト
    # メソッドが正常に実行されることを確認（戻り値はvoid）
    assert_nothing_raised { ClockService.check_forgotten_clock_ins }
  end

  test "退勤打刻忘れチェック" do
    # 退勤打刻忘れチェックの基本動作をテスト
    # メソッドが正常に実行されることを確認（戻り値はvoid）
    assert_nothing_raised { ClockService.check_forgotten_clock_outs }
  end

  test "今日の打刻記録を取得" do
    # 今日の打刻記録取得の基本動作をテスト
    result = @service.get_time_clocks_for_today(@employee_id)
    assert_not_nil result
    assert result.is_a?(Array)
  end

  test "出勤打刻リマインダーメール送信" do
    # 出勤打刻リマインダーメール送信の基本動作をテスト
    employee = Employee.create!(employee_id: "test_employee", role: "employee")
    shift = Shift.create!(employee_id: employee.employee_id, shift_date: Date.current, start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("18:00"))

    # メソッドが正常に実行されることを確認（戻り値はvoid）
    assert_nothing_raised { @service.send_clock_in_reminder(employee, shift) }

    # クリーンアップ
    shift.destroy
    employee.destroy
  end

  test "退勤打刻リマインダーメール送信" do
    # 退勤打刻リマインダーメール送信の基本動作をテスト
    employee = Employee.create!(employee_id: "test_employee", role: "employee")
    shift = Shift.create!(employee_id: employee.employee_id, shift_date: Date.current, start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("18:00"))

    # メソッドが正常に実行されることを確認（戻り値はvoid）
    assert_nothing_raised { @service.send_clock_out_reminder(employee, shift) }

    # クリーンアップ
    shift.destroy
    employee.destroy
  end

  # ===== プライベートメソッドテスト =====
  # プライベートメソッドのテストは削除（意味のないassert trueテストのため）
end
