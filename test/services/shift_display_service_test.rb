require 'test_helper'

class ShiftDisplayServiceTest < ActiveSupport::TestCase
  def setup
    @service = ShiftDisplayService.new
    @employee1 = employees(:employee1)
    @employee2 = employees(:employee2)
    @future_date = Date.current + 1.day
  end

  # 月次シフトデータ取得のテスト
  test "should get monthly shifts successfully" do
    # テスト用のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    result = @service.get_monthly_shifts(Date.current.year, Date.current.month)

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal Date.current.year, result[:data][:year]
    assert_equal Date.current.month, result[:data][:month]
    assert_not_nil result[:data][:shifts]
  end

  test "should handle monthly shifts when no shifts exist" do
    result = @service.get_monthly_shifts(Date.current.year, Date.current.month)

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal Date.current.year, result[:data][:year]
    assert_equal Date.current.month, result[:data][:month]
    assert_not_nil result[:data][:shifts]
  end

  # 個人シフトデータ取得のテスト
  test "should get employee shifts successfully" do
    # テスト用のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    result = @service.get_employee_shifts(@employee1.employee_id)

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal 1, result[:data].count
    assert_equal shift.id, result[:data].first.id
  end

  test "should get employee shifts with custom date range" do
    start_date = Date.current
    end_date = Date.current + 7.days

    # テスト用のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: start_date + 1.day,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    result = @service.get_employee_shifts(@employee1.employee_id, start_date, end_date)

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal 1, result[:data].count
  end

  test "should return empty array when no employee shifts exist" do
    result = @service.get_employee_shifts(@employee1.employee_id)

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal 0, result[:data].count
  end

  # 全従業員シフトデータ取得のテスト
  test "should get all employee shifts successfully" do
    # テスト用のシフトを作成
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    shift2 = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('19:00')
    )

    result = @service.get_all_employee_shifts

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal 2, result[:data].count
    assert_equal @employee1.display_name, result[:data].first[:employee_name]
    assert_equal @employee2.display_name, result[:data].last[:employee_name]
  end

  test "should return empty array when no shifts exist" do
    result = @service.get_all_employee_shifts

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal 0, result[:data].count
  end

  # シフトデータフォーマットのテスト
  test "should format employee shifts for line successfully" do
    # テスト用のシフトを作成
    shift1 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    shift2 = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 2.days,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('19:00')
    )

    shifts = [shift1, shift2]
    result = @service.format_employee_shifts_for_line(shifts)

    assert_includes result, "📅 今月のシフト"
    assert_includes result, "09:00-18:00"
    assert_includes result, "10:00-19:00"
  end

  test "should format empty employee shifts for line" do
    result = @service.format_employee_shifts_for_line([])

    assert_equal "今月のシフト情報はありません。", result
  end

  test "should format all shifts for line successfully" do
    all_shifts = [
      {
        employee_name: @employee1.display_name,
        date: Date.current + 1.day,
        start_time: "09:00",
        end_time: "18:00"
      },
      {
        employee_name: @employee2.display_name,
        date: Date.current + 1.day,
        start_time: "10:00",
        end_time: "19:00"
      }
    ]

    result = @service.format_all_shifts_for_line(all_shifts)

    assert_includes result, "【今月の全員シフト】"
    assert_includes result, @employee1.display_name
    assert_includes result, @employee2.display_name
    assert_includes result, "09:00-18:00"
    assert_includes result, "10:00-19:00"
  end

  test "should format empty all shifts for line" do
    result = @service.format_all_shifts_for_line([])

    assert_equal "【今月の全員シフト】\n今月のシフト情報はありません。", result
  end

  # エラーハンドリングのテスト
  test "should handle database errors gracefully" do
    # 無効な従業員IDでテスト
    result = @service.get_employee_shifts("invalid_id")

    assert result[:success]
    assert_not_nil result[:data]
    assert_equal 0, result[:data].count
  end

  test "should handle freee API service integration" do
    # freee APIサービスなしでテスト（フォールバック動作）
    service_without_api = ShiftDisplayService.new(nil)
    result = service_without_api.get_monthly_shifts(Date.current.year, Date.current.month)

    assert result[:success]
    assert_not_nil result[:data]
  end
end
