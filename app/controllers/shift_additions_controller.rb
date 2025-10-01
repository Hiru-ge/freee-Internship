# frozen_string_literal: true

class ShiftAdditionsController < ApplicationController
  include InputValidation


  # シフト追加リクエスト画面の表示（オーナーのみ）
  def new
    # 権限チェック（共通化されたメソッドを使用）
    return unless check_owner_permission

    @date = params[:date] || Date.current.strftime("%Y-%m-%d")
    @start_time = params[:start] || "09:00"
    @end_time = params[:end] || "18:00"

    # 従業員情報を取得（共通化されたメソッドを使用）
    load_employees_for_view
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

      # 共通化されたレスポンスハンドラーを使用
      handle_service_response(
        result,
        success_path: shifts_path,
        failure_path: new_shift_addition_path,
        success_flash_key: :notice,
        error_flash_key: :error
      )
    rescue StandardError => e
      handle_api_error(e, "シフト追加リクエスト作成", new_shift_addition_path)
    end
  end
end
