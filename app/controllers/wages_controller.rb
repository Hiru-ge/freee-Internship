class WagesController < ApplicationController
  before_action :require_login

  # 給与一覧（オーナーのみ）
  def index
    unless owner?
      flash[:error] = 'このページにアクセスする権限がありません'
      redirect_to dashboard_path and return
    end
    
    @month = params[:month]&.to_i || Time.current.month
    @year = params[:year]&.to_i || Time.current.year
    
    wage_service = WageService.new
    @wages = wage_service.get_all_employees_wages(@month, @year)
    
    # 月次ナビゲーション用
    @current_date = Date.new(@year, @month, 1)
    @prev_month = @current_date.prev_month
    @next_month = @current_date.next_month
  end


  # API: 給与情報をJSONで取得
  def api_wage_info
    employee_id = params[:employee_id] || current_employee_id
    month = params[:month]&.to_i || Time.current.month
    year = params[:year]&.to_i || Time.current.year
    
    wage_service = WageService.new
    wage_info = wage_service.get_employee_wage_info(employee_id, month, year)
    
    render json: wage_info
  end

  # API: 全従業員の給与情報をJSONで取得
  def api_all_wages
    month = params[:month]&.to_i || Time.current.month
    year = params[:year]&.to_i || Time.current.year
    
    wage_service = WageService.new
    wages = wage_service.get_all_employees_wages(month, year)
    
    render json: wages
  end
end