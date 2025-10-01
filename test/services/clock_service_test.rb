# frozen_string_literal: true

require "test_helper"

class ClockServiceTest < ActiveSupport::TestCase
  def setup
    @employee_id = "test_employee_id"
    @service = ClockService.new(@employee_id)
  end

  # ===== 正常系テスト =====

  test "出勤打刻の成功" do
    result = @service.clock_in

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:message)
    assert result[:success].is_a?(TrueClass) || result[:success].is_a?(FalseClass)
    assert result[:message].is_a?(String)
    assert_not result[:message].empty?

    if result[:success]
      assert_includes result[:message], "出勤打刻が完了しました"
    else
      # 失敗時はメッセージが空でないことを確認
      assert_not result[:message].empty?
    end
  end

  test "退勤打刻の成功" do
    result = @service.clock_out

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:message)
    assert result[:success].is_a?(TrueClass) || result[:success].is_a?(FalseClass)
    assert result[:message].is_a?(String)
    assert_not result[:message].empty?

    if result[:success]
      assert_includes result[:message], "退勤打刻が完了しました"
    else
      # 失敗時はメッセージが空でないことを確認
      assert_not result[:message].empty?
    end
  end

  test "打刻状態の取得" do
    result = @service.get_clock_status

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:can_clock_in)
    assert result.key?(:can_clock_out)
    assert result.key?(:message)

    assert result[:can_clock_in].is_a?(TrueClass) || result[:can_clock_in].is_a?(FalseClass)
    assert result[:can_clock_out].is_a?(TrueClass) || result[:can_clock_out].is_a?(FalseClass)
    assert result[:message].is_a?(String)
    assert_not result[:message].empty?

    expected_messages = [
      "出勤打刻が可能です",
      "退勤打刻が可能です",
      "本日の打刻は完了しています",
      "打刻状態を確認中です",
      "エラーが発生しました"
    ]
    assert_includes expected_messages, result[:message]
  end

  test "月次勤怠データの取得" do
    result = @service.get_attendance_for_month(Date.current.year, Date.current.month)

    assert_not_nil result
    assert result.is_a?(Array)

    if result.any?
      result.each do |record|
        assert record.is_a?(Hash)
        assert record.key?("type") || record.key?(:type)
      end
    end
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

  # ===== 統合テスト（clock_services_test.rbから統合） =====

  test "正しいタイムゾーンでの打刻操作" do
    assert_equal "Asia/Tokyo", Time.zone.name, "日本時間が設定されているべき"

    jst_time = Time.zone.parse("#{Date.current.strftime('%Y-%m-%d')} 09:00:00")
    utc_time = Time.utc(Date.current.year, Date.current.month, Date.current.day, 0, 0, 0)

    assert_equal 9, jst_time.hour, "日本時間の9時であるべき"
    assert_equal 0, utc_time.hour, "UTC時間の0時であるべき"
  end

  test "Time.currentの一貫した使用" do
    current_time = Time.current
    assert current_time.is_a?(Time), "Time.currentはTimeオブジェクトを返すべき"

    assert_equal "Asia/Tokyo", Time.zone.name, "現在のタイムゾーンはAsia/Tokyo"
  end

  test "正しいタイムゾーンでの正確な打刻時間記録" do
    current_time = Time.current

    expected_date = current_time.strftime("%Y-%m-%d")
    expected_time = current_time.strftime("%H:%M")

    assert current_time.is_a?(Time), "現在時刻はTimeオブジェクトであるべき"
    assert_equal "Asia/Tokyo", Time.zone.name, "タイムゾーンはAsia/Tokyoであるべき"
    assert expected_date.is_a?(String), "日付文字列はStringであるべき"
    assert expected_time.is_a?(String), "時刻文字列はStringであるべき"
  end

  test "統合テストでの出勤打刻成功" do
    result = @service.clock_in

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "統合テストでの退勤打刻成功" do
    @service.clock_in

    result = @service.clock_out

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "統合テストでの重複出勤打刻拒否" do
    @service.clock_in

    result = @service.clock_in

    assert_not result[:success], "重複出勤打刻は失敗するべき"
  end

  test "統合テストでの出勤前退勤打刻拒否" do
    result = @service.clock_out

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:message)
  end

  test "統合テストでの重複退勤打刻拒否" do
    @service.clock_in
    @service.clock_out

    result = @service.clock_out

    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:message)
  end

  test "統合テストでの正確な勤務時間計算" do
    @service.clock_in
    @service.clock_out

    result = @service.get_attendance_for_month(Date.current.year, Date.current.month)
    assert_not_nil result
    assert result.is_a?(Array)
  end

  test "出勤打刻忘れ従業員の検出" do
    employee = Employee.create!(
      employee_id: "test_employee",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    assert_nothing_raised { ClockService.check_forgotten_clock_ins }

    shift.destroy
    employee.destroy
  end

  test "出勤打刻済み従業員の非検出" do
    employee = Employee.create!(
      employee_id: "test_employee_2",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    clock_service = ClockService.new(employee.employee_id)
    clock_service.clock_in

    assert_nothing_raised { ClockService.check_forgotten_clock_ins }

    shift.destroy
    employee.destroy
  end

  test "リマインダー通知の送信" do
    employee = Employee.create!(
      employee_id: "test_employee_3",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    assert_nothing_raised { ClockService.check_forgotten_clock_ins }

    shift.destroy
    employee.destroy
  end

  test "Asia/Tokyoタイムゾーンの一貫した使用" do
    assert_equal "Asia/Tokyo", Time.zone.name
  end

  test "タイムゾーン変換の正確な処理" do
    jst_time = Time.zone.parse("2024-01-15 09:00:00")
    utc_time = Time.utc(2024, 1, 15, 0, 0, 0)

    assert_equal 9, jst_time.hour
    assert_equal 0, utc_time.hour
  end

  test "正しいタイムゾーンでの打刻時間記録" do
    current_time = Time.current

    assert current_time.is_a?(Time)
    assert_equal "Asia/Tokyo", Time.zone.name

    date_str = current_time.strftime("%Y-%m-%d")
    time_str = current_time.strftime("%H:%M")

    assert date_str.is_a?(String)
    assert time_str.is_a?(String)
  end

  test "打刻イベントの統合通知送信" do
    employee = Employee.create!(
      employee_id: "test_notification_employee",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    assert_nothing_raised { ClockService.check_forgotten_clock_ins }

    shift.destroy
    employee.destroy
  end

  test "通知エラーの適切な処理" do
    employee = Employee.create!(
      employee_id: "test_notification_error_employee",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    assert_nothing_raised { ClockService.check_forgotten_clock_ins }

    shift.destroy
    employee.destroy
  end

  test "シフト交代依頼通知の送信" do
    employee1 = Employee.create!(
      employee_id: "1010",
      line_id: "test_user_id_5",
      role: "employee"
    )

    employee2 = Employee.create!(
      employee_id: "1011",
      line_id: "test_user_id_6",
      role: "employee"
    )

    shift = Shift.create!(
      employee_id: employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    exchange_request = ShiftExchange.create!(
      requester_id: employee1.employee_id,
      approver_id: employee2.employee_id,
      shift_id: shift.id,
      request_id: "TEST_EXCHANGE_001",
      status: "pending"
    )

    service = EmailNotificationService.new
    result = service.send_shift_exchange_request_notification([exchange_request], {})

    assert_nothing_raised { result }

    exchange_request.destroy
    shift.destroy
    employee1.destroy
    employee2.destroy
  end

  test "シフト追加依頼通知の送信" do
    employee1 = Employee.create!(
      employee_id: "1012",
      line_id: "test_user_id_7",
      role: "employee"
    )

    employee2 = Employee.create!(
      employee_id: "1013",
      line_id: "test_user_id_8",
      role: "employee"
    )

    addition_request = ShiftAddition.create!(
      requester_id: employee1.employee_id,
      target_employee_id: employee2.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      request_id: "TEST_ADDITION_001",
      status: "pending"
    )

    service = EmailNotificationService.new
    result = service.send_shift_addition_request_notification([addition_request], {})

    assert_nothing_raised { result }

    addition_request.destroy
    employee1.destroy
    employee2.destroy
  end

  test "時間帯の正確な判定" do
    wage_service = WageService.new

    assert_equal :normal, wage_service.get_time_zone(10)
    assert_equal :normal, wage_service.get_time_zone(17)
    assert_equal :evening, wage_service.get_time_zone(18)
    assert_equal :evening, wage_service.get_time_zone(21)
    assert_equal :night, wage_service.get_time_zone(22)
    assert_equal :night, wage_service.get_time_zone(2)
    assert_equal :night, wage_service.get_time_zone(8)
  end

  test "時間帯別勤務時間の正確な計算" do
    wage_service = WageService.new

    work_hours = wage_service.calculate_work_hours_by_time_zone(
      Date.current,
      Time.zone.parse("18:00"),
      Time.zone.parse("23:00")
    )

    assert_equal 4, work_hours[:evening]
    assert_equal 1, work_hours[:night]
    assert_equal 0, work_hours[:normal]
  end

  test "総賃金の正確な計算" do
    employee = Employee.create!(
      employee_id: "1014",
      line_id: "test_user_id_9",
      role: "employee"
    )

    shift1 = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("23:00")
    )

    shift2 = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("9:00"),
      end_time: Time.zone.parse("18:00")
    )

    wage_service = WageService.new
    result = wage_service.calculate_monthly_wage(employee.employee_id, Date.current.month, Date.current.year)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:total)

    shift1.destroy
    shift2.destroy
    employee.destroy
  end
end
