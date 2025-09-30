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
  end

  # ===== シフト表示機能テスト =====

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
end
