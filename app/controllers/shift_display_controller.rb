# frozen_string_literal: true

class ShiftDisplayController < ShiftBaseController
  include FreeeApiHelper

  def index
    respond_to do |format|
      format.html do
        # 1. パラメータの準備
        display_params = prepare_shift_display_params

        # 2. サービスの呼び出し
        result = shift_display_service.get_display_data(display_params)

        # 3. レスポンスの処理
        @employee = result[:employee]
        @employee_id = result[:employee_id]
        @is_owner = result[:is_owner]
        render 'shifts/index'
      end
      format.json do
        # 1. パラメータの準備
        service_params = prepare_monthly_shifts_params

        # 2. サービスの呼び出し
        result = shift_display_service.get_monthly_shifts(service_params[:year], service_params[:month])

        # 3. レスポンスの処理
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

  def shift_display_service
    @shift_display_service ||= ShiftDisplayService.new(freee_api_service)
  end

  def prepare_shift_display_params
    {
      employee: current_employee,
      employee_id: current_employee_id,
      is_owner: owner?
    }
  end

  def prepare_monthly_shifts_params
    now = Date.current
    {
      year: now.year,
      month: now.month
    }
  end
end
