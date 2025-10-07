# frozen_string_literal: true

class ShiftExchangesController < ApplicationController
  include InputValidation
  include ErrorHandler

  def new
    @employee_id = current_employee_id
    @date = params[:date] || Date.current.strftime("%Y-%m-%d")
    @start_time = params[:start] || "09:00"
    @end_time = params[:end] || "18:00"

    load_employees_for_view
    @applicant_id = @employee_id
    render 'shifts/exchanges_new'
  end

  def create
    request_params = extract_request_params

    return unless validate_shift_params(request_params, shift_exchange_new_path)

    validation_result = validate_exchange_request(request_params)
    return if validation_result[:redirect]

    result = create_shift_exchange_request(request_params)
    handle_service_response(
      result,
      success_path: shifts_path,
      failure_path: shift_exchange_new_path,
      success_flash_key: :notice,
      error_flash_key: :error
    )
  rescue StandardError => e
    handle_api_error(e, "シフト交代リクエスト作成", shift_exchange_new_path)
  end

  private

  def extract_request_params
    {
      applicant_id: params[:applicant_id],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time],
      approver_ids: params[:approver_ids] || []
    }
  end

  def validate_exchange_request(params)
    if params[:applicant_id].blank? || params[:shift_date].blank? ||
       params[:start_time].blank? || params[:end_time].blank?
      flash[:error] = "すべての項目を入力してください。"
      redirect_to shift_exchange_new_path
      return { redirect: true }
    end

    if params[:approver_ids].blank?
      flash[:error] = "交代を依頼する相手を選択してください。"
      redirect_to shift_exchange_new_path
      return { redirect: true }
    end

    { redirect: false }
  end

  def create_shift_exchange_request(request_params)
    shift_exchange_service = ShiftExchangeService.new
    shift_exchange_service.create_exchange_request(request_params)
  end
end
