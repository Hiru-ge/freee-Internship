# frozen_string_literal: true

class ShiftApprovalsController < ShiftBaseController
  include FreeeApiHelper

  skip_before_action :verify_authenticity_token, if: :json_request?

  def index
    @employee_id = current_employee_id
    load_pending_requests
    load_employee_data
  end

  def approve
    return unless check_authorization_and_process_request("approve")
  end

  def reject
    return unless check_authorization_and_process_request("reject")
  end

  def pending_requests_for_user
    employee_id = params[:employee_id] || current_employee_id
    all_requests = get_all_pending_requests_for(employee_id)
    render json: all_requests
  end

  def pending_exchange_requests
    employee_id = params[:employee_id] || current_employee_id
    requests = get_pending_exchange_requests_for(employee_id)
    render json: requests
  end

  def pending_addition_requests
    employee_id = params[:employee_id] || current_employee_id
    requests = get_pending_addition_requests_for(employee_id)
    render json: requests
  end

  private

  def json_request?
    request.format.json?
  end

  def load_pending_requests
    @shift_exchanges = ShiftExchange.for_approver(@employee_id).pending.includes(:shift)
    @shift_additions = ShiftAddition.for_employee(@employee_id).pending
    @shift_deletions = ShiftDeletion.pending.includes(:shift)
  end

  def load_employee_data
    @employee_names = {}
  end

  def check_authorization_and_process_request(action)
    request_id = params[:request_id]
    request_type = params[:request_type]

    return unless check_shift_approval_authorization(request_id, request_type)

    handle_shift_request(
      request_type: request_type,
      request_id: request_id,
      action: action,
      redirect_path: shift_approvals_path
    )
  end

  def get_all_pending_requests_for(employee_id)
    change_requests = get_pending_exchange_requests_for(employee_id)
    addition_requests = get_pending_addition_requests_for(employee_id)
    change_requests + addition_requests
  end

  def get_pending_exchange_requests_for(employee_id)
    shift_exchanges = ShiftExchange.for_approver(employee_id).pending.includes(:shift)

    shift_exchanges.filter_map do |exchange|
      next unless exchange.shift

      {
        type: "change",
        requestId: exchange.request_id,
        applicantId: exchange.requester_id,
        start: Time.zone.parse("#{exchange.shift.shift_date} #{exchange.shift.start_time}").iso8601,
        end: Time.zone.parse("#{exchange.shift.shift_date} #{exchange.shift.end_time}").iso8601
      }
    end
  end

  def get_pending_addition_requests_for(employee_id)
    shift_additions = ShiftAddition.for_employee(employee_id).pending

    shift_additions.map do |addition|
      {
        type: "addition",
        requestId: addition.request_id,
        applicantId: addition.requester_id,
        start: Time.zone.parse("#{addition.shift_date} #{addition.start_time}").iso8601,
        end: Time.zone.parse("#{addition.shift_date} #{addition.end_time}").iso8601
      }
    end
  end
end
