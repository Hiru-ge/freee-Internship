# frozen_string_literal: true

class ShiftAdditionsController < ApplicationController
  include InputValidation
  include RequestIdGenerator


  # シフト追加リクエスト画面の表示（オーナーのみ）
  def new
    unless owner?
      flash[:error] = "このページにアクセスする権限がありません"
      redirect_to dashboard_path and return
    end

    @date = params[:date] || Date.current.strftime("%Y-%m-%d")
    @start_time = params[:start] || "09:00"
    @end_time = params[:end] || "18:00"

    begin
      @employees = freee_api_service.get_employees
    rescue StandardError => e
      handle_api_error(e, "従業員一覧取得")
      @employees = []
    end
  end

  # シフト追加リクエストの作成
  def create
    return unless check_shift_addition_authorization

    begin
      # 必須項目チェック（従業員ID含む）
      return unless validate_required_params(params, %i[employee_id shift_date start_time end_time],
                                             new_shift_addition_path)

      # シフト関連の共通バリデーション
      return unless validate_shift_params(params, new_shift_addition_path)

      # 重複チェック
      display_service = ShiftDisplayService.new
      overlapping_employee = display_service.check_addition_overlap(
        params[:employee_id],
        Date.parse(params[:shift_date]),
        Time.zone.parse(params[:start_time]),
        Time.zone.parse(params[:end_time])
      )

      if overlapping_employee
        flash[:error] = "#{overlapping_employee}は指定された時間にシフトが入っています。"
        redirect_to new_shift_addition_path and return
      end

      # 共通サービスを使用してシフト追加リクエストを作成
      request_params = {
        requester_id: current_employee_id,
        shift_date: params[:shift_date],
        start_time: params[:start_time],
        end_time: params[:end_time],
        target_employee_ids: [params[:employee_id]]
      }

      shift_addition_service = ShiftAdditionService.new
      result = shift_addition_service.create_addition_request(request_params)

      if result[:success]
        flash[:notice] = result[:message]
        redirect_to shifts_path
      else
        flash[:error] = result[:message]
        redirect_to new_shift_addition_path
      end
    rescue StandardError => e
      handle_api_error(e, "シフト追加リクエスト作成")
      flash[:error] = "リクエストの送信に失敗しました。しばらく時間をおいてから再度お試しください。"
      redirect_to new_shift_addition_path
    end
  end
end
