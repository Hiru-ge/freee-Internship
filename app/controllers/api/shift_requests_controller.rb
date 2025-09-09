class Api::ShiftRequestsController < ApplicationController
  before_action :require_login
  skip_before_action :verify_authenticity_token, if: :json_request?

  # 指定した従業員宛の全リクエストを取得（GAS互換）
  def pending_requests_for_user
    employee_id = params[:employee_id] || current_employee_id
    
    change_requests = get_pending_change_requests_for(employee_id)
    addition_requests = get_pending_addition_requests_for(employee_id)
    all_requests = change_requests + addition_requests
    
    render json: all_requests
  end

  # 指定した従業員宛のシフト交代リクエストを取得（GAS互換）
  def pending_change_requests
    employee_id = params[:employee_id] || current_employee_id
    requests = get_pending_change_requests_for(employee_id)
    
    render json: requests
  end

  # 指定した従業員宛のシフト追加リクエストを取得（GAS互換）
  def pending_addition_requests
    employee_id = params[:employee_id] || current_employee_id
    requests = get_pending_addition_requests_for(employee_id)
    
    render json: requests
  end

  private

  def json_request?
    request.format.json?
  end

  # シフト交代リクエストを取得
  def get_pending_change_requests_for(employee_id)
    shift_exchanges = ShiftExchange.for_approver(employee_id).pending.includes(:shift)
    
    shift_exchanges.map do |exchange|
      {
        type: 'change',
        requestId: exchange.request_id,
        applicantId: exchange.requester_id,
        start: Time.zone.parse("#{exchange.shift.shift_date} #{exchange.shift.start_time}").iso8601,
        end: Time.zone.parse("#{exchange.shift.shift_date} #{exchange.shift.end_time}").iso8601
      }
    end
  end

  # シフト追加リクエストを取得
  def get_pending_addition_requests_for(employee_id)
    shift_additions = ShiftAddition.for_employee(employee_id).pending
    
    shift_additions.map do |addition|
      {
        type: 'addition',
        requestId: addition.request_id,
        applicantId: addition.requester_id,
        start: Time.zone.parse("#{addition.shift_date} #{addition.start_time}").iso8601,
        end: Time.zone.parse("#{addition.shift_date} #{addition.end_time}").iso8601
      }
    end
  end
end
