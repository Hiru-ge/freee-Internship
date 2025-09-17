# 打刻システム
# 出勤・退勤打刻、打刻忘れチェックを担当

class ClockService
  def initialize(employee_id)
    @employee_id = employee_id
    @freee_service = FreeeApiService.new(
      ENV['FREEE_ACCESS_TOKEN'],
      ENV['FREEE_COMPANY_ID']
    )
  end

  # 出勤打刻
  def clock_in
    begin
      now = Time.current
      
      clock_in_form = create_clock_form_data('clock_in', now)
      
      clock_result = @freee_service.create_work_record(@employee_id, clock_in_form)
      
      if clock_result == '登録しました'
        {
          success: true,
          message: '出勤打刻が完了しました'
        }
      else
        {
          success: false,
          message: clock_result || '出勤打刻に失敗しました'
        }
      end
    rescue => error
      Rails.logger.error "clockIn: エラーが発生しました: #{error.message}"
      {
        success: false,
        message: '出勤打刻中にエラーが発生しました'
      }
    end
  end

  # 退勤打刻
  def clock_out
    begin
      now = Time.current
      
      clock_out_form = create_clock_form_data('clock_out', now)
      
      clock_result = @freee_service.create_work_record(@employee_id, clock_out_form)
      
      if clock_result == '登録しました'
        {
          success: true,
          message: '退勤打刻が完了しました'
        }
      else
        {
          success: false,
          message: clock_result || '退勤打刻に失敗しました'
        }
      end
    rescue => error
      Rails.logger.error "clockOut: エラーが発生しました: #{error.message}"
      {
        success: false,
        message: '退勤打刻中にエラーが発生しました'
      }
    end
  end

  # 打刻状態の取得
  def get_clock_status
    begin
      today = Date.current
      from_date = today.strftime('%Y-%m-%d')
      to_date = today.strftime('%Y-%m-%d')
      time_clocks = @freee_service.get_time_clocks(@employee_id, from_date, to_date)
      
      has_clock_in = false
      has_clock_out = false
      
      time_clocks.each do |record|
        if record['type'] == 'clock_in'
          has_clock_in = true
        elsif record['type'] == 'clock_out'
          has_clock_out = true
        end
      end
      
      can_clock_in = !has_clock_in
      can_clock_out = has_clock_in && !has_clock_out
      
      message = ''
      if can_clock_in
        message = '出勤打刻が可能です'
      elsif can_clock_out
        message = '退勤打刻が可能です'
      elsif has_clock_in && has_clock_out
        message = '本日の打刻は完了しています'
      else
        message = '打刻状態を確認中です'
      end
      
      {
        can_clock_in: can_clock_in,
        can_clock_out: can_clock_out,
        message: message
      }
    rescue => error
      Rails.logger.error "getClockStatus: エラーが発生しました: #{error.message}"
      {
        can_clock_in: false,
        can_clock_out: false,
        message: 'エラーが発生しました'
      }
    end
  end

  # 月次勤怠データの取得
  def get_attendance_for_month(year, month)
    begin
      year_month = "#{year}-#{month.to_s.rjust(2, '0')}"
      @freee_service.get_time_clocks_for_month(@employee_id, year_month)
    rescue => error
      Rails.logger.error "getAttendanceForMonth: エラーが発生しました: #{error.message}"
      []
    end
  end

  # 打刻忘れチェック（出勤）
  def self.check_forgotten_clock_ins
    # バックグラウンド処理として実装予定
    # 現在はスキップ
  end

  # 打刻忘れチェック（退勤）
  def self.check_forgotten_clock_outs
    # バックグラウンド処理として実装予定
    # 現在はスキップ
  end

  private

  # 打刻用のフォームデータを作成
  def create_clock_form_data(clock_type, time = Time.current)
    {
      target_date: time.strftime('%Y-%m-%d'),
      target_time: time.strftime('%H:%M'),
      target_type: clock_type
    }
  end
end
