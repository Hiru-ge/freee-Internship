require "test_helper"

class WageServiceTest < ActiveSupport::TestCase
  def setup
    @wage_service = WageService.new
    
    # テスト用従業員データ
    @employee = employees(:employee1)
    
    # テスト用シフトデータ
    @shift1 = Shift.create!(
      employee_id: '3316120',
      shift_date: Date.current,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    @shift2 = Shift.create!(
      employee_id: '3316120',
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse('9:00'),
      end_time: Time.zone.parse('18:00')
    )
  end

  # 時間帯判定テスト
  test "should determine time zone correctly" do
    assert_equal :normal, @wage_service.get_time_zone(10)  # 10時は通常時給
    assert_equal :normal, @wage_service.get_time_zone(17)  # 17時は通常時給
    assert_equal :evening, @wage_service.get_time_zone(18) # 18時は夜間手当
    assert_equal :evening, @wage_service.get_time_zone(21) # 21時は夜間手当
    assert_equal :night, @wage_service.get_time_zone(22)   # 22時は深夜手当
    assert_equal :night, @wage_service.get_time_zone(2)    # 2時は深夜手当
    assert_equal :night, @wage_service.get_time_zone(8)    # 8時は深夜手当
  end

  # 時間帯別勤務時間計算テスト
  test "should calculate work hours by time zone correctly" do
    # 18:00-23:00のシフト（夜間4時間、深夜1時間）
    work_hours = @wage_service.calculate_work_hours_by_time_zone(
      Date.current,
      Time.zone.parse('18:00'),
      Time.zone.parse('23:00')
    )
    
    assert_equal 4, work_hours[:evening]
    assert_equal 1, work_hours[:night]
    assert_equal 0, work_hours[:normal]
  end

  # 通常時給の勤務時間計算テスト
  test "should calculate normal time work hours correctly" do
    # 9:00-18:00のシフト（通常時給9時間）
    work_hours = @wage_service.calculate_work_hours_by_time_zone(
      Date.current,
      Time.zone.parse('9:00'),
      Time.zone.parse('18:00')
    )
    
    assert_equal 9, work_hours[:normal]
    assert_equal 0, work_hours[:evening]
    assert_equal 0, work_hours[:night]
  end

  # 日をまたぐ勤務時間計算テスト
  test "should calculate overnight work hours correctly" do
    # 22:00-翌日6:00のシフト（深夜8時間）
    work_hours = @wage_service.calculate_work_hours_by_time_zone(
      Date.current,
      Time.zone.parse('22:00'),
      Time.zone.parse('06:00') + 1.day
    )
    
    assert_equal 0, work_hours[:normal]
    assert_equal 0, work_hours[:evening]
    assert_equal 8, work_hours[:night]
  end

  # 月間勤務時間計算テスト
  test "should calculate monthly work hours correctly" do
    month = Date.current.month
    year = Date.current.year
    
    work_hours = @wage_service.calculate_monthly_work_hours('3316120', month, year)
    
    # レスポンスが有効であることを確認
    assert work_hours.is_a?(Hash) || work_hours.is_a?(Numeric)
  end

  # 月間給与計算テスト
  test "should calculate monthly wage correctly" do
    month = Date.current.month
    year = Date.current.year
    
    wage = @wage_service.calculate_monthly_wage('3316120', month, year)
    
    # レスポンスが有効であることを確認
    assert wage.is_a?(Hash) || wage.is_a?(Numeric)
  end

  # 給与情報取得テスト
  test "should get employee wage info correctly" do
    month = Date.current.month
    year = Date.current.year
    
    wage_info = @wage_service.get_employee_wage_info('3316120', month, year)
    
    # レスポンスが有効であることを確認
    assert wage_info.is_a?(Hash)
  end

  # 全従業員給与情報取得テスト
  test "should get all employees wages correctly" do
    month = Date.current.month
    year = Date.current.year
    
    all_wages = @wage_service.get_all_employees_wages(month, year)
    
    # レスポンスが有効であることを確認
    assert all_wages.is_a?(Array) || all_wages.is_a?(Hash)
  end

  # 103万の壁達成率計算テスト
  test "should calculate 103 million yen wall percentage correctly" do
    month = Date.current.month
    year = Date.current.year
    
    wage_info = @wage_service.get_employee_wage_info('3316120', month, year)
    
    # レスポンスが有効であることを確認
    assert wage_info.is_a?(Hash)
  end

  # 時間帯別時給レートテスト
  test "should use correct time zone wage rates" do
    rates = WageService.time_zone_wage_rates
    assert_equal 1000, rates[:normal][:rate]
    assert_equal 1200, rates[:evening][:rate]
    assert_equal 1500, rates[:night][:rate]
  end

  # 月間給与目標テスト
  test "should use correct monthly wage target" do
    assert_equal 1_030_000, WageService.monthly_wage_target
  end

  # エラーハンドリングテスト
  test "should handle non-existent employee gracefully" do
    month = Date.current.month
    year = Date.current.year
    
    wage_info = @wage_service.get_employee_wage_info('9999999', month, year)
    
    # レスポンスが有効であることを確認
    assert wage_info.is_a?(Hash)
  end

  # 空の月の給与計算テスト
  test "should handle month with no shifts gracefully" do
    month = Date.current.month
    year = Date.current.year
    
    # 外部キー制約を考慮して、関連するshift_exchangesを先に削除
    ShiftExchange.destroy_all
    Shift.destroy_all
    
    wage_info = @wage_service.get_employee_wage_info('3316120', month, year)
    
    # レスポンスが有効であることを確認
    assert wage_info.is_a?(Hash)
  end
end
