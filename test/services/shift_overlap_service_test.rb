require "test_helper"

class ShiftOverlapServiceTest < ActiveSupport::TestCase
  def setup
    @overlap_service = ShiftOverlapService.new
    
    # テスト用従業員データ
    @employee1 = employees(:employee1)
    @employee2 = employees(:employee2)
    
    # テスト用既存シフトデータ
    @existing_shift = Shift.create!(
      employee_id: '3317741',
      shift_date: Date.current,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    )
  end

  # シフト交代の重複チェックテスト（重複なし）
  test "should not detect overlap for non-overlapping shifts" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('18:00'),
      Time.zone.parse('19:00')
    )
    
    assert result.empty?
  end

  # シフト交代の重複チェックテスト（重複あり）
  test "should detect overlap for overlapping shifts" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('18:00'),
      Time.zone.parse('21:00')
    )
    
    
    assert_not result.empty?
    assert result.include?("テスト 三郎")
  end

  # シフト交代の重複チェックテスト（完全重複）
  test "should detect overlap for completely overlapping shifts" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('19:00'),
      Time.zone.parse('22:00')
    )
    
    assert_not result.empty?
    assert result.include?("テスト 三郎")
  end

  # シフト交代の重複チェックテスト（部分重複）
  test "should detect overlap for partially overlapping shifts" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('20:00'),
      Time.zone.parse('23:00')
    )
    
    assert_not result.empty?
    assert result.include?("テスト 三郎")
  end

  # シフト追加の重複チェックテスト（重複なし）
  test "should not detect overlap for non-overlapping shift addition" do
    result = @overlap_service.check_addition_overlap(
      '3317741',
      Date.current,
      Time.zone.parse('18:00'),
      Time.zone.parse('19:00')
    )
    
    assert_nil result
  end

  # シフト追加の重複チェックテスト（重複あり）
  test "should detect overlap for overlapping shift addition" do
    result = @overlap_service.check_addition_overlap(
      '3317741',
      Date.current,
      Time.zone.parse('18:00'),
      Time.zone.parse('21:00')
    )
    
    assert_not_nil result
    assert_equal "テスト 三郎", result
  end

  # 異なる日付の重複チェックテスト
  test "should not detect overlap for different dates" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current + 1.day,
      Time.zone.parse('19:00'),
      Time.zone.parse('22:00')
    )
    
    assert result.empty?
  end

  # 異なる従業員の重複チェックテスト
  test "should not detect overlap for different employees" do
    result = @overlap_service.check_exchange_overlap(
      ['3316120'],
      Date.current,
      Time.zone.parse('19:00'),
      Time.zone.parse('22:00')
    )
    
    assert result.empty?
  end

  # 存在しない従業員の重複チェックテスト
  test "should handle non-existent employee gracefully" do
    result = @overlap_service.check_exchange_overlap(
      ['9999999'],
      Date.current,
      Time.zone.parse('19:00'),
      Time.zone.parse('22:00')
    )
    
    assert result.empty?
  end

  # 境界値テスト（開始時刻が既存シフトの終了時刻と同じ）
  test "should not detect overlap when start time equals existing end time" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('22:00'),
      Time.zone.parse('23:00')
    )
    
    assert result.empty?
  end

  # 境界値テスト（終了時刻が既存シフトの開始時刻と同じ）
  test "should not detect overlap when end time equals existing start time" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('18:00'),
      Time.zone.parse('19:00')
    )
    
    assert result.empty?
  end

  # 境界値テスト（開始時刻が既存シフトの開始時刻と同じ）
  test "should detect overlap when start time equals existing start time" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('19:00'),
      Time.zone.parse('20:00')
    )
    
    assert_not result.empty?
    assert result.include?("テスト 三郎")
  end

  # 境界値テスト（終了時刻が既存シフトの終了時刻と同じ）
  test "should detect overlap when end time equals existing end time" do
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('20:00'),
      Time.zone.parse('22:00')
    )
    
    assert_not result.empty?
    assert result.include?("テスト 三郎")
  end

  # 複数シフトがある場合の重複チェックテスト
  test "should detect overlap with multiple existing shifts" do
    # 追加のシフトを作成
    Shift.create!(
      employee_id: '3317741',
      shift_date: Date.current,
      start_time: Time.zone.parse('14:00'),
      end_time: Time.zone.parse('17:00')
    )
    
    # 既存のシフトと重複する時間帯
    result = @overlap_service.check_exchange_overlap(
      ['3317741'],
      Date.current,
      Time.zone.parse('16:00'),
      Time.zone.parse('18:00')
    )
    
    assert_not result.empty?
    assert result.include?("テスト 三郎")
  end

end
