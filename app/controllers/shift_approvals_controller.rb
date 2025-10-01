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

    # freee APIから従業員情報を取得
    begin
      freee_service = freee_api_service
      @employees = freee_service.get_employees
      @employee_names = @employees.index_by { |emp| emp[:id] }
    rescue StandardError => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
      @employee_names = {}
    end
  end

  # シフト交代リクエストの承認
  def approve
    request_id = params[:request_id]
    request_type = params[:request_type]

    # 権限チェック
    return unless check_shift_approval_authorization(request_id, request_type)

    if request_type == "exchange"
      # 共通サービスを使用してシフト交代リクエストを承認
      shift_exchange_service = ShiftExchangeService.new
      result = shift_exchange_service.approve_exchange_request(request_id, current_employee_id)

      if result[:success]
        flash[:success] = result[:message]
      else
        flash[:error] = result[:message]
      end

    elsif request_type == "addition"
      # 共通サービスを使用してシフト追加リクエストを承認
      shift_addition_service = ShiftAdditionService.new
      result = shift_addition_service.approve_addition_request(request_id, current_employee_id)

      if result[:success]
        flash[:success] = result[:message]
      else
        flash[:error] = result[:message]
      end

    elsif request_type == "deletion"
      # 共通サービスを使用して欠勤申請を承認
      shift_deletion_service = ShiftDeletionService.new
      result = shift_deletion_service.approve_deletion_request(request_id, current_employee_id)

      if result[:success]
        flash[:success] = result[:message]
      else
        flash[:error] = result[:message]
      end
    else
      flash[:error] = "無効なリクエストタイプです"
    end

    redirect_to shift_approvals_path
  rescue StandardError => e
    Rails.logger.error "リクエスト承認エラー: #{e.message}"
    flash[:error] = "承認処理に失敗しました"
    redirect_to shift_approvals_path
  end

  # リクエストの拒否
  def reject
    request_id = params[:request_id]
    request_type = params[:request_type]

    # 権限チェック
    return unless check_shift_approval_authorization(request_id, request_type)

    if request_type == "exchange"
      # 共通サービスを使用してシフト交代リクエストを拒否
      shift_exchange_service = ShiftExchangeService.new
      result = shift_exchange_service.reject_exchange_request(request_id, current_employee_id)

      if result[:success]
        flash[:success] = result[:message]
      else
        flash[:error] = result[:message]
      end

    elsif request_type == "addition"
      # 共通サービスを使用してシフト追加リクエストを拒否
      shift_addition_service = ShiftAdditionService.new
      result = shift_addition_service.reject_addition_request(request_id, current_employee_id)

      if result[:success]
        flash[:success] = result[:message]
      else
        flash[:error] = result[:message]
      end

    elsif request_type == "deletion"
      # 共通サービスを使用して欠勤申請を拒否
      shift_deletion_service = ShiftDeletionService.new
      result = shift_deletion_service.reject_deletion_request(request_id, current_employee_id)

      if result[:success]
        flash[:success] = result[:message]
      else
        flash[:error] = result[:message]
      end
    else
      flash[:error] = "無効なリクエストタイプです"
    end

    redirect_to shift_approvals_path
  rescue StandardError => e
    Rails.logger.error "リクエスト拒否エラー: #{e.message}"
    flash[:error] = "拒否処理に失敗しました"
    redirect_to shift_approvals_path
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
