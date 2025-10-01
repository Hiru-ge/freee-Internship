# frozen_string_literal: true

class ShiftApprovalsController < ApplicationController
  include InputValidation

  skip_before_action :verify_authenticity_token, if: :json_request?


  # リクエスト一覧表示
  def index
    @employee_id = current_employee_id

    # 自分宛のリクエストを取得
    @shift_exchanges = ShiftExchange.for_approver(@employee_id).pending.includes(:shift)
    @shift_additions = ShiftAddition.for_employee(@employee_id).pending
    @shift_deletions = ShiftDeletion.pending.includes(:shift)

    # 従業員情報を取得（共通化されたメソッドを使用）
    load_employees_for_view
    @employee_names = fetch_employee_names
  end

  # シフト交代リクエストの承認
  def approve
    request_id = params[:request_id]
    request_type = params[:request_type]

    # 権限チェック
    return unless check_shift_approval_authorization(request_id, request_type)

    # 共通化されたメソッドを使用してリクエストを処理
    handle_shift_request(
      request_type: request_type,
      request_id: request_id,
      action: "approve",
      redirect_path: shift_approvals_path
    )
  end

  # リクエストの拒否
  def reject
    request_id = params[:request_id]
    request_type = params[:request_type]

    # 権限チェック
    return unless check_shift_approval_authorization(request_id, request_type)

    # 共通化されたメソッドを使用してリクエストを処理
    handle_shift_request(
      request_type: request_type,
      request_id: request_id,
      action: "reject",
      redirect_path: shift_approvals_path
    )
  end

  # API: 指定した従業員宛の全リクエストを取得（GAS互換）
  def pending_requests_for_user
    employee_id = params[:employee_id] || current_employee_id

    change_requests = get_pending_exchange_requests_for(employee_id)
    addition_requests = get_pending_addition_requests_for(employee_id)
    all_requests = change_requests + addition_requests

    render json: all_requests
  end

  # API: 指定した従業員宛のシフト交代リクエストを取得（GAS互換）
  def pending_exchange_requests
    employee_id = params[:employee_id] || current_employee_id
    requests = get_pending_exchange_requests_for(employee_id)

    render json: requests
  end

  # API: 指定した従業員宛のシフト追加リクエストを取得（GAS互換）
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
  def get_pending_exchange_requests_for(employee_id)
    shift_exchanges = ShiftExchange.for_approver(employee_id).pending.includes(:shift)

    shift_exchanges.filter_map do |exchange|
      next unless exchange.shift # shiftが存在しない場合はスキップ

      {
        type: "change",
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
        type: "addition",
        requestId: addition.request_id,
        applicantId: addition.requester_id,
        start: Time.zone.parse("#{addition.shift_date} #{addition.start_time}").iso8601,
        end: Time.zone.parse("#{addition.shift_date} #{addition.end_time}").iso8601
      }
    end
  end
end
