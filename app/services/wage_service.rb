class WageService
  # 時間帯別時給レート（GAS互換）
  TIME_ZONE_WAGE_RATES = {
    normal: { start: 9, end: 18, rate: 1000, name: '通常時給' },
    evening: { start: 18, end: 22, rate: 1200, name: '夜間手当' },
    night: { start: 22, end: 9, rate: 1500, name: '深夜手当' }
  }.freeze

  # 月間給与目標（103万の壁）
  MONTHLY_WAGE_TARGET = 1_030_000

  def initialize
  end

  # 時間帯を判定する
  def get_time_zone(hour)
    if hour >= 9 && hour < 18
      :normal
    elsif hour >= 18 && hour < 22
      :evening
    else
      :night
    end
  end

  # シフト時間を時間帯別に分解して勤務時間を計算
  def calculate_work_hours_by_time_zone(shift_date, start_time, end_time)
    start_hour = start_time.hour
    end_hour = end_time.hour
    time_zone_hours = { normal: 0, evening: 0, night: 0 }

    # 日をまたぐ場合の処理
    if end_hour <= start_hour
      # 深夜勤務（日をまたぐ）
      (start_hour...24).each do |hour|
        time_zone = get_time_zone(hour)
        time_zone_hours[time_zone] += 1
      end
      (0...end_hour).each do |hour|
        time_zone = get_time_zone(hour)
        time_zone_hours[time_zone] += 1
      end
    else
      # 通常勤務（同日内）
      (start_hour...end_hour).each do |hour|
        time_zone = get_time_zone(hour)
        time_zone_hours[time_zone] += 1
      end
    end

    time_zone_hours
  end

  # 指定月の従業員の勤務時間を計算
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

  # 指定月の従業員の給与を計算
  def calculate_monthly_wage(employee_id, month, year)
    begin
      monthly_work_hours = calculate_monthly_work_hours(employee_id, month, year)
      
      breakdown = {}
      total = 0

      monthly_work_hours.each do |time_zone, hours|
        rate = TIME_ZONE_WAGE_RATES[time_zone][:rate]
        wage = hours * rate
        
        breakdown[time_zone] = {
          hours: hours,
          rate: rate,
          wage: wage,
          name: TIME_ZONE_WAGE_RATES[time_zone][:name]
        }
        
        total += wage
      end

      {
        total: total,
        breakdown: breakdown,
        work_hours: monthly_work_hours
      }
      
    rescue => e
      Rails.logger.error "給与計算エラー: #{e.message}"
      {
        total: 0,
        breakdown: {},
        work_hours: { normal: 0, evening: 0, night: 0 }
      }
    end
  end

  # 全従業員の給与情報を取得
  def get_all_employees_wages(month, year)
    begin
      employees = Employee.all
      all_wages = []
      
      employees.each do |employee|
        wage_info = calculate_monthly_wage(employee.employee_id, month, year)
        
        all_wages << {
          employee_id: employee.employee_id,
          employee_name: employee.display_name || "ID: #{employee.employee_id}",
          wage: wage_info[:total],
          breakdown: wage_info[:breakdown],
          work_hours: wage_info[:work_hours],
          target: MONTHLY_WAGE_TARGET,
          percentage: (wage_info[:total].to_f / MONTHLY_WAGE_TARGET * 100).round(2)
        }
      end

      all_wages
    rescue => e
      Rails.logger.error "全従業員給与取得エラー: #{e.message}"
      []
    end
  end

  # 指定従業員の給与情報を取得
  def get_employee_wage_info(employee_id, month, year)
    begin
      employee = Employee.find_by(employee_id: employee_id)
      unless employee
        return {
          error: '指定された従業員IDが見つかりません',
          employee_id: employee_id
        }
      end
      
      wage_info = calculate_monthly_wage(employee_id, month, year)
      
      {
        employee_id: employee_id,
        employee_name: employee.display_name || "ID: #{employee_id}",
        wage: wage_info[:total],
        breakdown: wage_info[:breakdown],
        work_hours: wage_info[:work_hours],
        target: MONTHLY_WAGE_TARGET,
        percentage: (wage_info[:total].to_f / MONTHLY_WAGE_TARGET * 100).round(2),
        is_over_limit: wage_info[:total] >= MONTHLY_WAGE_TARGET,
        remaining: [MONTHLY_WAGE_TARGET - wage_info[:total], 0].max
      }
      
    rescue => e
      Rails.logger.error "従業員給与取得エラー: #{e.message}"
      {
        error: "給与計算中にエラーが発生しました: #{e.message}",
        employee_id: employee_id
      }
    end
  end

  # 現在月の給与情報を取得（簡易版）
  def get_wage_info(employee_id)
    begin
      now = Time.current
      current_month = now.month
      current_year = now.year
      
      wage_data = get_employee_wage_info(employee_id, current_month, current_year)
      
      if wage_data[:error]
        return { wage: 0, target: MONTHLY_WAGE_TARGET, percentage: 0 }
      end
      
      {
        wage: wage_data[:wage],
        target: wage_data[:target],
        percentage: wage_data[:percentage]
      }
    rescue => e
      Rails.logger.error "給与情報取得エラー: #{e.message}"
      { wage: 0, target: MONTHLY_WAGE_TARGET, percentage: 0 }
    end
  end

  # freee APIから基本時給を取得（将来の拡張用）
  def get_hourly_wage_from_freee(employee_id)
    begin
      # freee APIの実装は将来の拡張で追加
      # 現在は固定値を使用
      1000
    rescue => e
      Rails.logger.error "freee API時給取得エラー: #{e.message}"
      1000
    end
  end
end
