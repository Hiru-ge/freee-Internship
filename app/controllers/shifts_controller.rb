class ShiftsController < ApplicationController
  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @is_owner = owner?
  end

  # シフトデータの取得
  def data
    begin
      # 現在の月のシフトデータを取得
      now = Date.current
      year = now.year
      month = now.month
      
      # freee APIから従業員一覧を取得
      freee_service = FreeeApiService.new(ENV['FREEE_ACCESS_TOKEN'], ENV['FREEE_COMPANY_ID'])
      employees = freee_service.get_employees
      
      # DBからシフトデータを取得
      shifts_in_db = Shift.for_month(year, month)
      
      # 従業員データをシフト形式に変換
      shifts = {}
      employees.each do |employee|
        employee_shifts = {}
        
        # 該当従業員のシフトデータを取得
        employee_shift_records = shifts_in_db.where(employee_id: employee[:id])
        employee_shift_records.each do |shift_record|
          day = shift_record.shift_date.day
          time_string = "#{shift_record.start_time.strftime('%H')}-#{shift_record.end_time.strftime('%H')}"
          employee_shifts[day.to_s] = time_string
        end
        
        shifts[employee[:id]] = {
          name: employee[:display_name],
          shifts: employee_shifts
        }
      end
      
      shifts_data = {
        year: year,
        month: month,
        shifts: shifts
      }
      
      render json: shifts_data
    rescue => e
      Rails.logger.error "シフトデータ取得エラー: #{e.message}"
      render json: { error: "シフトデータの取得に失敗しました" }, status: 500
    end
  end

  # 従業員一覧の取得（オーナーのみ）
  def employees
    unless owner?
      render json: { error: "権限がありません" }, status: 403
      return
    end

    begin
      # freee APIから従業員一覧を取得
      freee_service = FreeeApiService.new(ENV['FREEE_ACCESS_TOKEN'], ENV['FREEE_COMPANY_ID'])
      employees = freee_service.get_employees
      
      render json: employees
    rescue => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
      render json: { error: "従業員一覧の取得に失敗しました" }, status: 500
    end
  end

end
