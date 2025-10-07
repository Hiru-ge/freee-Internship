# frozen_string_literal: true

class ShiftExchangesController < ShiftBaseController
  include ErrorHandler

  def new
    @employee_id = current_employee_id
    setup_shift_form_params
    load_employees_for_view
    @applicant_id = @employee_id
    respond_to do |format|
      format.html { render 'shifts/exchanges_new' }
      format.json { render json: { ok: true } }
    end
  end

  def create
    # 理想形: 3つのメソッド呼び出しで完結
    @result = ShiftExchange.create_request_for(**exchange_params)
    @result.send_notifications!

    respond_to do |format|
      format.html { redirect_to shifts_path, notice: @result.success_message }
      format.json { render json: { success: true, message: @result.success_message } }
    end
  rescue ShiftExchange::ValidationError => e
    respond_to do |format|
      format.html do
        flash.now[:error] = e.message
        setup_shift_form_params
        load_employees_for_view
        @applicant_id = current_employee_id
        render 'shifts/exchanges_new'
      end
      format.json { render json: { success: false, message: e.message } }
    end
  rescue ShiftExchange::AuthorizationError => e
    respond_to do |format|
      format.html { redirect_to shifts_path, alert: e.message }
      format.json { render json: { success: false, message: e.message } }
    end
  end

  private

  def exchange_params
    {
      applicant_id: params[:applicant_id],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time],
      approver_ids: params[:approver_ids] || []
    }
  end
end
