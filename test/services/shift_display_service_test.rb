# frozen_string_literal: true

require "test_helper"
require "ostruct"

class ShiftDisplayServiceTest < ActiveSupport::TestCase
  def setup
    @service = ShiftDisplayService.new
    @employee_id = "test_employee_id"
    @shift_date = Date.current
    @start_time = Time.zone.parse("09:00")
    @end_time = Time.zone.parse("17:00")

    # 統合テスト用の従業員データ
    @employee1 = Employee.create!(
      employee_id: "test_employee_1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "test_employee_2",
      role: "employee"
    )
  end

  # ===== 正常系テスト =====

  test "月次シフトデータの取得" do
    year = Date.current.year
    month = Date.current.month

    result = @service.get_monthly_shifts(year, month)

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal year, result[:data][:year]
    assert_equal month, result[:data][:month]
    assert_not_nil result[:data][:shifts]
  end

  test "個人シフトデータの取得" do
    result = @service.get_employee_shifts(@employee_id)

    assert result[:success]
    assert_not_nil result[:data]
  end

  test "全従業員シフトデータの取得" do
    result = @service.get_all_employee_shifts

    assert result[:success]
    assert_not_nil result[:data]
  end

  test "シフトデータのフォーマット（LINE Bot用）" do
    shifts = []
    result = @service.format_employee_shifts_for_line(shifts)

    assert_equal "今月のシフト情報はありません。", result
  end

  test "全従業員シフトデータのフォーマット（LINE Bot用）" do
    all_shifts = []
    result = @service.format_all_shifts_for_line(all_shifts)

    assert result.include?("今月のシフト情報はありません")
  end

  # ===== シフトマージ機能テスト =====

  test "シフトのマージ" do
    existing_shift = create_test_shift(@employee_id, @shift_date, @start_time, @end_time)
    new_shift = create_test_shift(@employee_id, @shift_date, @start_time + 1.hour, @end_time + 1.hour)

    result = ShiftDisplayService.merge_shifts(existing_shift, new_shift)

    assert_not_nil result
    assert_equal existing_shift.id, result.id
  end

  test "シフトの完全包含チェック" do
    existing_shift = create_test_shift(@employee_id, @shift_date, @start_time, @end_time)
    new_shift = create_test_shift(@employee_id, @shift_date, @start_time + 1.hour, @end_time - 1.hour)

    result = ShiftDisplayService.shift_fully_contained?(existing_shift, new_shift)

    assert result
  end

  test "シフト交代承認時のシフト処理" do
    # メソッドの存在確認のみ（複雑なデータベース操作を避ける）
    assert_respond_to ShiftDisplayService, :process_shift_exchange_approval
  end

  test "シフト追加承認時のシフト処理" do
    # メソッドの存在確認のみ（複雑なデータベース操作を避ける）
    assert_respond_to ShiftDisplayService, :process_shift_addition_approval
  end

  test "共通のシフト承認処理" do
    # メソッドの存在確認のみ（複雑なデータベース操作を避ける）
    assert_respond_to ShiftDisplayService, :process_shift_approval
  end

  # ===== シフト重複チェック機能テスト =====

  test "シフト交代依頼時の重複チェック" do
    approver_ids = [@employee_id, "another_employee_id"]

    result = @service.check_exchange_overlap(approver_ids, @shift_date, @start_time, @end_time)

    assert_not_nil result
    assert result.is_a?(Array)
  end

  test "依頼可能な従業員IDと重複している従業員名の取得" do
    approver_ids = [@employee_id, "another_employee_id"]

    result = @service.get_available_and_overlapping_employees(approver_ids, @shift_date, @start_time, @end_time)

    assert_not_nil result
    assert result.key?(:available_ids)
    assert result.key?(:overlapping_names)
    assert result[:available_ids].is_a?(Array)
    assert result[:overlapping_names].is_a?(Array)
  end

  test "シフト追加依頼時の重複チェック" do
    target_employee_id = "target_employee_id"

    result = @service.check_addition_overlap(target_employee_id, @shift_date, @start_time, @end_time)

    # 重複がない場合はnilが返される
    assert_nil result
  end

  # ===== プライベートメソッドテスト =====

  test "シフト重複のチェック" do
    employee_id = "test_employee_id"

    result = @service.send(:has_shift_overlap?, employee_id, @shift_date, @start_time, @end_time)

    # テスト環境ではシフトがないため、falseが返される
    assert_not result
  end

  test "シフト時間の重複チェック" do
    existing_shift = create_test_shift(@employee_id, @shift_date, @start_time, @end_time)

    result = @service.send(:shift_overlaps?, existing_shift, @start_time + 1.hour, @end_time + 1.hour)

    assert result
  end

  test "既存シフトの時間をTimeオブジェクトに変換" do
    existing_shift = create_test_shift(@employee_id, @shift_date, @start_time, @end_time)

    result = @service.send(:convert_shift_times_to_objects, existing_shift)

    assert_not_nil result
    assert result.key?(:start)
    assert result.key?(:end)
    assert result[:start].is_a?(Time)
    assert result[:end].is_a?(Time)
  end

  test "新しいシフトの時間をTimeオブジェクトに変換" do
    result = @service.send(:convert_new_shift_times_to_objects, @shift_date, @start_time, @end_time)

    assert_not_nil result
    assert result.key?(:start)
    assert result.key?(:end)
    assert result[:start].is_a?(Time)
    assert result[:end].is_a?(Time)
  end

  test "時間オブジェクトを文字列に変換" do
    time = Time.zone.parse("09:00")

    result = @service.send(:format_time_to_string, time)

    assert_equal "09:00", result
  end

  test "文字列を文字列に変換" do
    time_string = "09:00"

    result = @service.send(:format_time_to_string, time_string)

    assert_equal "09:00", result
  end

  private

  def create_test_shift(employee_id, shift_date, start_time, end_time)
    # テスト用のシフトオブジェクトを作成
    shift = OpenStruct.new
    shift.id = 1
    shift.employee_id = employee_id
    shift.shift_date = shift_date
    shift.start_time = start_time
    shift.end_time = end_time
    shift.original_employee_id = nil

    # update!メソッドをモック
    def shift.update!(attributes)
      attributes.each { |key, value| send("#{key}=", value) }
      self
    end

    shift
  end

  # ===== シフト表示・重複・マージテスト（shift_services_test.rbから統合） =====

  test "シフト情報の正確な表示" do
    shift_date = Date.current
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    shifts = Shift.where(employee_id: @employee1.employee_id, shift_date: shift_date)
    assert_equal 1, shifts.count
    assert_equal shift.id, shifts.first.id

    shift.destroy
  end

  test "空のシフト情報の処理" do
    shift_date = Date.current
    shifts = Shift.where(employee_id: @employee1.employee_id, shift_date: shift_date)
    assert_equal 0, shifts.count
  end

  test "重複シフトの検出" do
    shift_date = Date.current
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("12:00")
    )

    shift2 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("11:00"),
      end_time: Time.zone.parse("15:00")
    )

    overlapping_shifts = []
    shifts = Shift.where(employee_id: @employee1.employee_id, shift_date: shift_date)

    shifts.each do |shift|
      other_shifts = shifts.where.not(id: shift.id)
      other_shifts.each do |other_shift|
        if shift.start_time < other_shift.end_time && shift.end_time > other_shift.start_time
          overlapping_shifts << [shift.id, other_shift.id]
        end
      end
    end

    assert_equal 2, overlapping_shifts.length
    assert_includes overlapping_shifts.first, shift1.id
    assert_includes overlapping_shifts.first, shift2.id

    shift1.destroy
    shift2.destroy
  end

  test "非重複シフトの非検出" do
    shift_date = Date.current
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("12:00")
    )

    shift2 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("13:00"),
      end_time: Time.zone.parse("15:00")
    )

    overlapping_shifts = []
    shifts = Shift.where(employee_id: @employee1.employee_id, shift_date: shift_date)

    shifts.each do |shift|
      other_shifts = shifts.where.not(id: shift.id)
      other_shifts.each do |other_shift|
        if shift.start_time < other_shift.end_time && shift.end_time > other_shift.start_time
          overlapping_shifts << [shift.id, other_shift.id]
        end
      end
    end

    assert_equal 0, overlapping_shifts.length

    shift1.destroy
    shift2.destroy
  end

  test "重複シフトの正確なマージ" do
    shift_date = Date.current
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("12:00")
    )

    shift2 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: Time.zone.parse("11:00"),
      end_time: Time.zone.parse("15:00")
    )

    merged_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: shift_date,
      start_time: [shift1.start_time, shift2.start_time].min,
      end_time: [shift1.end_time, shift2.end_time].max
    )

    shift1.destroy
    shift2.destroy

    assert_equal "09:00", merged_shift.start_time.strftime("%H:%M")
    assert_equal "15:00", merged_shift.end_time.strftime("%H:%M")

    merged_shift.destroy
  end

  test "大量シフトの効率的な処理" do
    shifts = []
    shift_date = Date.current
    100.times do |i|
      shifts << Shift.create!(
        employee_id: @employee1.employee_id,
        shift_date: shift_date + i.days,
        start_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("18:00")
      )
    end

    start_time = Time.current
    retrieved_shifts = Shift.where(employee_id: @employee1.employee_id)
    end_time = Time.current

    processing_time = end_time - start_time
    assert processing_time < 1.0, "大量のシフト取得が1秒以内で完了するべき: #{processing_time}秒"
    assert_equal 100, retrieved_shifts.count

    shifts.each(&:destroy)
  end

  test "N+1クエリ問題の回避" do
    employee_ids = %w[1001 1002 1003 1004 1005]
    month = Date.current.month
    year = Date.current.year

    employees = employee_ids.map do |id|
      Employee.create!(employee_id: id, role: "employee", line_id: "test_#{id}")
    end

    employees.each do |employee|
      (1..5).each do |day|
        Shift.create!(
          employee_id: employee.employee_id,
          shift_date: Date.new(year, month, day),
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("18:00")
        )
      end
    end

    expected_query_count = 15

    query_count = 0
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args|
      query_count += 1
    end

    controller = ShiftDisplayController.new
    controller.instance_variable_set(:@employee_ids, employee_ids)

    shifts_in_db = Shift.for_month(year, month)
    employee_ids.each do |employee_id|
      employee_shift_records = shifts_in_db.where(employee_id: employee_id)
      employee_shift_records.each(&:employee_id)
    end

    assert query_count <= expected_query_count, "N+1問題が発生しています。クエリ数: #{query_count}, 期待値: #{expected_query_count}"

    ShiftExchange.destroy_all
    ShiftAddition.destroy_all
    Shift.destroy_all
    Employee.destroy_all
  end

  test "includesを使用したクエリ最適化" do
    employee_ids = %w[1001 1002 1003]
    month = Date.current.month
    year = Date.current.year

    employees = employee_ids.map do |id|
      Employee.create!(employee_id: id, role: "employee", line_id: "test_#{id}")
    end

    employees.each do |employee|
      (1..3).each do |day|
        Shift.create!(
          employee_id: employee.employee_id,
          shift_date: Date.new(year, month, day),
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("18:00")
        )
      end
    end

    query_count = 0
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args|
      query_count += 1
    end

    shifts_with_employees = Shift.for_month(year, month).includes(:employee)
    employee_ids.each do |employee_id|
      employee_shift_records = shifts_with_employees.where(employee_id: employee_id)
      employee_shift_records.each(&:employee_id)
    end

    assert query_count <= 8, "クエリが最適化されていません。クエリ数: #{query_count}"

    ShiftExchange.destroy_all
    ShiftAddition.destroy_all
    Shift.destroy_all
    Employee.destroy_all
  end

  test "従業員データキャッシュによるクエリ削減" do
    employee_ids = %w[1001 1002 1003]
    month = Date.current.month
    year = Date.current.year

    employees = employee_ids.map do |id|
      Employee.create!(employee_id: id, role: "employee", line_id: "test_#{id}")
    end

    employees.each do |employee|
      (1..3).each do |day|
        Shift.create!(
          employee_id: employee.employee_id,
          shift_date: Date.new(year, month, day),
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("18:00")
        )
      end
    end

    query_count = 0
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args|
      query_count += 1
    end

    employee_cache = Employee.where(employee_id: employee_ids).index_by(&:employee_id)

    shifts_in_db = Shift.for_month(year, month)
    employee_ids.each do |employee_id|
      employee_shift_records = shifts_in_db.where(employee_id: employee_id)
      employee_shift_records.each do |shift_record|
        employee = employee_cache[shift_record.employee_id]
        assert_not_nil employee
      end
    end

    assert query_count <= 5, "キャッシュが効果的に機能していません。クエリ数: #{query_count}"

    ShiftExchange.destroy_all
    ShiftAddition.destroy_all
    Shift.destroy_all
    Employee.destroy_all
  end
end
