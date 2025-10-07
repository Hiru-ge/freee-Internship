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
    # 1. パラメータの準備
    service_params = prepare_approval_params("approve")

    # 2. 認証チェック
    return unless check_shift_approval_authorization(service_params[:request_id], service_params[:request_type])

    # 3. サービスの呼び出し
    result = process_approval_request(service_params)

    # 4. レスポンスの処理
    handle_shift_service_response(
      result,
      success_path: shift_approvals_path,
      failure_path: shift_approvals_path
    )
  end

  def reject
    # 1. パラメータの準備
    service_params = prepare_approval_params("reject")

    # 2. 認証チェック
    return unless check_shift_approval_authorization(service_params[:request_id], service_params[:request_type])

    # 3. サービスの呼び出し
    result = process_approval_request(service_params)

    # 4. レスポンスの処理
    handle_shift_service_response(
      result,
      success_path: shift_approvals_path,
      failure_path: shift_approvals_path
    )
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

  def prepare_approval_params(action)
    {
      request_id: params[:request_id],
      request_type: params[:request_type],
      action: action,
      approver_id: current_employee_id
    }
  end

  def process_approval_request(service_params)
    case service_params[:request_type]
    when "exchange"
      if service_params[:action] == "approve"
        shift_exchange_service.approve_exchange_request(service_params[:request_id], service_params[:approver_id])
      else
        shift_exchange_service.reject_exchange_request(service_params[:request_id], service_params[:approver_id])
      end
    when "addition"
      if service_params[:action] == "approve"
        shift_addition_service.approve_addition_request(service_params[:request_id], service_params[:approver_id])
      else
        shift_addition_service.reject_addition_request(service_params[:request_id], service_params[:approver_id])
      end
    when "deletion"
      if service_params[:action] == "approve"
        shift_deletion_service.approve_deletion_request(service_params[:request_id], service_params[:approver_id])
      else
        shift_deletion_service.reject_deletion_request(service_params[:request_id], service_params[:approver_id])
      end
    else
      { success: false, message: "不明なリクエストタイプです。" }
    end
  end

  def shift_exchange_service
    @shift_exchange_service ||= ShiftExchangeService.new
  end

  def shift_addition_service
    @shift_addition_service ||= ShiftAdditionService.new
  end

  def shift_deletion_service
    @shift_deletion_service ||= ShiftDeletionService.new
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
