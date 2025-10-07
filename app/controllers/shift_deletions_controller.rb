# frozen_string_literal: true

class ShiftDeletionsController < ShiftBaseController

  def new
    @shifts = load_future_shifts
    @shift_deletion = ShiftDeletion.new
    render 'shifts/deletions_new'
  end

  def create
    # 理想形: 3つのメソッド呼び出しで完結
    @result = ShiftDeletion.create_request_for(**shift_deletion_params_for_model)
    @result.send_notifications!
    flash[:success] = @result.success_message
    redirect_to shifts_path
  rescue ShiftDeletion::ValidationError => e
    flash.now[:error] = e.message
    @shifts = load_future_shifts
    @shift_deletion = ShiftDeletion.new(shift_deletion_params)
    render 'shifts/deletions_new', status: :unprocessable_content
  rescue ShiftDeletion::AuthorizationError => e
    redirect_to shifts_path, alert: e.message
  end

  private

  def load_future_shifts
    Shift.where(employee_id: current_employee_id)
         .where('shift_date >= ?', Date.current)
         .order(:shift_date, :start_time)
  end

  def shift_deletion_params_for_model
    {
      shift_id: params[:shift_deletion][:shift_id],
      requester_id: current_employee_id,
      reason: shift_deletion_params[:reason]
    }
  end

  def shift_deletion_params
    params.require(:shift_deletion).permit(:shift_id, :reason)
  end
end
