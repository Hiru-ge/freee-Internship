class ShiftDisplayService < ShiftBaseService
  def initialize(freee_api_service = nil)
    super()
    @freee_api_service = freee_api_service
  end

  def get_display_data(params)
    {
      employee: params[:employee],
      employee_id: params[:employee_id],
      is_owner: params[:is_owner]
    }
  end

  def get_monthly_shifts(year, month)
    begin
      employees = get_employees_from_api
      if employees.empty?
        log_warn("従業員データが取得できませんでした")
        return {
          success: false,
          error: "従業員データの取得に失敗しました"
        }
      end

      shifts_in_db = Shift.for_month(year, month).includes(:employee)
      shifts = {}
      employees.map { |emp| emp[:id] }
      shifts_by_employee = shifts_in_db.group_by(&:employee_id)

      employees.each do |employee|
        employee_shifts = {}
        employee_id = employee[:id]
        employee_shift_records = shifts_by_employee[employee_id] || []
        employee_shift_records.each do |shift_record|
          day = shift_record.shift_date.day
          time_string = "#{shift_record.start_time.strftime('%H')}-#{shift_record.end_time.strftime('%H')}"
          employee_shifts[day.to_s] = time_string
        end

        shifts[employee_id] = {
          name: employee[:display_name],
          shifts: employee_shifts
        }
      end

      {
        success: true,
        data: {
          year: year,
          month: month,
          shifts: shifts
        }
      }
    rescue StandardError => e
      log_error("月次シフトデータ取得エラー: #{e.message}")
      {
        success: false,
        error: "シフトデータの取得に失敗しました"
      }
    end
  end

  def get_employee_shifts(employee_id, start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    shifts = Shift.where(
      employee_id: employee_id,
      shift_date: start_date..end_date
    ).order(:shift_date, :start_time)

    {
      success: true,
      data: shifts
    }
  rescue StandardError => e
    Rails.logger.error "個人シフトデータ取得エラー: #{e.message}"
    {
      success: false,
      error: "シフトデータの取得に失敗しました"
    }
  end

  def get_all_employee_shifts(start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    employees = Employee.all
    all_shifts = []

    employees.each do |employee|
      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: start_date..end_date
      ).order(:shift_date, :start_time)

      shifts.each do |shift|
        all_shifts << {
          employee_name: employee.display_name,
          date: shift.shift_date,
          start_time: shift.start_time.strftime("%H:%M"),
          end_time: shift.end_time.strftime("%H:%M")
        }
      end
    end

    {
      success: true,
      data: all_shifts
    }
  rescue StandardError => e
    Rails.logger.error "全従業員シフトデータ取得エラー: #{e.message}"
    {
      success: false,
      error: "シフトデータの取得に失敗しました"
    }
  end

  def format_employee_shifts_for_line(shifts)
    return "今月のシフト情報はありません。" if shifts.empty?

    message = "📅 今月のシフト\n\n"
    shifts.each do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      message += "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    end

    message
  end

  def format_all_shifts_for_line(all_shifts)
    return "【今月の全員シフト】\n今月のシフト情報はありません。" if all_shifts.empty?
    grouped_shifts = all_shifts.group_by { |shift| shift[:date] }
    message = "【今月の全員シフト】\n\n"

    grouped_shifts.each do |date, shifts|
      day_of_week = %w[日 月 火 水 木 金 土][date.wday]
      message += "#{date.strftime('%m/%d')} (#{day_of_week})\n"
      shifts.each do |shift|
        message += "  #{shift[:employee_name]}: #{shift[:start_time]}-#{shift[:end_time]}\n"
      end
      message += "\n"
    end

    message
  end

  def get_shift_overlap_info(employee_id, shift_date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    overlapping_shifts = existing_shifts.select do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end

    {
      has_overlap: overlapping_shifts.any?,
      overlapping_shifts: overlapping_shifts.map do |shift|
        {
          id: shift.id,
          start_time: shift.start_time.strftime("%H:%M"),
          end_time: shift.end_time.strftime("%H:%M")
        }
      end
    }
  end

  def get_available_employees_for_date(shift_date, start_time, end_time)
    all_employees = get_employees_from_api
    available_employees = []

    all_employees.each do |employee|
      employee_id = employee[:id]
      overlap_info = get_shift_overlap_info(employee_id, shift_date, start_time, end_time)

      unless overlap_info[:has_overlap]
        available_employees << {
          id: employee_id,
          name: employee[:display_name]
        }
      end
    end

    available_employees
  end

  def get_shift_summary_for_employee(employee_id, month = nil, year = nil)
    month ||= Date.current.month
    year ||= Date.current.year

    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    shifts = Shift.where(
      employee_id: employee_id,
      shift_date: start_date..end_date
    ).order(:shift_date)

    total_hours = 0
    shift_count = shifts.count

    shifts.each do |shift|
      duration = (shift.end_time - shift.start_time) / 1.hour
      total_hours += duration
    end

    {
      employee_id: employee_id,
      month: month,
      year: year,
      shift_count: shift_count,
      total_hours: total_hours.round(2),
      shifts: shifts.map do |shift|
        {
          date: shift.shift_date,
          start_time: shift.start_time.strftime("%H:%M"),
          end_time: shift.end_time.strftime("%H:%M"),
          duration: ((shift.end_time - shift.start_time) / 1.hour).round(2)
        }
      end
    }
  end

  def get_monthly_shift_summary(month = nil, year = nil)
    month ||= Date.current.month
    year ||= Date.current.year

    employees = get_employees_from_api
    summary = []

    employees.each do |employee|
      employee_summary = get_shift_summary_for_employee(employee[:id], month, year)
      summary << employee_summary
    end

    {
      month: month,
      year: year,
      employees: summary
    }
  end

  def validate_shift_data(shift_data)
    errors = []

    if shift_data[:employee_id].blank?
      errors << "従業員IDが指定されていません"
    end

    if shift_data[:shift_date].blank?
      errors << "シフト日付が指定されていません"
    end

    if shift_data[:start_time].blank?
      errors << "開始時間が指定されていません"
    end

    if shift_data[:end_time].blank?
      errors << "終了時間が指定されていません"
    end

    if shift_data[:start_time].present? && shift_data[:end_time].present?
      begin
        start_time = Time.zone.parse(shift_data[:start_time])
        end_time = Time.zone.parse(shift_data[:end_time])

        if start_time >= end_time
          errors << "開始時間は終了時間より前である必要があります"
        end
      rescue ArgumentError
        errors << "時間の形式が正しくありません"
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def create_shift_record(shift_data)
    validation_result = validate_shift_data(shift_data)

    unless validation_result[:valid]
      return {
        success: false,
        errors: validation_result[:errors]
      }
    end

    begin
      shift = Shift.create!(
        employee_id: shift_data[:employee_id],
        shift_date: Date.parse(shift_data[:shift_date]),
        start_time: Time.zone.parse(shift_data[:start_time]),
        end_time: Time.zone.parse(shift_data[:end_time])
      )

      {
        success: true,
        data: shift
      }
    rescue StandardError => e
      log_error("シフト作成エラー: #{e.message}")
      {
        success: false,
        error: "シフトの作成に失敗しました"
      }
    end
  end

  def update_shift_record(shift_id, shift_data)
    begin
      shift = Shift.find(shift_id)

      validation_result = validate_shift_data(shift_data)
      unless validation_result[:valid]
        return {
          success: false,
          errors: validation_result[:errors]
        }
      end

      shift.update!(
        employee_id: shift_data[:employee_id],
        shift_date: Date.parse(shift_data[:shift_date]),
        start_time: Time.zone.parse(shift_data[:start_time]),
        end_time: Time.zone.parse(shift_data[:end_time])
      )

      {
        success: true,
        data: shift
      }
    rescue ActiveRecord::RecordNotFound
      {
        success: false,
        error: "指定されたシフトが見つかりません"
      }
    rescue StandardError => e
      log_error("シフト更新エラー: #{e.message}")
      {
        success: false,
        error: "シフトの更新に失敗しました"
      }
    end
  end

  def delete_shift_record(shift_id)
    begin
      shift = Shift.find(shift_id)
      shift.destroy!

      {
        success: true,
        message: "シフトを削除しました"
      }
    rescue ActiveRecord::RecordNotFound
      {
        success: false,
        error: "指定されたシフトが見つかりません"
      }
    rescue StandardError => e
      log_error("シフト削除エラー: #{e.message}")
      {
        success: false,
        error: "シフトの削除に失敗しました"
      }
    end
  end

  def get_shift_statistics(month = nil, year = nil)
    month ||= Date.current.month
    year ||= Date.current.year

    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    total_shifts = Shift.where(shift_date: start_date..end_date).count
    total_hours = 0

    Shift.where(shift_date: start_date..end_date).each do |shift|
      duration = (shift.end_time - shift.start_time) / 1.hour
      total_hours += duration
    end

    employees = get_employees_from_api
    employee_stats = employees.map do |employee|
      employee_shifts = Shift.where(
        employee_id: employee[:id],
        shift_date: start_date..end_date
      )

      employee_hours = 0
      employee_shifts.each do |shift|
        duration = (shift.end_time - shift.start_time) / 1.hour
        employee_hours += duration
      end

      {
        employee_id: employee[:id],
        employee_name: employee[:display_name],
        shift_count: employee_shifts.count,
        total_hours: employee_hours.round(2)
      }
    end

    {
      month: month,
      year: year,
      total_shifts: total_shifts,
      total_hours: total_hours.round(2),
      employee_statistics: employee_stats
    }
  end

  private

  def get_employees_from_api
    if @freee_api_service
      @freee_api_service.get_employees
    else
      # フォールバック: データベースから従業員を取得
      begin
        Employee.all.map do |emp|
          {
            id: emp.employee_id,
            display_name: emp.display_name
          }
        end
      rescue StandardError => e
        log_error("従業員データ取得エラー: #{e.message}")
        []
      end
    end
  end

  def shift_overlaps?(existing_shift, new_start_time, new_end_time)
    existing_start = existing_shift.start_time
    existing_end = existing_shift.end_time

    # 新しいシフトの開始時間が既存のシフトの終了時間より前
    # かつ新しいシフトの終了時間が既存のシフトの開始時間より後
    new_start_time < existing_end && new_end_time > existing_start
  end

  def convert_existing_shift_times_to_objects(existing_shift)
    base_date = existing_shift.shift_date

    {
      start: Time.zone.parse("#{base_date} #{existing_shift.start_time.strftime('%H:%M')}"),
      end: Time.zone.parse("#{base_date} #{existing_shift.end_time.strftime('%H:%M')}")
    }
  end

  def convert_new_shift_times_to_objects(base_date, new_start_time, new_end_time)
    new_start_time_str = format_time_to_string(new_start_time)
    new_end_time_str = format_time_to_string(new_end_time)

    {
      start: Time.zone.parse("#{base_date} #{new_start_time_str}"),
      end: Time.zone.parse("#{base_date} #{new_end_time_str}")
    }
  end

  def format_time_to_string(time)
    time.is_a?(String) ? time : time.strftime("%H:%M")
  end
end
