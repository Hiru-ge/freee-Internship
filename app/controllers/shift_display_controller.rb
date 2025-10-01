# frozen_string_literal: true

class ShiftDisplayController < ApplicationController
  include InputValidation

  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @is_owner = owner?
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
