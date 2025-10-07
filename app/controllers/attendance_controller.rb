# frozen_string_literal: true

class AttendanceController < ApplicationController

  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @clock_service = ClockService.new(@employee_id)
    @clock_status = @clock_service.get_clock_status

    @employee_name ||= get_employee_name
    @is_owner ||= owner?
    render 'dashboard/attendance'
  end

  def clock_in
    result = perform_clock_action(:clock_in)
    render json: result
  end

  def clock_out
    result = perform_clock_action(:clock_out)
    render json: result
  end

  def clock_status
    status = get_clock_status
    render json: status
  end

  def attendance_history
    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month

    clock_service = ClockService.new(current_employee_id)
    attendance_data = clock_service.get_attendance_for_month(year, month)

    render json: attendance_data
  end

  private

  def perform_clock_action(action)
    clock_service = ClockService.new(current_employee_id)
    clock_service.send(action)
  end

  def get_clock_status
    clock_service = ClockService.new(current_employee_id)
    clock_service.get_clock_status
  end
end
