# frozen_string_literal: true

class WagesController < ApplicationController
  include InputValidation
  include AuthorizationCheck

  before_action :require_login

  # 給与一覧（オーナーのみ）
  def index
    return unless check_owner_permission

    @month = params[:month]&.to_i || Time.current.month
    @year = params[:year]&.to_i || Time.current.year

    wage_service = WageService.new
    @employee_wages = wage_service.get_all_employees_wages(@month, @year)

    # 月次ナビゲーション用
    @current_date = Date.new(@year, @month, 1)
    @prev_month = @current_date.prev_month
    @next_month = @current_date.next_month
    @prev_year = @prev_month.year
    @next_year = @next_month.year

    # サマリー情報
    @total_hours = @employee_wages.sum { |w| w[:work_hours].values.sum }
    @total_wage = @employee_wages.sum { |w| w[:wage] }
    @average_percentage = @employee_wages.any? ? @employee_wages.sum { |w| w[:percentage] } / @employee_wages.size : 0
  end

  # API: 給与情報をJSONで取得
  def wage_info
    employee_id = params[:employee_id] || current_employee_id
    month = params[:month]&.to_i || Time.current.month
    year = params[:year]&.to_i || Time.current.year

    wage_service = WageService.new
    wage_info = wage_service.get_employee_wage_info(employee_id, month, year)

    render json: wage_info
  end

  # API: 全従業員の給与情報をJSONで取得
  def all_wages
    month = params[:month]&.to_i || Time.current.month
    year = params[:year]&.to_i || Time.current.year

    wage_service = WageService.new
    wages = wage_service.get_all_employees_wages(month, year)

    render json: wages
  end
end
