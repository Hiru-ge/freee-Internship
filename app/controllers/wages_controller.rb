# frozen_string_literal: true

class WagesController < ApplicationController
  include FreeeApiHelper

  def index
    @month = params[:month]&.to_i || Time.current.month
    @year = params[:year]&.to_i || Time.current.year
    @employee_id = params[:employee_id]

    if @employee_id.present?
      # 特定従業員の給料情報を表示
      wage_service = WageService.new
      wage_info = wage_service.get_employee_wage_info(@employee_id, @month, @year)

      respond_to do |format|
        format.html do
          @employee_wages = [wage_info]
          setup_navigation_variables
          calculate_summary_statistics
        end
        format.json do
          render json: wage_info
        end
      end
    else
      # 全従業員のデータを表示（オーナー権限確認）
      return unless check_owner_permission

      wage_service = WageService.new(freee_api_service)
      @employee_wages = wage_service.get_all_employees_wages(@month, @year)

      respond_to do |format|
        format.html do
          setup_navigation_variables
          calculate_summary_statistics
        end
        format.json do
          render json: @employee_wages
        end
      end
    end
  end

  def wage_info
    employee_id = params[:employee_id] || current_employee_id
    month = params[:month]&.to_i || Time.current.month
    year = params[:year]&.to_i || Time.current.year

    wage_service = WageService.new
    wage_info = wage_service.get_employee_wage_info(employee_id, month, year)

    render json: wage_info
  end

  def all_wages
    month = params[:month]&.to_i || Time.current.month
    year = params[:year]&.to_i || Time.current.year

    wage_service = WageService.new
    wages = wage_service.get_all_employees_wages(month, year)

    render json: wages
  end

  def employees
    unless owner?
      render json: { error: "権限がありません" }, status: :forbidden
      return
    end

    begin
      employees = fetch_employees
      formatted_employees = format_employee_data(employees)
      render json: formatted_employees
    rescue StandardError => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
      render json: { error: "従業員一覧の取得に失敗しました" }, status: 500
    end
  end

  private

  def setup_navigation_variables
    @current_date = Date.new(@year, @month, 1)
    @prev_month = @current_date.prev_month
    @next_month = @current_date.next_month
    @prev_year = @prev_month.year
    @next_year = @next_month.year
  end

  def calculate_summary_statistics
    @total_hours = @employee_wages.sum { |w| w[:work_hours].values.sum }
    @total_wage = @employee_wages.sum { |w| w[:wage] }
    @average_percentage = @employee_wages.any? ? @employee_wages.sum { |w| w[:percentage] } / @employee_wages.size : 0
  end

  def format_employee_data(employees)
    employees.map do |employee|
      {
        id: employee[:id],
        employee_id: employee[:id],
        display_name: employee[:display_name]
      }
    end
  end
end
