# frozen_string_literal: true

class ShiftsController < ApplicationController
  include InputValidation

  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @is_owner = owner?

    # 給与情報を取得（freee API呼び出し最適化）
    wage_service = WageService.new(freee_api_service)
    if @is_owner
      # オーナー: 全従業員の給与情報
      @employee_wages = wage_service.get_all_employees_wages(
        Date.current.month,
        Date.current.year
      )
    else
      # 従業員: 個人の給与情報
      @wage_info = wage_service.get_wage_info(@employee_id)
    end
  end

  # 従業員一覧の取得（オーナーのみ）
  def employees
    unless owner?
      render json: { error: "権限がありません" }, status: :forbidden
      return
    end

    begin
      # freee APIから従業員一覧を取得（共通インスタンス使用）
      employees = freee_api_service.get_employees

      # 従業員データを整形
      formatted_employees = employees.map do |employee|
        {
          id: employee[:id],
          employee_id: employee[:id], # 給与データとの整合性のため
          display_name: employee[:display_name]
        }
      end

      render json: formatted_employees
    rescue StandardError => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
      render json: { error: "従業員一覧の取得に失敗しました" }, status: 500
    end
  end

  # シフトデータの取得
  def data
    # 現在の月のシフトデータを取得
    now = Date.current
    year = now.year
    month = now.month

    # 共通サービスを使用してシフトデータを取得
    shift_display_service = ShiftDisplayService.new(freee_api_service)
    result = shift_display_service.get_monthly_shifts(year, month)

    if result[:success]
      render json: result[:data]
    else
      render json: { error: result[:error] }, status: 500
    end
  rescue StandardError => e
    Rails.logger.error "シフトデータ取得エラー: #{e.message}"
    render json: { error: "シフトデータの取得に失敗しました" }, status: 500
  end

end
