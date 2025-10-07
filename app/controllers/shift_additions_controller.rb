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

    # 理想形: 3つのメソッド呼び出しで完結
    @result = ShiftAddition.create_request_for(**shift_addition_params)
    @result.send_notifications!
    redirect_to shifts_path, notice: @result.success_message
  rescue ShiftAddition::ValidationError => e
    flash.now[:error] = e.message
    setup_shift_form_params
    load_employees_for_view
    render 'shifts/additions_new'
  rescue ShiftAddition::AuthorizationError => e
    redirect_to shifts_path, alert: e.message
  end

  private

  def shift_addition_params
    {
      requester_id: current_employee_id,
      target_employee_ids: [params[:employee_id]],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time]
    }
  end
end
