# frozen_string_literal: true

class ShiftBaseController < ApplicationController
  include ServiceResponseHandler

  # 共通の初期化処理
  def setup_shift_form_params
    @date = params[:date] || Date.current.strftime("%Y-%m-%d")
    @start_time = params[:start] || "09:00"
    @end_time = params[:end] || "18:00"
  end

  # 共通のバリデーション処理（Shiftモデルに移行）
  def validate_shift_form_params(params, required_fields, redirect_path)
    validation_result = Shift.validate_shift_params(params)

    unless validation_result[:success]
      flash[:error] = validation_result[:error]
      redirect_to redirect_path
      return false
    end

    true
  end

  # 共通のサービス呼び出しとレスポンス処理
  def handle_shift_service_response(result, success_path:, failure_path:, success_flash_key: :notice, error_flash_key: :error)
    handle_service_response(
      result,
      success_path: success_path,
      failure_path: failure_path,
      success_flash_key: success_flash_key,
      error_flash_key: error_flash_key
    )
  end

  # 共通のエラーハンドリング
  def handle_shift_error(error, context, redirect_path)
    handle_api_error(error, context, redirect_path)
  end

  # 従業員データの読み込み（共通処理）
  def load_employees_for_view
    @employees = fetch_employees
  end


  private

  # シフト重複チェックの共通処理
  def check_shift_overlap_for_employee(employee_id, shift_date, start_time, end_time)
    display_service = ShiftDisplayService.new
    display_service.check_addition_overlap(
      employee_id,
      Date.parse(shift_date),
      Time.zone.parse(start_time),
      Time.zone.parse(end_time)
    )
  end

  # シフト重複チェックの共通処理（複数従業員）
  def check_shift_overlap_for_employees(employee_ids, shift_date, start_time, end_time)
    display_service = ShiftDisplayService.new
    display_service.get_available_and_overlapping_employees(
      employee_ids,
      Date.parse(shift_date),
      Time.zone.parse(start_time),
      Time.zone.parse(end_time)
    )
  end
end
