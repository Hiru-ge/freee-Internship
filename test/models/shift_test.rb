# frozen_string_literal: true

require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  def setup
    # テスト用の従業員データ
    @employee1 = Employee.create!(
      employee_id: "test_employee_1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "test_employee_2",
      role: "employee"
    )
    @employee3 = Employee.create!(
      employee_id: "test_employee_3",
      role: "employee"
    )
  end

  def teardown
    # テストデータのクリーンアップ（外部キー制約を考慮した順序）
    ActiveRecord::Base.connection.disable_referential_integrity do
      ShiftExchange.delete_all
      ShiftAddition.delete_all
      ShiftDeletion.delete_all
      Shift.delete_all
      Employee.where(employee_id: ["test_employee_1", "test_employee_2", "test_employee_3"]).delete_all
    end
  end

  # ===== バリデーションテスト =====

  test "有効なShiftの作成" do
    shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    assert shift.valid?
  end

  test "必須項目のバリデーション" do
    shift = Shift.new

    assert_not shift.valid?
    assert shift.errors[:employee_id].present?
    assert shift.errors[:shift_date].present?
    assert shift.errors[:start_time].present?
    assert shift.errors[:end_time].present?
  end

  test "終了時間が開始時間より後でない場合のバリデーション" do
    shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("18:00:00"),
      end_time: Time.zone.parse("09:00:00")
    )

    assert_not shift.valid?
    assert_includes shift.errors[:end_time], "終了時間は開始時間より後である必要があります"
  end

  # ===== 重複チェック機能テスト（ShiftValidationServiceから移行） =====

  test "has_shift_overlap? - 重複する場合" do
    future_date = Date.current + 1.day
    Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    # 重複する時間帯
    overlap_result = Shift.has_shift_overlap?(
      @employee1.employee_id,
      future_date,
      Time.zone.parse("10:00:00"),
      Time.zone.parse("19:00:00")
    )

    assert overlap_result
  end

  test "has_shift_overlap? - 重複しない場合" do
    future_date = Date.current + 1.day
    Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("12:00:00")
    )

    # 重複しない時間帯
    no_overlap_result = Shift.has_shift_overlap?(
      @employee1.employee_id,
      future_date,
      Time.zone.parse("13:00:00"),
      Time.zone.parse("18:00:00")
    )

    assert_not no_overlap_result
  end

  test "get_available_and_overlapping_employees - 複数従業員の重複チェック" do
    future_date = Date.current + 1.day

    # employee1にシフトを作成
    Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("12:00:00")
    )

    result = Shift.get_available_and_overlapping_employees(
      [@employee1.employee_id, @employee2.employee_id, @employee3.employee_id],
      future_date,
      Time.zone.parse("10:00:00"),
      Time.zone.parse("18:00:00")
    )

    # employee1は重複、employee2とemployee3は利用可能
    assert_equal 2, result[:available_ids].count
    assert_includes result[:available_ids], @employee2.employee_id
    assert_includes result[:available_ids], @employee3.employee_id
    assert_equal 1, result[:overlapping_names].count
  end

  test "check_addition_overlap - 単一従業員の重複チェック" do
    future_date = Date.current + 1.day

    # employee1にシフトを作成
    Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("12:00:00")
    )

    # 重複する場合
    overlap_result = Shift.check_addition_overlap(
      @employee1.employee_id,
      future_date,
      Time.zone.parse("10:00:00"),
      Time.zone.parse("18:00:00")
    )
    assert_not_nil overlap_result

    # 重複しない場合
    no_overlap_result = Shift.check_addition_overlap(
      @employee2.employee_id,
      future_date,
      Time.zone.parse("10:00:00"),
      Time.zone.parse("18:00:00")
    )
    assert_nil no_overlap_result
  end

  test "check_deletion_eligibility - 削除可能性チェック" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    # 削除可能な場合
    result = Shift.check_deletion_eligibility(shift.id, @employee1.employee_id)
    assert result[:eligible]
    assert_equal shift, result[:shift]

    # 存在しないシフト
    not_found_result = Shift.check_deletion_eligibility(99999, @employee1.employee_id)
    assert_not not_found_result[:eligible]
    assert_includes not_found_result[:reason], "シフトが見つかりません"

    # 過去のシフト
    past_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current - 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )
    past_result = Shift.check_deletion_eligibility(past_shift.id, @employee1.employee_id)
    assert_not past_result[:eligible]
    assert_includes past_result[:reason], "過去のシフトは削除できません"
  end

  # ===== 表示機能テスト（ShiftDisplayServiceから移行） =====

  test "get_employee_shifts - 個人シフトデータの取得" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    result = Shift.get_employee_shifts(@employee1.employee_id)

    assert result[:success]
    assert_not_nil result[:data]
    assert_includes result[:data], shift
  end

  test "get_all_employee_shifts - 全従業員シフトデータの取得" do
    future_date = Date.current + 1.day
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )
    shift2 = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("10:00:00"),
      end_time: Time.zone.parse("19:00:00")
    )

    result = Shift.get_all_employee_shifts

    assert result[:success]
    assert_not_nil result[:data]
    assert result[:data].is_a?(Array)

    # 従業員名が含まれていることを確認
    employee_names = result[:data].map { |shift_data| shift_data[:employee_name] }
    assert_includes employee_names, @employee1.display_name
    assert_includes employee_names, @employee2.display_name
  end

  test "format_employee_shifts_for_line - LINE用フォーマット" do
    future_date = Date.current + 1.day
    shifts = [
      Shift.create!(
        employee_id: @employee1.employee_id,
        shift_date: future_date,
        start_time: Time.zone.parse("09:00:00"),
        end_time: Time.zone.parse("18:00:00")
      )
    ]

    result = Shift.format_employee_shifts_for_line(shifts)

    assert_includes result, "📅 今月のシフト"
    assert_includes result, future_date.strftime('%m/%d')
    assert_includes result, "09:00-18:00"
  end

  test "format_employee_shifts_for_line - 空のシフト" do
    result = Shift.format_employee_shifts_for_line([])
    assert_equal "今月のシフト情報はありません。", result
  end

  # ===== CRUD機能テスト =====

  test "create_with_validation - 正常なシフト作成" do
    future_date = Date.current + 1.day

    shift = Shift.create_with_validation(
      employee_id: @employee1.employee_id,
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00"
    )

    assert_not_nil shift
    assert_equal @employee1.employee_id, shift.employee_id
    assert_equal future_date, shift.shift_date
  end

  test "create_with_validation - 必須項目不足でのエラー" do
    assert_raises(ArgumentError, "必須項目が不足しています") do
      Shift.create_with_validation(
        employee_id: "",
        shift_date: Date.current + 1.day,
        start_time: "09:00",
        end_time: "18:00"
      )
    end
  end

  test "create_with_validation - 過去の日付でのエラー" do
    past_date = Date.current - 1.day

    assert_raises(ArgumentError, "過去の日付は指定できません") do
      Shift.create_with_validation(
        employee_id: @employee1.employee_id,
        shift_date: past_date.strftime("%Y-%m-%d"),
        start_time: "09:00",
        end_time: "18:00"
      )
    end
  end

  test "create_with_validation - 重複シフトでのエラー" do
    future_date = Date.current + 1.day

    # 最初のシフトを作成
    Shift.create_with_validation(
      employee_id: @employee1.employee_id,
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "12:00"
    )

    # 重複するシフトを作成しようとする
    assert_raises(ArgumentError, "指定時間に既存のシフトが重複しています") do
      Shift.create_with_validation(
        employee_id: @employee1.employee_id,
        shift_date: future_date.strftime("%Y-%m-%d"),
        start_time: "10:00",
        end_time: "18:00"
      )
    end
  end

  test "update_with_validation - 正常なシフト更新" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift.update_with_validation(
      start_time: "10:00",
      end_time: "19:00"
    )

    shift.reload
    assert_equal "10:00", shift.start_time.strftime("%H:%M")
    assert_equal "19:00", shift.end_time.strftime("%H:%M")
  end

  test "update_with_validation - 時間の妥当性エラー" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    assert_raises(ArgumentError, "終了時間は開始時間より後である必要があります") do
      shift.update_with_validation(
        start_time: "19:00",
        end_time: "10:00"
      )
    end
  end

  test "destroy_with_validation - 正常なシフト削除" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift.destroy_with_validation

    assert_raises(ActiveRecord::RecordNotFound) do
      Shift.find(shift.id)
    end
  end

  test "destroy_with_validation - 過去のシフト削除エラー" do
    past_date = Date.current - 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: past_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    assert_raises(ArgumentError, "過去のシフトは削除できません") do
      shift.destroy_with_validation
    end
  end

  # ===== スコープテスト =====

  test "スコープの動作確認" do
    future_date = Date.current + 1.day
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )
    shift2 = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("10:00:00"),
      end_time: Time.zone.parse("19:00:00")
    )

    # for_employeeスコープ
    employee1_shifts = Shift.for_employee(@employee1.employee_id)
    assert_includes employee1_shifts, shift1
    assert_not_includes employee1_shifts, shift2

    # for_date_rangeスコープ
    date_range_shifts = Shift.for_date_range(future_date, future_date)
    assert_includes date_range_shifts, shift1
    assert_includes date_range_shifts, shift2

    # for_monthスコープ
    month_shifts = Shift.for_month(future_date.year, future_date.month)
    assert_includes month_shifts, shift1
    assert_includes month_shifts, shift2
  end

  # ===== ヘルパーメソッドテスト =====

  test "display_name - シフト表示名" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    expected_name = "#{future_date.strftime('%m/%d')} 09:00-18:00"
    assert_equal expected_name, shift.display_name
  end

  test "get_employee_display_name - 従業員名取得" do
    result = Shift.get_employee_display_name(@employee1.employee_id)
    assert_equal @employee1.display_name, result

    # 存在しない従業員ID
    unknown_result = Shift.get_employee_display_name("unknown_id")
    assert_equal "ID: unknown_id", unknown_result
  end
end
