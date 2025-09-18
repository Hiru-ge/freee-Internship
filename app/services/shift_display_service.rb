class ShiftDisplayService
  def initialize(freee_api_service = nil)
    @freee_api_service = freee_api_service
  end

  # 月次シフトデータの取得（Webアプリ用）
  def get_monthly_shifts(year, month)
    begin
      # freee APIから従業員一覧を取得
      employees = get_employees_from_api
      
      # DBからシフトデータを取得（N+1問題を解決するためincludesを使用）
      shifts_in_db = Shift.for_month(year, month).includes(:employee)
      
      # 従業員データをシフト形式に変換（N+1問題を解決するため一括処理）
      shifts = {}
      employee_ids = employees.map { |emp| emp[:id] }
      
      # 従業員ごとにシフトデータをグループ化
      shifts_by_employee = shifts_in_db.group_by(&:employee_id)
      
      employees.each do |employee|
        employee_shifts = {}
        employee_id = employee[:id]
        
        # 該当従業員のシフトデータを取得（N+1問題を解決）
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
    rescue => e
      Rails.logger.error "月次シフトデータ取得エラー: #{e.message}"
      {
        success: false,
        error: "シフトデータの取得に失敗しました"
      }
    end
  end

  # 個人シフトデータの取得（LINE Bot用）
  def get_employee_shifts(employee_id, start_date = nil, end_date = nil)
    begin
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
    rescue => e
      Rails.logger.error "個人シフトデータ取得エラー: #{e.message}"
      {
        success: false,
        error: "シフトデータの取得に失敗しました"
      }
    end
  end

  # 全従業員シフトデータの取得（LINE Bot用）
  def get_all_employee_shifts(start_date = nil, end_date = nil)
    begin
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
            start_time: shift.start_time.strftime('%H:%M'),
            end_time: shift.end_time.strftime('%H:%M')
          }
        end
      end
      
      {
        success: true,
        data: all_shifts
      }
    rescue => e
      Rails.logger.error "全従業員シフトデータ取得エラー: #{e.message}"
      {
        success: false,
        error: "シフトデータの取得に失敗しました"
      }
    end
  end

  # シフトデータのフォーマット（LINE Bot用）
  def format_employee_shifts_for_line(shifts)
    return "今月のシフト情報はありません。" if shifts.empty?
    
    message = "📅 今月のシフト\n\n"
    shifts.each do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      message += "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    end
    
    message
  end

  # 全従業員シフトデータのフォーマット（LINE Bot用）
  def format_all_shifts_for_line(all_shifts)
    return "【今月の全員シフト】\n今月のシフト情報はありません。" if all_shifts.empty?
    
    # 日付ごとにグループ化
    grouped_shifts = all_shifts.group_by { |shift| shift[:date] }
    
    # シフト情報をフォーマット
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

  private

  # freee APIから従業員情報を取得
  def get_employees_from_api
    if @freee_api_service
      @freee_api_service.get_employees
    else
      # フォールバック: DBから従業員情報を取得
      Employee.all.map do |emp|
        {
          id: emp.employee_id,
          display_name: emp.display_name
        }
      end
    end
  end
end
