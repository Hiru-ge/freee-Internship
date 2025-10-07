
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

    # 内部ロジックはEmployeeモデルに委譲
    clock_in_form = Employee.create_clock_form_data("clock_in", now)

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

    # 内部ロジックはEmployeeモデルに委譲
    clock_out_form = Employee.create_clock_form_data("clock_out", now)

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
    # 内部ロジックはEmployeeモデルに委譲
    forgotten_employees = Employee.check_forgotten_clock_ins
    return if forgotten_employees.empty?

    forgotten_employees.each do |data|
      employee = data[:employee]
      shift = data[:shift]

      # 外部APIで打刻状況確認
      time_clocks = get_time_clocks_for_today(employee.employee_id)
      has_clock_in = time_clocks.any? { |record| record["type"] == "clock_in" }

      # リマインダー送信（外部API連携）
      send_clock_in_reminder(employee, shift) unless has_clock_in
    end
  end

  def check_forgotten_clock_outs
    # 内部ロジックはEmployeeモデルに委譲
    forgotten_employees = Employee.check_forgotten_clock_outs
    return if forgotten_employees.empty?

    forgotten_employees.each do |data|
      employee = data[:employee]
      shift = data[:shift]

      # 外部APIで打刻状況確認
      time_clocks = get_time_clocks_for_today(employee.employee_id)
      has_clock_out = time_clocks.any? { |record| record["type"] == "clock_out" }

      # リマインダー送信（外部API連携）
      send_clock_out_reminder(employee, shift) unless has_clock_out
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
    # 外部APIから従業員情報取得
    all_employees = @freee_service.get_employees_full
    employee_info = all_employees.find { |emp| emp["id"].to_s == employee.employee_id.to_s }
    return unless employee_info&.dig("email")

    # 内部ロジックはEmployeeモデルに委譲
    shift_time = Employee.format_shift_time(shift)

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
    # 外部APIから従業員情報取得
    all_employees = @freee_service.get_employees_full
    employee_info = all_employees.find { |emp| emp["id"].to_s == employee.employee_id.to_s }
    return unless employee_info&.dig("email")

    # 内部ロジックはEmployeeモデルに委譲
    shift_time = Employee.format_shift_time(shift)
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
  # 内部ロジックはEmployeeモデルに移行済み
end
