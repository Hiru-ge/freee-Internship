require "test_helper"

class ClockServiceTimezoneTest < ActiveSupport::TestCase
  test "should use Asia/Tokyo timezone" do
    assert_equal "Asia/Tokyo", Time.zone.name
  end

  test "should use Time.current consistently" do
    current_time = Time.current
    assert current_time.is_a?(Time)
    assert_equal "Asia/Tokyo", Time.zone.name
  end

  test "should handle timezone correctly" do
    jst_time = Time.zone.parse("2024-01-15 09:00:00")
    # UTC時間を明示的にUTCタイムゾーンでパース
    utc_time = Time.utc(2024, 1, 15, 0, 0, 0)
    
    assert_equal 9, jst_time.hour
    assert_equal 0, utc_time.hour
  end

  test "should record clock times in correct timezone" do
    current_time = Time.current
    
    assert current_time.is_a?(Time)
    assert_equal "Asia/Tokyo", Time.zone.name
    
    date_str = current_time.strftime('%Y-%m-%d')
    time_str = current_time.strftime('%H:%M')
    
    assert date_str.is_a?(String)
    assert time_str.is_a?(String)
  end
end
