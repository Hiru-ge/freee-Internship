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

    begin
      return unless validate_shift_form_params(params, %i[employee_id shift_date start_time end_time], shift_addition_new_path)

      overlapping_employee = check_shift_overlap
      if overlapping_employee
        flash[:error] = "#{overlapping_employee}は指定された時間にシフトが入っています。"
        redirect_to shift_addition_new_path and return
      end

      result = create_shift_addition_request
      handle_shift_service_response(
        result,
        success_path: shifts_path,
        failure_path: shift_addition_new_path
      )
    rescue StandardError => e
      handle_shift_error(e, "シフト追加リクエスト作成", shift_addition_new_path)
    end
  end

  private

  def check_shift_overlap
    check_shift_overlap_for_employee(
      params[:employee_id],
      params[:shift_date],
      params[:start_time],
      params[:end_time]
    )
  end

  def create_shift_addition_request
    request_params = {
      requester_id: current_employee_id,
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time],
      target_employee_ids: [params[:employee_id]]
    }

    shift_addition_service = ShiftAdditionService.new
    shift_addition_service.create_addition_request(request_params)
  end
end
