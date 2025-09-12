class WageService
  # 時間帯別時給レート（設定ファイルから取得）
  def self.time_zone_wage_rates
    @time_zone_wage_rates ||= begin
      time_zone_rates = AppConstants.wage[:time_zone_rates] || {}
      {
        normal: { start: time_zone_rates.dig(:normal, :start_hour) || 9, end: time_zone_rates.dig(:normal, :end_hour) || 18, rate: time_zone_rates.dig(:normal, :rate) || 1000, name: time_zone_rates.dig(:normal, :name) || '通常時給' },
        evening: { start: time_zone_rates.dig(:evening, :start_hour) || 18, end: time_zone_rates.dig(:evening, :end_hour) || 22, rate: time_zone_rates.dig(:evening, :rate) || 1200, name: time_zone_rates.dig(:evening, :name) || '夜間手当' },
        night: { start: time_zone_rates.dig(:night, :start_hour) || 22, end: time_zone_rates.dig(:night, :end_hour) || 9, rate: time_zone_rates.dig(:night, :rate) || 1500, name: time_zone_rates.dig(:night, :name) || '深夜手当' }
      }.freeze
    end
  end

  # 月間給与目標（設定ファイルから取得）
  def self.monthly_wage_target
    AppConstants.monthly_wage_target
  end

  def initialize
  end

  # 時間帯を判定する
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
        work_hours: monthly_work_hours
      }
      
    rescue => error
      Rails.logger.error "給与計算エラー: #{error.message}"
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
      # freeeAPIから従業員一覧を取得
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      freee_employees = freee_service.get_all_employees
      
      if freee_employees.empty?
        Rails.logger.warn "freeeAPIから従業員データを取得できませんでした"
        return []
      end
      
      all_wages = []
      
      freee_employees.each do |employee_data|
        employee_id = employee_data['id'].to_s
        wage_info = calculate_monthly_wage(employee_id, month, year)
        
        all_wages << {
          employee_id: employee_id,
          employee_name: employee_data['display_name'] || "ID: #{employee_id}",
          wage: wage_info[:total],
          breakdown: wage_info[:breakdown],
          work_hours: wage_info[:work_hours],
          target: self.class.monthly_wage_target,
          percentage: (wage_info[:total].to_f / self.class.monthly_wage_target * 100).round(2)
        }
      end

      all_wages
    rescue => error
      Rails.logger.error "全従業員給与取得エラー: #{error.message}"
      []
    end
  end

  # 指定従業員の給与情報を取得
  def get_employee_wage_info(employee_id, month, year)
    begin
      # freeeAPIから従業員情報を取得
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      employee_info = freee_service.get_employee_info(employee_id)
      unless employee_info
        return {
          error: '指定された従業員IDが見つかりません',
          employee_id: employee_id
        }
      end
      
      wage_info = calculate_monthly_wage(employee_id, month, year)
      
      {
        employee_id: employee_id,
        employee_name: employee_info['display_name'] || "ID: #{employee_id}",
        wage: wage_info[:total],
        breakdown: wage_info[:breakdown],
        work_hours: wage_info[:work_hours],
        target: self.class.monthly_wage_target,
        percentage: (wage_info[:total].to_f / self.class.monthly_wage_target * 100).round(2),
        is_over_limit: wage_info[:total] >= self.class.monthly_wage_target,
        remaining: [self.class.monthly_wage_target - wage_info[:total], 0].max
      }
      
    rescue => error
      Rails.logger.error "従業員給与取得エラー: #{error.message}"
      {
        error: "給与計算中にエラーが発生しました: #{error.message}",
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
        return { wage: 0, target: self.class.monthly_wage_target, percentage: 0 }
      end
      
      {
        wage: wage_data[:wage],
        target: wage_data[:target],
        percentage: wage_data[:percentage]
      }
    rescue => error
      Rails.logger.error "給与情報取得エラー: #{error.message}"
      { wage: 0, target: self.class.monthly_wage_target, percentage: 0 }
    end
  end

  # freee APIから基本時給を取得（将来の拡張用）
  def get_hourly_wage_from_freee(employee_id)
    begin
      # freee APIの実装は将来の拡張で追加
      # 現在は固定値を使用
      1000
    rescue => error
      Rails.logger.error "freee API時給取得エラー: #{error.message}"
      1000
    end
  end
end
