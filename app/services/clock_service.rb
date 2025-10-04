
class ClockService
  def initialize(employee_id)
    @employee_id = employee_id
    @freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end
  def clock_in
    now = Time.current

    clock_in_form = create_clock_form_data("clock_in", now)

    clock_result = @freee_service.create_work_record(@employee_id, clock_in_form)

    if clock_result == "登録しました"
      {
        success: true,
        message: "出勤打刻が完了しました"
      }
    else
      {
        success: false,
        message: clock_result || "出勤打刻に失敗しました"
      }
    end
  rescue StandardError => e
    Rails.logger.error "clockIn: エラーが発生しました: #{e.message}"
    {
      success: false,
      message: "出勤打刻中にエラーが発生しました"
    }
  end
  def clock_out
    now = Time.current

    clock_out_form = create_clock_form_data("clock_out", now)

    clock_result = @freee_service.create_work_record(@employee_id, clock_out_form)

    if clock_result == "登録しました"
      {
        success: true,
        message: "退勤打刻が完了しました"
      }
    else
      {
        success: false,
        message: clock_result || "退勤打刻に失敗しました"
      }
    end
  rescue StandardError => e
    Rails.logger.error "clockOut: エラーが発生しました: #{e.message}"
    {
      success: false,
      message: "退勤打刻中にエラーが発生しました"
    }
  end
  def get_clock_status
    today = Date.current
    from_date = today.strftime("%Y-%m-%d")
    to_date = today.strftime("%Y-%m-%d")
    time_clocks = @freee_service.get_time_clocks(@employee_id, from_date, to_date)

    has_clock_in = false
    has_clock_out = false

    time_clocks.each do |record|
      if record["type"] == "clock_in"
        has_clock_in = true
      elsif record["type"] == "clock_out"
        has_clock_out = true
      end
    end

    can_clock_in = !has_clock_in
    can_clock_out = has_clock_in && !has_clock_out
    message = if can_clock_in
                "出勤打刻が可能です"
              elsif can_clock_out
                "退勤打刻が可能です"
              elsif has_clock_in && has_clock_out
                "本日の打刻は完了しています"
              else
                "打刻状態を確認中です"
              end

    {
      can_clock_in: can_clock_in,
      can_clock_out: can_clock_out,
      message: message
    }
  rescue StandardError => e
    Rails.logger.error "getClockStatus: エラーが発生しました: #{e.message}"
    {
      can_clock_in: false,
      can_clock_out: false,
      message: "エラーが発生しました"
    }
  end
  def get_attendance_for_month(year, month)
    year_month = "#{year}-#{month.to_s.rjust(2, '0')}"
    @freee_service.get_time_clocks_for_month(@employee_id, year_month)
  rescue StandardError => e
    Rails.logger.error "getAttendanceForMonth: エラーが発生しました: #{e.message}"
    []
  end
  def self.check_forgotten_clock_ins
    service = new("dummy_employee_id")
    service.check_forgotten_clock_ins
  end
  def self.check_forgotten_clock_outs
    service = new("dummy_employee_id")
    service.check_forgotten_clock_outs
  end

  def check_forgotten_clock_ins
    now = Time.current
    today_employee_ids = Shift.where(shift_date: Date.current).pluck(:employee_id)
    return if today_employee_ids.empty?

    employees = Employee.where(employee_id: today_employee_ids)
    return if employees.empty?

    employees.each do |employee|
  
      today_shift = Shift.find_by(
        employee_id: employee.employee_id,
        shift_date: Date.current
      )
      next unless today_shift
      next unless within_shift_start_window?(now, today_shift.start_time)
      time_clocks = get_time_clocks_for_today(employee.employee_id)
      has_clock_in = time_clocks.any? { |record| record["type"] == "clock_in" }
      send_clock_in_reminder(employee, today_shift) unless has_clock_in
    end
  end

  def check_forgotten_clock_outs
    now = Time.current
    today_employee_ids = Shift.where(shift_date: Date.current).pluck(:employee_id)
    return if today_employee_ids.empty?

    employees = Employee.where(employee_id: today_employee_ids)
    return if employees.empty?

    employees.each do |employee|
  
      today_shift = Shift.find_by(
        employee_id: employee.employee_id,
        shift_date: Date.current
      )
      next unless today_shift
      next unless within_shift_end_window?(now, today_shift.end_time)
      time_clocks = get_time_clocks_for_today(employee.employee_id)
      has_clock_out = time_clocks.any? { |record| record["type"] == "clock_out" }
      send_clock_out_reminder(employee, today_shift) unless has_clock_out
    end
  end
  def get_time_clocks_for_today(employee_id)
    today = Date.current
    date_string = today.strftime("%Y-%m-%d")
    @freee_service.get_time_clocks(employee_id, date_string, date_string)
  rescue StandardError => e
    Rails.logger.error "打刻記録取得エラー: #{e.message}"
    []
  end
  def send_clock_in_reminder(employee, shift)

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
  def send_clock_out_reminder(employee, shift)

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
  def create_clock_form_data(clock_type, time = Time.current)
    {
      target_date: time.strftime("%Y-%m-%d"),
      target_time: time.strftime("%H:%M"),
      target_type: clock_type
    }
  end
  def format_shift_time(shift)
    "#{shift.start_time.strftime('%H:%M')}～#{shift.end_time.strftime('%H:%M')}"
  end
  def within_shift_start_window?(current_time, shift_start_time)
    current_minutes = (current_time.hour * 60) + current_time.min
    shift_start_minutes = shift_start_time.hour * 60
    reminder_end_minutes = (shift_start_time.hour + 1) * 60

    current_minutes >= shift_start_minutes && current_minutes < reminder_end_minutes
  end
  def within_shift_end_window?(current_time, shift_end_time)
    current_minutes = (current_time.hour * 60) + current_time.min
    shift_end_minutes = shift_end_time.hour * 60
    reminder_end_minutes = (shift_end_time.hour + 1) * 60

    current_minutes >= shift_end_minutes && current_minutes < reminder_end_minutes
  end
  def should_send_reminder?(current_time)
    (current_time.min % 15).zero?
  end
end
