# frozen_string_literal: true

class ShiftAdditionsController < ShiftBaseController

  def new
    return unless check_owner_permission

    setup_shift_form_params
    load_employees_for_view
    render 'shifts/additions_new'
  end

  def create
    return unless check_shift_addition_authorization

    # 1. パラメータの準備
    service_params = prepare_shift_addition_params

    # 2. サービスの呼び出し
    result = shift_addition_service.create_addition_request(service_params)

    # 3. レスポンスの処理
    handle_shift_service_response(
      result,
      success_path: shifts_path,
      failure_path: shift_addition_new_path
    )
  rescue StandardError => e
    handle_shift_error(e, "シフト追加リクエスト作成", shift_addition_new_path)
  end

  private

  def shift_addition_service
    @shift_addition_service ||= ShiftAdditionService.new
  end

  def prepare_shift_addition_params
    {
      requester_id: current_employee_id,
      target_employee_ids: [params[:employee_id]],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time]
    }
  end
end
