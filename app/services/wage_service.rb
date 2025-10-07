# frozen_string_literal: true

class WageService
  def initialize(freee_api_service = nil)
    @freee_api_service = freee_api_service || FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

  # 全従業員の給与情報取得（外部API連携）
  def get_all_employees_wages(month, year)
    freee_employees = @freee_api_service.get_all_employees
    return [] if freee_employees.empty?

    employee_ids = freee_employees.map { |emp| emp["id"].to_s }
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    all_shifts = Shift.where(
      employee_id: employee_ids,
      shift_date: start_date..end_date
    ).includes(:employee)

    shifts_by_employee = all_shifts.group_by(&:employee_id)

    freee_employees.map do |employee_data|
      employee_id = employee_data["id"].to_s
      employee_shifts = shifts_by_employee[employee_id] || []

      # 内部計算はEmployeeモデルに委譲
      wage_info = Employee.calculate_wage_from_shifts(employee_shifts)

      {
        employee_id: employee_id,
        employee_name: employee_data["display_name"] || "ID: #{employee_id}",
        wage: wage_info[:total],
        breakdown: wage_info[:breakdown],
        work_hours: wage_info[:work_hours],
        target: Employee.monthly_wage_target,
        percentage: (wage_info[:total].to_f / Employee.monthly_wage_target * 100).round(2)
      }
    end
  rescue StandardError => e
    Rails.logger.error "全従業員給与取得エラー: #{e.message}"
    []
  end

  # 従業員の詳細給与情報取得（外部API連携）
  def get_employee_wage_info(employee_id, month, year)
    employee_info = @freee_api_service.get_employee_info(employee_id)
    unless employee_info
      return {
        error: "指定された従業員IDが見つかりません",
        employee_id: employee_id
      }
    end

    # 内部計算はEmployeeモデルに委譲
    employee = Employee.find_by(employee_id: employee_id)
    if employee
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month
      wage_info = employee.calculate_wage_for_period(start_date, end_date)

      {
        employee_id: employee_id,
        employee_name: employee_info["display_name"] || employee.display_name,
        wage: wage_info[:total],
        breakdown: wage_info[:breakdown],
        work_hours: wage_info[:work_hours],
        target: Employee.monthly_wage_target,
        percentage: (wage_info[:total].to_f / Employee.monthly_wage_target * 100).round(2),
        is_over_limit: wage_info[:total] >= Employee.monthly_wage_target,
        remaining: [Employee.monthly_wage_target - wage_info[:total], 0].max
      }
    else
      {
        error: "従業員データが見つかりません",
        employee_id: employee_id
      }
    end
  rescue StandardError => e
    Rails.logger.error "従業員給与取得エラー: #{e.message}"
    {
      error: "給与計算中にエラーが発生しました: #{e.message}",
      employee_id: employee_id
    }
  end

  # 現在月の給与情報取得（外部API連携）
  def get_current_wage_info(employee_id)
    now = Time.current
    wage_data = get_employee_wage_info(employee_id, now.month, now.year)

    return { wage: 0, target: Employee.monthly_wage_target, percentage: 0 } if wage_data[:error]

    {
      wage: wage_data[:wage],
      target: wage_data[:target],
      percentage: wage_data[:percentage]
    }
  rescue StandardError => e
    Rails.logger.error "給与情報取得エラー: #{e.message}"
    { wage: 0, target: Employee.monthly_wage_target, percentage: 0 }
  end
end
