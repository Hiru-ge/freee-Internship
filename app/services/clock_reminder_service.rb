# 打刻リマインダーサービス
# GAS時代のcheckForgottenClockInsとcheckForgottenClockOutsを再現

class ClockReminderService
  def initialize
    @freee_service = FreeeApiService.new(
      ENV['FREEE_ACCESS_TOKEN'],
      ENV['FREEE_COMPANY_ID']
    )
  end

  # 出勤打刻忘れチェック
  def self.check_forgotten_clock_ins
    service = new
    service.check_forgotten_clock_ins
  end

  # 退勤打刻忘れチェック
  def self.check_forgotten_clock_outs
    service = new
    service.check_forgotten_clock_outs
  end

  private

  def check_forgotten_clock_ins
    now = Time.current
    today = now.day
    current_hour = now.hour

    # 全従業員を取得
    employees = Employee.all
    return if employees.empty?

    employees.each do |employee|
      # 今日のシフトを取得
      today_shift = Shift.find_by(
        employee_id: employee.employee_id,
        shift_date: Date.current
      )
      next unless today_shift

      # シフト開始時刻を取得
      shift_start_hour = today_shift.start_time.hour

      # シフト開始時刻から1時間以内かチェック
      if current_hour >= shift_start_hour && current_hour < shift_start_hour + 1
        # 今日の打刻記録を取得
        time_clocks = get_time_clocks_for_today(employee.employee_id)
        has_clock_in = time_clocks.any? { |record| record['type'] == 'clock_in' }

        # 出勤打刻がない場合、メール送信
        unless has_clock_in
          send_clock_in_reminder(employee, today_shift)
        end
      end
    end
  end

  def check_forgotten_clock_outs
    now = Time.current
    current_hour = now.hour
    current_minute = now.min

    # 全従業員を取得
    employees = Employee.all
    return if employees.empty?

    employees.each do |employee|
      # 今日のシフトを取得
      today_shift = Shift.find_by(
        employee_id: employee.employee_id,
        shift_date: Date.current
      )
      next unless today_shift

      # シフト終了時刻を取得
      shift_end_hour = today_shift.end_time.hour

      # シフト終了時刻から2時間以内かチェック
      if (current_hour > shift_end_hour || (current_hour == shift_end_hour && current_minute >= 0)) &&
         current_hour < shift_end_hour + 2

        # 15分間隔でリマインダーを送信
        should_send_reminder = (current_minute % 15 == 0)

        if should_send_reminder
          # 今日の打刻記録を取得
          time_clocks = get_time_clocks_for_today(employee.employee_id)
          has_clock_out = time_clocks.any? { |record| record['type'] == 'clock_out' }

          # 退勤打刻がない場合、メール送信
          unless has_clock_out
            send_clock_out_reminder(employee, today_shift)
          end
        end
      end
    end
  end

  # 今日の打刻記録を取得
  def get_time_clocks_for_today(employee_id)
    begin
      today = Date.current
      date_string = today.strftime('%Y-%m-%d')
      @freee_service.get_time_clocks(employee_id, date_string, date_string)
    rescue => e
      Rails.logger.error "打刻記録取得エラー: #{e.message}"
      []
    end
  end

  # 出勤打刻リマインダーメール送信
  def send_clock_in_reminder(employee, shift)
    begin
      # GAS時代のgetEmployeesを再現したAPIから従業員情報を取得
      all_employees = @freee_service.get_employees_full
      employee_info = all_employees.find { |emp| emp['id'].to_s == employee.employee_id.to_s }
      return unless employee_info&.dig('email')
      
      shift_time = format_shift_time(shift)
      
      ClockReminderMailer.clock_in_reminder(
        employee_info['email'],
        employee_info['display_name'],
        shift_time
      ).deliver_now
      
      Rails.logger.info "出勤打刻リマインダー送信: #{employee_info['display_name']} (#{employee_info['email']})"
    rescue => e
      Rails.logger.error "出勤打刻リマインダー送信エラー: #{e.message}"
    end
  end

  # 退勤打刻リマインダーメール送信
  def send_clock_out_reminder(employee, shift)
    begin
      # GAS時代のgetEmployeesを再現したAPIから従業員情報を取得
      all_employees = @freee_service.get_employees_full
      employee_info = all_employees.find { |emp| emp['id'].to_s == employee.employee_id.to_s }
      return unless employee_info&.dig('email')
      
      shift_time = format_shift_time(shift)
      end_hour = shift.end_time.hour
      
      ClockReminderMailer.clock_out_reminder(
        employee_info['email'],
        employee_info['display_name'],
        shift_time,
        end_hour
      ).deliver_now
      
      Rails.logger.info "退勤打刻リマインダー送信: #{employee_info['display_name']} (#{employee_info['email']})"
    rescue => e
      Rails.logger.error "退勤打刻リマインダー送信エラー: #{e.message}"
    end
  end

  # シフト時間をフォーマット
  def format_shift_time(shift)
    "#{shift.start_time.strftime('%H:%M')}～#{shift.end_time.strftime('%H:%M')}"
  end
end
