# frozen_string_literal: true

class ShiftDeletionsController < ApplicationController

  def new
    @shifts = load_future_shifts
    @shift_deletion = ShiftDeletion.new
  end

  def create
    @shift = Shift.find(params[:shift_deletion][:shift_id])
    result = create_shift_deletion_request

    if result[:success]
      handle_service_response(
        result,
        success_path: shifts_path,
        failure_path: nil,
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

  def create_shift_deletion_request
    service = ShiftDeletionService.new
    service.create_deletion_request(
      @shift.id,
      current_employee_id,
      shift_deletion_params[:reason]
    )
  end

  def handle_deletion_failure(result)
    flash.now[:error] = result[:message]
    @shifts = load_future_shifts
    @shift_deletion = ShiftDeletion.new(shift_deletion_params)
    render :new, status: :unprocessable_content
  end

  def shift_deletion_params
    params.require(:shift_deletion).permit(:shift_id, :reason)
  end
end
