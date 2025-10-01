# frozen_string_literal: true

class ShiftExchangesController < ApplicationController
  include InputValidation
  include ErrorHandler
  include RequestIdGenerator


  # シフト交代リクエスト画面の表示
  def new
    @employee_id = current_employee_id
    @date = params[:date] || Date.current.strftime("%Y-%m-%d")
    @start_time = params[:start] || "09:00"
    @end_time = params[:end] || "18:00"

    begin
      @employees = freee_api_service.get_employees
      @applicant_id = @employee_id
    rescue StandardError => e
      handle_api_error(e, "従業員一覧取得")
      @employees = []
    end
  end

  # シフト交代リクエストの作成
  def create
    request_params = extract_request_params

    # シフト関連の共通バリデーション
    return unless validate_shift_params(request_params, new_shift_exchange_path)

    # ビジネスロジックのバリデーション
    validation_result = validate_exchange_request(request_params)
    return if validation_result[:redirect]

    # 共通サービスを使用してシフト交代リクエストを作成
    shift_exchange_service = ShiftExchangeService.new
    result = shift_exchange_service.create_exchange_request(request_params)

    if result[:success]
      flash[:notice] = result[:message]
      redirect_to shifts_path
    else
      flash[:error] = result[:message]
      redirect_to new_shift_exchange_path
    end
  rescue StandardError => e
    handle_api_error(e, "シフト交代リクエスト作成", new_shift_exchange_path)
  end

  private

  # リクエストパラメータの抽出
  def extract_request_params
    {
      applicant_id: params[:applicant_id],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time],
      approver_ids: params[:approver_ids] || []
    }
  end

  # シフト交代リクエストの検証
  def validate_exchange_request(params)
    if params[:applicant_id].blank? || params[:shift_date].blank? ||
       params[:start_time].blank? || params[:end_time].blank?
      flash[:error] = "すべての項目を入力してください。"
      redirect_to new_shift_exchange_path
      return { redirect: true }
    end

    if params[:approver_ids].blank?
      flash[:error] = "交代を依頼する相手を選択してください。"
      redirect_to new_shift_exchange_path
      return { redirect: true }
    end

    { redirect: false }
  end
end
