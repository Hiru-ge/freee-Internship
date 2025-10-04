class ShiftDisplayService
  def initialize(freee_api_service = nil)
    @freee_api_service = freee_api_service
  end
  def get_monthly_shifts(year, month)

    employees = get_employees_from_api
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
    Rails.logger.error "月次シフトデータ取得エラー: #{e.message}"
    {
      success: false,
      error: "シフトデータの取得に失敗しました"
    }
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
    grouped_shifts.sort_by { |date, _| date }.each do |date, shifts|
      day_of_week = %w[日 月 火 水 木 金 土][date.wday]
      message += "#{date.strftime('%m/%d')} (#{day_of_week})\n"

      shifts.each do |shift|
        message += "  #{shift[:employee_name]}: #{shift[:start_time]}-#{shift[:end_time]}\n"
      end
      message += "\n"
    end

    message
  end
  def self.merge_shifts(existing_shift, new_shift)
    return new_shift unless existing_shift

    existing_start_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    new_start_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.start_time.strftime('%H:%M')}")
    new_end_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.end_time.strftime('%H:%M')}")

    merged_start_time = [existing_start_time, new_start_time].min
    merged_end_time = [existing_end_time, new_end_time].max
    merged_start_time_only = Time.zone.parse(merged_start_time.strftime("%H:%M"))
    merged_end_time_only = Time.zone.parse(merged_end_time.strftime("%H:%M"))
    existing_shift.update!(
      start_time: merged_start_time_only,
      end_time: merged_end_time_only,
      is_modified: true,
      original_employee_id: new_shift.original_employee_id || new_shift.employee_id
    )

    existing_shift
  end
  def self.shift_fully_contained?(existing_shift, new_shift)

    existing_start_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    new_start_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.start_time.strftime('%H:%M')}")
    new_end_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.end_time.strftime('%H:%M')}")
    new_start_time >= existing_start_time && new_end_time <= existing_end_time
  end
  def self.process_shift_exchange_approval(approver_employee_id, shift_to_approve)
    new_shift_data = {
      employee_id: approver_employee_id,
      shift_date: shift_to_approve.shift_date,
      start_time: shift_to_approve.start_time,
      end_time: shift_to_approve.end_time,
      is_modified: true,
      original_employee_id: shift_to_approve.employee_id
    }

    process_shift_approval(approver_employee_id, new_shift_data)
  end
  def self.process_shift_addition_approval(employee_id, new_shift_data)
    shift_data = {
      employee_id: employee_id,
      shift_date: new_shift_data[:shift_date],
      start_time: new_shift_data[:start_time],
      end_time: new_shift_data[:end_time],
      is_modified: true,
      original_employee_id: new_shift_data[:requester_id]
    }

    process_shift_approval(employee_id, shift_data)
  end
  def self.process_shift_approval(employee_id, shift_data)

    existing_shift = Shift.find_by(
      employee_id: employee_id,
      shift_date: shift_data[:shift_date]
    )

    if existing_shift
  
      new_shift = Shift.new(shift_data)
      merged_shift = if shift_fully_contained?(existing_shift, new_shift)
                   
                       existing_shift
                     else
                   
                       merge_shifts(existing_shift, new_shift)
                     end
    else
  
      merged_shift = Shift.create!(shift_data)
    end

    merged_shift
  end
  def check_exchange_overlap(approver_ids, shift_date, start_time, end_time)
    overlapping_employees = []

    approver_ids.each do |approver_id|
      next unless has_shift_overlap?(approver_id, shift_date, start_time, end_time)

      employee = Employee.find_by(employee_id: approver_id)
      employee_name = employee&.display_name || "ID: #{approver_id}"
      overlapping_employees << employee_name
    end

    overlapping_employees
  end
  def get_available_and_overlapping_employees(approver_ids, shift_date, start_time, end_time)
    available_ids = []
    overlapping_names = []

    approver_ids.each do |approver_id|
      if has_shift_overlap?(approver_id, shift_date, start_time, end_time)
        employee = Employee.find_by(employee_id: approver_id)
        employee_name = employee&.display_name || "ID: #{approver_id}"
        overlapping_names << employee_name
      else
        available_ids << approver_id
      end
    end

    { available_ids: available_ids, overlapping_names: overlapping_names }
  end
  def check_addition_overlap(target_employee_id, shift_date, start_time, end_time)
    if has_shift_overlap?(target_employee_id, shift_date, start_time, end_time)
      employee = Employee.find_by(employee_id: target_employee_id)
      employee_name = employee&.display_name || "ID: #{target_employee_id}"
      return employee_name
    end

    nil
  end

  private
  def get_employees_from_api
    if @freee_api_service
      @freee_api_service.get_employees
    else
  
      Employee.all.map do |emp|
        {
          id: emp.employee_id,
          display_name: emp.display_name
        }
      end
    end
  end
  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)

    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end
  def shift_overlaps?(existing_shift, new_start_time, new_end_time)
    existing_times = convert_shift_times_to_objects(existing_shift)
    new_times = convert_new_shift_times_to_objects(existing_shift.shift_date, new_start_time, new_end_time)

    new_times[:start] < existing_times[:end] && new_times[:end] > existing_times[:start]
  end
  def convert_shift_times_to_objects(existing_shift)
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
