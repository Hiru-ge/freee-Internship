class WageService

  def self.time_zone_wage_rates
    @time_zone_wage_rates ||= begin
      time_zone_rates = AppConstants.wage[:time_zone_rates] || {}
      {
        normal: { start: time_zone_rates.dig(:normal, :start_hour) || 9,
                  end: time_zone_rates.dig(:normal, :end_hour) || 18, rate: time_zone_rates.dig(:normal, :rate) || 1000, name: time_zone_rates.dig(:normal, :name) || "通常時給" },
        evening: { start: time_zone_rates.dig(:evening, :start_hour) || 18,
                   end: time_zone_rates.dig(:evening, :end_hour) || 22, rate: time_zone_rates.dig(:evening, :rate) || 1200, name: time_zone_rates.dig(:evening, :name) || "夜間手当" },
        night: { start: time_zone_rates.dig(:night, :start_hour) || 22,
                 end: time_zone_rates.dig(:night, :end_hour) || 9, rate: time_zone_rates.dig(:night, :rate) || 1500, name: time_zone_rates.dig(:night, :name) || "深夜手当" }
      }.freeze
    end
  end
  def self.monthly_wage_target
    AppConstants.monthly_wage_target
  end

  def initialize(freee_api_service = nil)
    @freee_api_service = freee_api_service
  end
  def get_time_zone(hour)
    time_zone_rates = self.class.time_zone_wage_rates

    if hour >= time_zone_rates[:normal][:start] && hour < time_zone_rates[:normal][:end]
      :normal
    elsif hour >= time_zone_rates[:evening][:start] && hour < time_zone_rates[:evening][:end]
      :evening
    else
      :night
    end
  end
  def calculate_work_hours_by_time_zone(_shift_date, start_time, end_time)
    start_hour = start_time.hour
    end_hour = end_time.hour
    time_zone_hours = { normal: 0, evening: 0, night: 0 }
    if end_hour <= start_hour
  
      (start_hour...24).each do |hour|
        time_zone = get_time_zone(hour)
        time_zone_hours[time_zone] += 1
      end
      (0...end_hour).each do |hour|
        time_zone = get_time_zone(hour)
        time_zone_hours[time_zone] += 1
      end
    else
  
      (start_hour...end_hour).each do |hour|
        time_zone = get_time_zone(hour)
        time_zone_hours[time_zone] += 1
      end
    end

    time_zone_hours
  end
  def calculate_monthly_work_hours(employee_id, month, year)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    shifts = Shift.where(
      employee_id: employee_id,
      shift_date: start_date..end_date
    )

    monthly_hours = { normal: 0, evening: 0, night: 0 }

    shifts.each do |shift|
      day_hours = calculate_work_hours_by_time_zone(
        shift.shift_date,
        shift.start_time,
        shift.end_time
      )

      monthly_hours[:normal] += day_hours[:normal]
      monthly_hours[:evening] += day_hours[:evening]
      monthly_hours[:night] += day_hours[:night]
    end

    monthly_hours
  end
  def calculate_monthly_wage(employee_id, month, year)
    monthly_work_hours = calculate_monthly_work_hours(employee_id, month, year)
    calculate_wage_from_hours(monthly_work_hours)
  rescue StandardError => e
    Rails.logger.error "給与計算エラー: #{e.message}"
    default_wage_result
  end
  def calculate_monthly_wage_from_shifts(shifts)
    monthly_hours = calculate_monthly_hours_from_shifts(shifts)
    calculate_wage_from_hours(monthly_hours)
  rescue StandardError => e
    Rails.logger.error "給与計算エラー: #{e.message}"
    default_wage_result
  end
  def get_all_employees_wages(month, year)
    freee_employees = fetch_freee_employees
    return [] if freee_employees.empty?

    shifts_by_employee = fetch_shifts_by_employee(freee_employees, month, year)
    build_wage_data_for_all_employees(freee_employees, shifts_by_employee)
  rescue StandardError => e
    Rails.logger.error "全従業員給与取得エラー: #{e.message}"
    []
  end
  def get_employee_wage_info(employee_id, month, year)

    freee_service = @freee_api_service || get_freee_api_service

    employee_info = freee_service.get_employee_info(employee_id)
    unless employee_info
      return {
        error: "指定された従業員IDが見つかりません",
        employee_id: employee_id
      }
    end

    wage_info = calculate_monthly_wage(employee_id, month, year)

    {
      employee_id: employee_id,
      employee_name: employee_info["display_name"] || "ID: #{employee_id}",
      wage: wage_info[:total],
      breakdown: wage_info[:breakdown],
      work_hours: wage_info[:work_hours],
      target: self.class.monthly_wage_target,
      percentage: (wage_info[:total].to_f / self.class.monthly_wage_target * 100).round(2),
      is_over_limit: wage_info[:total] >= self.class.monthly_wage_target,
      remaining: [self.class.monthly_wage_target - wage_info[:total], 0].max
    }
  rescue StandardError => e
    Rails.logger.error "従業員給与取得エラー: #{e.message}"
    {
      error: "給与計算中にエラーが発生しました: #{e.message}",
      employee_id: employee_id
    }
  end
  def get_wage_info(employee_id)
    now = Time.current
    current_month = now.month
    current_year = now.year

    wage_data = get_employee_wage_info(employee_id, current_month, current_year)

    return { wage: 0, target: self.class.monthly_wage_target, percentage: 0 } if wage_data[:error]

    {
      wage: wage_data[:wage],
      target: wage_data[:target],
      percentage: wage_data[:percentage]
    }
  rescue StandardError => e
    Rails.logger.error "給与情報取得エラー: #{e.message}"
    { wage: 0, target: self.class.monthly_wage_target, percentage: 0 }
  end
  def get_hourly_wage_from_freee(_employee_id)
    1000
  rescue StandardError => e
    Rails.logger.error "freee API時給取得エラー: #{e.message}"
    1000
  end

  private
  def get_freee_api_service
    FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end
  def calculate_wage_from_hours(monthly_hours)
    breakdown = {}
    total = 0

    monthly_hours.each do |time_zone, hours|
      rate = self.class.time_zone_wage_rates[time_zone][:rate]
      wage = hours * rate

      breakdown[time_zone] = {
        hours: hours,
        rate: rate,
        wage: wage,
        name: self.class.time_zone_wage_rates[time_zone][:name]
      }

      total += wage
    end

    {
      total: total,
      breakdown: breakdown,
      work_hours: monthly_hours
    }
  end
  def calculate_monthly_hours_from_shifts(shifts)
    monthly_hours = { normal: 0, evening: 0, night: 0 }

    shifts.each do |shift|
      day_hours = calculate_work_hours_by_time_zone(
        shift.shift_date,
        shift.start_time,
        shift.end_time
      )

      monthly_hours[:normal] += day_hours[:normal]
      monthly_hours[:evening] += day_hours[:evening]
      monthly_hours[:night] += day_hours[:night]
    end

    monthly_hours
  end
  def default_wage_result
    {
      total: 0,
      breakdown: {},
      work_hours: { normal: 0, evening: 0, night: 0 }
    }
  end
  def fetch_freee_employees
    freee_service = @freee_api_service || get_freee_api_service
    employees = freee_service.get_all_employees

    Rails.logger.warn "freeeAPIから従業員データを取得できませんでした" if employees.empty?

    employees
  end
  def fetch_shifts_by_employee(freee_employees, month, year)
    employee_ids = freee_employees.map { |emp| emp["id"].to_s }
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    all_shifts = Shift.where(
      employee_id: employee_ids,
      shift_date: start_date..end_date
    ).includes(:employee)

    all_shifts.group_by(&:employee_id)
  end
  def build_wage_data_for_all_employees(freee_employees, shifts_by_employee)
    all_wages = []

    freee_employees.each do |employee_data|
      employee_id = employee_data["id"].to_s
      employee_shifts = shifts_by_employee[employee_id] || []

      wage_info = calculate_monthly_wage_from_shifts(employee_shifts)

      all_wages << build_employee_wage_data(employee_data, employee_id, wage_info)
    end

    all_wages
  end
  def build_employee_wage_data(employee_data, employee_id, wage_info)
    {
      employee_id: employee_id,
      employee_name: employee_data["display_name"] || "ID: #{employee_id}",
      wage: wage_info[:total],
      breakdown: wage_info[:breakdown],
      work_hours: wage_info[:work_hours],
      target: self.class.monthly_wage_target,
      percentage: (wage_info[:total].to_f / self.class.monthly_wage_target * 100).round(2)
    }
  end
end
