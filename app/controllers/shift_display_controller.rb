# frozen_string_literal: true

class ShiftDisplayController < ShiftBaseController
  include FreeeApiHelper

  def index
    respond_to do |format|
      format.html do
        @employee = current_employee
        @employee_id = current_employee_id
        @is_owner = owner?
        render 'shifts/index'
      end
      format.json do
        now = Date.current
        result = fetch_monthly_shifts(now.year, now.month)

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
  end

  private

  def fetch_monthly_shifts(year, month)
    shift_display_service = ShiftDisplayService.new(freee_api_service)
    shift_display_service.get_monthly_shifts(year, month)
  end
end
