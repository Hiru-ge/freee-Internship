# frozen_string_literal: true

class ShiftDeletionsController < ApplicationController
  before_action :require_login

  def new
    @shifts = Shift.where(employee_id: current_employee_id)
                   .where('shift_date >= ?', Date.current)
                   .order(:shift_date, :start_time)
    @shift_deletion = ShiftDeletion.new
  end

  def create
    @shift = Shift.find(params[:shift_deletion][:shift_id])

    # サービスを使用して欠勤申請を作成
    service = ShiftDeletionService.new
    result = service.create_deletion_request(
      @shift.id,
      current_employee_id,
      shift_deletion_params[:reason]
    )

    if result[:success]
      flash[:success] = result[:message]
      redirect_to shifts_path
    else
      flash[:error] = result[:message]
      @shifts = Shift.where(employee_id: current_employee_id)
                     .where('shift_date >= ?', Date.current)
                     .order(:shift_date, :start_time)
      @shift_deletion = ShiftDeletion.new(shift_deletion_params)
      render :new, status: :unprocessable_content
    end
  end

  private

  def shift_deletion_params
    params.require(:shift_deletion).permit(:shift_id, :reason)
  end
end
