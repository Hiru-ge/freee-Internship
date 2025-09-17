require 'test_helper'

class ClockReminderServiceTest < ActionMailer::TestCase
  def setup
    @employee = Employee.create!(
      employee_id: 123,
      role: 'employee'
    )
    
    @shift = Shift.create!(
      employee_id: 123,
      shift_date: Date.new(2000, 1, 1), # テスト用の固定日付
      start_time: Time.new(2000, 1, 1, 9, 0, 0), # 9:00
      end_time: Time.new(2000, 1, 1, 18, 0, 0)   # 18:00
    )
    
    @service = ClockReminderService.new
  end

  test "出勤打刻忘れチェック - 打刻なしの場合にメール送信される" do
    # 現在時刻をシフト開始時刻の30分後に設定（15分経過後の条件を満たす）
    travel_to @shift.start_time + 30.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信をテスト
      assert_emails 1 do
        @service.send(:check_forgotten_clock_ins)
      end
    end
  end

  test "出勤打刻忘れチェック - 打刻ありの場合はメール送信されない" do
    # 現在時刻をシフト開始時刻の30分後に設定
    travel_to @shift.start_time + 30.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック（打刻あり）
      mock_freee_service = mock_freee_api_service_with_clock_in
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信されないことをテスト
      assert_no_emails do
        @service.send(:check_forgotten_clock_ins)
      end
    end
  end

  test "出勤打刻忘れチェック - 15分経過前はメール送信されない" do
    # 現在時刻をシフト開始時刻の10分後に設定（15分経過前）
    travel_to @shift.start_time + 10.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信されないことをテスト
      assert_no_emails do
        @service.send(:check_forgotten_clock_ins)
      end
    end
  end

  test "退勤打刻忘れチェック - 打刻なしの場合にメール送信される" do
    # 現在時刻をシフト終了時刻の30分後に設定（2時間以内の条件を満たす）
    travel_to @shift.end_time + 30.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信をテスト
      assert_emails 1 do
        @service.send(:check_forgotten_clock_outs)
      end
    end
  end

  test "退勤打刻忘れチェック - 打刻ありの場合はメール送信されない" do
    # 現在時刻をシフト終了時刻の30分後に設定
    travel_to @shift.end_time + 30.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック（打刻あり）
      mock_freee_service = mock_freee_api_service_with_clock_out
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信されないことをテスト
      assert_no_emails do
        @service.send(:check_forgotten_clock_outs)
      end
    end
  end

  test "退勤打刻忘れチェック - 15分間隔でリマインダー送信" do
    # 現在時刻をシフト終了時刻の30分後に設定（15分の倍数）
    travel_to @shift.end_time + 30.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信をテスト
      assert_emails 1 do
        @service.send(:check_forgotten_clock_outs)
      end
    end
  end

  test "退勤打刻忘れチェック - 15分間隔以外はメール送信されない" do
    # 現在時刻をシフト終了時刻の31分後に設定（15分の倍数でない）
    travel_to @shift.end_time + 31.minutes do
      # シフトの日付を現在の日付に更新
      @shift.update!(shift_date: Date.current)
      
      # FreeeApiServiceのモック
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      # メール送信されないことをテスト
      assert_no_emails do
        @service.send(:check_forgotten_clock_outs)
      end
    end
  end

  private

  def mock_freee_api_service
    mock_service = Object.new
    def mock_service.get_employee_info(employee_id)
      {
        'display_name' => 'テスト従業員',
        'email' => 'test@example.com'
      }
    end
    
    def mock_service.get_employees_full
      [
        {
          'id' => 123,
          'display_name' => 'テスト従業員',
          'email' => 'test@example.com'
        }
      ]
    end
    
    def mock_service.get_time_clocks(employee_id, start_date, end_date)
      []  # 打刻記録なし
    end
    
    mock_service
  end

  def mock_freee_api_service_with_clock_in
    mock_service = Object.new
    def mock_service.get_employee_info(employee_id)
      {
        'display_name' => 'テスト従業員',
        'email' => 'test@example.com'
      }
    end
    
    def mock_service.get_employees_full
      [
        {
          'id' => 123,
          'display_name' => 'テスト従業員',
          'email' => 'test@example.com'
        }
      ]
    end
    
    def mock_service.get_time_clocks(employee_id, start_date, end_date)
      [
        { 'type' => 'clock_in', 'datetime' => '2024-01-01T09:00:00+09:00' }
      ]
    end
    
    mock_service
  end

  def mock_freee_api_service_with_clock_out
    mock_service = Object.new
    def mock_service.get_employee_info(employee_id)
      {
        'display_name' => 'テスト従業員',
        'email' => 'test@example.com'
      }
    end
    
    def mock_service.get_employees_full
      [
        {
          'id' => 123,
          'display_name' => 'テスト従業員',
          'email' => 'test@example.com'
        }
      ]
    end
    
    def mock_service.get_time_clocks(employee_id, start_date, end_date)
      [
        { 'type' => 'clock_in', 'datetime' => '2024-01-01T09:00:00+09:00' },
        { 'type' => 'clock_out', 'datetime' => '2024-01-01T18:00:00+09:00' }
      ]
    end
    
    mock_service
  end
end