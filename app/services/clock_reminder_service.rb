# frozen_string_literal: true

# 打刻リマインダーサービス
# GAS時代のcheckForgottenClockInsとcheckForgottenClockOutsを再現

class ClockReminderService
  def initialize
    @freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
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

  def check_forgotten_clock_ins
    now = Time.current

    # 今日シフトがある従業員のみを取得（パフォーマンス最適化）
    today_employee_ids = Shift.where(shift_date: Date.current).pluck(:employee_id)
    return if today_employee_ids.empty?

    employees = Employee.where(employee_id: today_employee_ids)
    return if employees.empty?

    employees.each do |employee|
      # 今日のシフトを取得（既に存在することが保証されている）
      today_shift = Shift.find_by(
        employee_id: employee.employee_id,
        shift_date: Date.current
      )
      next unless today_shift

      # シフト開始時刻を過ぎて1時間以内かチェック
      next unless within_shift_start_window?(now, today_shift.start_time)

      # 今日の打刻記録を取得
      time_clocks = get_time_clocks_for_today(employee.employee_id)
      has_clock_in = time_clocks.any? { |record| record["type"] == "clock_in" }

      # 出勤打刻がない場合、メール送信
      send_clock_in_reminder(employee, today_shift) unless has_clock_in
    end
  end

  def check_forgotten_clock_outs
    now = Time.current

    # 今日シフトがある従業員のみを取得（パフォーマンス最適化）
    today_employee_ids = Shift.where(shift_date: Date.current).pluck(:employee_id)
    return if today_employee_ids.empty?

    employees = Employee.where(employee_id: today_employee_ids)
    return if employees.empty?

    employees.each do |employee|
      # 今日のシフトを取得（既に存在することが保証されている）
      today_shift = Shift.find_by(
        employee_id: employee.employee_id,
        shift_date: Date.current
      )
      next unless today_shift

      # シフト終了時刻を過ぎて1時間以内かチェック
      next unless within_shift_end_window?(now, today_shift.end_time)

      # 今日の打刻記録を取得
      time_clocks = get_time_clocks_for_today(employee.employee_id)
      has_clock_out = time_clocks.any? { |record| record["type"] == "clock_out" }

      # 退勤打刻がない場合、メール送信
      send_clock_out_reminder(employee, today_shift) unless has_clock_out
    end
  end

  # 今日の打刻記録を取得
  def get_time_clocks_for_today(employee_id)
    today = Date.current
    date_string = today.strftime("%Y-%m-%d")
    @freee_service.get_time_clocks(employee_id, date_string, date_string)
  rescue StandardError => e
    Rails.logger.error "打刻記録取得エラー: #{e.message}"
    []
  end

  # 出勤打刻リマインダーメール送信
  def send_clock_in_reminder(employee, shift)
    # GAS時代のgetEmployeesを再現したAPIから従業員情報を取得
    all_employees = @freee_service.get_employees_full
    employee_info = all_employees.find { |emp| emp["id"].to_s == employee.employee_id.to_s }
    return unless employee_info&.dig("email")

    shift_time = format_shift_time(shift)

    ClockReminderMailer.clock_in_reminder(
      employee_info["email"],
      employee_info["display_name"],
      shift_time
    ).deliver_now

    Rails.logger.info "出勤打刻リマインダー送信: #{employee_info['display_name']} (#{employee_info['email']})"
  rescue StandardError => e
    Rails.logger.error "出勤打刻リマインダー送信エラー: #{e.message}"
  end

  # 退勤打刻リマインダーメール送信
  def send_clock_out_reminder(employee, shift)
    # GAS時代のgetEmployeesを再現したAPIから従業員情報を取得
    all_employees = @freee_service.get_employees_full
    employee_info = all_employees.find { |emp| emp["id"].to_s == employee.employee_id.to_s }
    return unless employee_info&.dig("email")

    shift_time = format_shift_time(shift)
    end_hour = shift.end_time.hour

    ClockReminderMailer.clock_out_reminder(
      employee_info["email"],
      employee_info["display_name"],
      shift_time,
      end_hour
    ).deliver_now

    Rails.logger.info "退勤打刻リマインダー送信: #{employee_info['display_name']} (#{employee_info['email']})"
  rescue StandardError => e
    Rails.logger.error "退勤打刻リマインダー送信エラー: #{e.message}"
  end

  private

  # シフト時間をフォーマット
  def format_shift_time(shift)
    "#{shift.start_time.strftime('%H:%M')}～#{shift.end_time.strftime('%H:%M')}"
  end

  # シフト開始時刻を過ぎて1時間以内かチェック
  def within_shift_start_window?(current_time, shift_start_time)
    current_minutes = (current_time.hour * 60) + current_time.min
    shift_start_minutes = shift_start_time.hour * 60
    reminder_end_minutes = (shift_start_time.hour + 1) * 60

    current_minutes >= shift_start_minutes && current_minutes < reminder_end_minutes
  end

  # シフト終了時刻を過ぎて1時間以内かチェック
  def within_shift_end_window?(current_time, shift_end_time)
    current_minutes = (current_time.hour * 60) + current_time.min
    shift_end_minutes = shift_end_time.hour * 60
    reminder_end_minutes = (shift_end_time.hour + 1) * 60

    current_minutes >= shift_end_minutes && current_minutes < reminder_end_minutes
  end

  # 15分間隔でリマインダーを送信するかチェック
  def should_send_reminder?(current_time)
    (current_time.min % 15).zero?
  end
end
