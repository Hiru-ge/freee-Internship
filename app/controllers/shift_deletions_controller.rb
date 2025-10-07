# frozen_string_literal: true

class ShiftDeletionsController < ShiftBaseController

  def new
    @shifts = load_future_shifts
    @shift_deletion = ShiftDeletion.new
    render 'shifts/deletions_new'
  end

  def create
    # 1. パラメータの準備
    service_params = prepare_shift_deletion_params

    # 2. サービスの呼び出し
    result = shift_deletion_service.create_deletion_request(
      service_params[:shift_id],
      service_params[:requester_id],
      service_params[:reason]
    )

    # 3. レスポンスの処理
    if result[:success]
      handle_shift_service_response(
        result,
        success_path: shifts_path,
        failure_path: shift_deletion_new_path,
        success_flash_key: :success
      )
    else
      handle_deletion_failure(result)
    end
  end

  private

  def load_future_shifts
    Shift.where(employee_id: current_employee_id)
         .where('shift_date >= ?', Date.current)
         .order(:shift_date, :start_time)
  end

  def shift_deletion_service
    @shift_deletion_service ||= ShiftDeletionService.new
  end

  def prepare_shift_deletion_params
    {
      shift_id: params[:shift_deletion][:shift_id],
      requester_id: current_employee_id,
      reason: shift_deletion_params[:reason]
    }
  end

  def handle_deletion_failure(result)
    flash.now[:error] = result[:message]
    @shifts = load_future_shifts
    @shift_deletion = ShiftDeletion.new(shift_deletion_params)
    render 'shifts/deletions_new', status: :unprocessable_content
  end

  def shift_deletion_params
    params.require(:shift_deletion).permit(:shift_id, :reason)
  end
end
