# frozen_string_literal: true

class ShiftAdditionsController < ApplicationController
  include InputValidation

  def new
    return unless check_owner_permission

    @date = params[:date] || Date.current.strftime("%Y-%m-%d")
    @start_time = params[:start] || "09:00"
    @end_time = params[:end] || "18:00"

    load_employees_for_view
    render 'shifts/additions_new'
  end

  def create
    return unless check_shift_addition_authorization

    begin
      return unless validate_required_params(params, %i[employee_id shift_date start_time end_time], new_shift_addition_path)
      return unless validate_shift_params(params, new_shift_addition_path)

      overlapping_employee = check_shift_overlap
      if overlapping_employee
        flash[:error] = "#{overlapping_employee}は指定された時間にシフトが入っています。"
        redirect_to new_shift_addition_path and return
      end

      result = create_shift_addition_request
      handle_service_response(
        result,
        success_path: shifts_path,
        failure_path: new_shift_addition_path,
        success_flash_key: :notice,
        error_flash_key: :error
      )
    rescue StandardError => e
      handle_api_error(e, "シフト追加リクエスト作成", new_shift_addition_path)
    end
  end

  private

  def check_shift_overlap
    display_service = ShiftDisplayService.new
    display_service.check_addition_overlap(
      params[:employee_id],
      Date.parse(params[:shift_date]),
      Time.zone.parse(params[:start_time]),
      Time.zone.parse(params[:end_time])
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
