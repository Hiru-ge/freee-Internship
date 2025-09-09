class DashboardController < ApplicationController
  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @is_owner = owner?
    @employee_name = get_employee_name
    @clock_service = ClockService.new(@employee_id)
    @clock_status = @clock_service.get_clock_status
    
    # 給与情報を取得
    wage_service = WageService.new
    @wage_info = wage_service.get_wage_info(@employee_id)
  end

  # 出勤打刻
  def clock_in
    clock_service = ClockService.new(current_employee_id)
    result = clock_service.clock_in
    
    respond_to do |format|
      format.json { render json: result }
    end
  end

  # 退勤打刻
  def clock_out
    clock_service = ClockService.new(current_employee_id)
    result = clock_service.clock_out
    
    respond_to do |format|
      format.json { render json: result }
    end
  end

  # 打刻状態の取得
  def clock_status
    clock_service = ClockService.new(current_employee_id)
    status = clock_service.get_clock_status
    
    respond_to do |format|
      format.json { render json: status }
    end
  end

  # 勤怠履歴の取得
  def attendance_history
    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month
    
    clock_service = ClockService.new(current_employee_id)
    attendance_data = clock_service.get_attendance_for_month(year, month)
    
    respond_to do |format|
      format.json { render json: attendance_data }
    end
  end

  private

  def get_employee_name
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      employee_info = freee_service.get_employee_info(current_employee_id)
      employee_info['display_name'] || 'Unknown'
    rescue => error
      Rails.logger.error "Failed to get employee name: #{error.message}"
      'Unknown'
    end
  end
end
