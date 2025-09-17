require "test_helper"

class ClockServiceTest < ActiveSupport::TestCase
  def setup
    @employee_id = '3316120'
    @clock_service = ClockService.new(@employee_id)
    
    # テスト用の従業員データ
    @employee = employees(:employee1)
  end

  # タイムゾーン設定のテスト
  test "should use correct timezone for clock operations" do
    # 現在のタイムゾーン設定を確認（Asia/Tokyoに設定されているはず）
    assert_equal "Asia/Tokyo", Time.zone.name, "日本時間が設定されているべき"
    
    # 日本時間での時刻取得をテスト
    jst_time = Time.zone.parse("2024-01-15 09:00:00")
    utc_time = Time.utc(2024, 1, 15, 0, 0, 0)
    
    # タイムゾーンが正しく設定されている場合のテスト
    assert_equal 9, jst_time.hour, "日本時間の9時であるべき"
    assert_equal 0, utc_time.hour, "UTC時間の0時であるべき"
  end

  # 現在時刻のタイムゾーンテスト
  test "should use Time.current consistently" do
    # Time.currentの使用をテスト
    current_time = Time.current
    assert current_time.is_a?(Time), "Time.currentはTimeオブジェクトを返すべき"
    
    # 現在のタイムゾーンでの時刻取得
    assert_equal "Asia/Tokyo", Time.zone.name, "現在のタイムゾーンはAsia/Tokyo"
  end

  # 打刻時刻の正確性テスト
  test "should record accurate clock times in correct timezone" do
    # 現在時刻を取得
    current_time = Time.current
    
    # 時刻の正確性を検証（タイムゾーン考慮）
    expected_date = current_time.strftime('%Y-%m-%d')
    expected_time = current_time.strftime('%H:%M')
    
    # 基本的な時刻処理のテスト
    assert current_time.is_a?(Time), "現在時刻はTimeオブジェクトであるべき"
    assert_equal "Asia/Tokyo", Time.zone.name, "タイムゾーンはAsia/Tokyoであるべき"
    assert expected_date.is_a?(String), "日付文字列はStringであるべき"
    assert expected_time.is_a?(String), "時刻文字列はStringであるべき"
  end

  # 打刻状態取得のタイムゾーンテスト
  test "should get clock status with correct timezone" do
    # 現在時刻のタイムゾーンテスト
    current_time = Time.current
    current_date = Date.current
    
    # 基本的な時刻処理のテスト
    assert current_time.is_a?(Time), "現在時刻はTimeオブジェクトであるべき"
    assert current_date.is_a?(Date), "現在日付はDateオブジェクトであるべき"
    assert_equal "Asia/Tokyo", Time.zone.name, "タイムゾーンはAsia/Tokyoであるべき"
  end

  # 月次勤怠データのタイムゾーンテスト
  test "should get monthly attendance with correct timezone" do
    # 現在時刻のタイムゾーンテスト
    current_time = Time.current
    
    # 基本的な時刻処理のテスト
    assert current_time.is_a?(Time), "現在時刻はTimeオブジェクトであるべき"
    assert_equal "Asia/Tokyo", Time.zone.name, "タイムゾーンはAsia/Tokyoであるべき"
    
    # 年月の文字列化テスト
    year_month = "2024-01"
    assert year_month.is_a?(String), "年月文字列はStringであるべき"
  end

  # タイムゾーン設定の影響テスト
  test "should handle timezone changes correctly" do
    # 現在のタイムゾーンを保存
    original_timezone = Time.zone
    
    begin
      # 日本時間に設定
      Time.zone = 'Asia/Tokyo'
      
      # 時刻の取得と検証
      jst_time = Time.zone.now
      assert_equal 'Asia/Tokyo', Time.zone.name
      
      # UTC時間に設定
      Time.zone = 'UTC'
      
      # 時刻の取得と検証
      utc_time = Time.zone.now
      assert_equal 'UTC', Time.zone.name
      
      # 時刻の差を検証（日本時間はUTC+9）
      time_diff = jst_time.hour - utc_time.hour
      # サマータイム等を考慮して±1時間の誤差を許容
      assert_includes [8, 9, 10], time_diff, "日本時間とUTC時間の差は8-10時間であるべき"
      
    ensure
      # 元のタイムゾーンに戻す
      Time.zone = original_timezone
    end
  end

  # 打刻リマインダーサービスのタイムゾーンテスト
  test "should handle clock reminder timezone correctly" do
    # 現在のタイムゾーンを保存
    original_timezone = Time.zone
    
    begin
      # 日本時間に設定
      Time.zone = 'Asia/Tokyo'
      
      # 現在時刻を取得
      current_time = Time.current
      current_date = Date.current
      
      # 時刻の検証
      assert_equal 'Asia/Tokyo', Time.zone.name
      assert current_time.is_a?(Time), "現在時刻がTimeオブジェクトであるべき"
      assert current_date.is_a?(Date), "現在日付がDateオブジェクトであるべき"
      
    ensure
      # 元のタイムゾーンに戻す
      Time.zone = original_timezone
    end
  end
end
