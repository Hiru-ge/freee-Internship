# frozen_string_literal: true

module ServiceResponseHandler
  extend ActiveSupport::Concern

  def handle_service_response(result, success_path:, failure_path:, success_flash_key: :notice, error_flash_key: :error)
    if result[:success]
      flash[success_flash_key] = result[:message]
      redirect_to success_path
    else
      flash[error_flash_key] = result[:message]
      redirect_to failure_path
    end
  end

  def handle_service_response_with_render(result, success_path:, render_action:, success_flash_key: :notice, error_flash_key: :error, render_status: :unprocessable_content)
    if result[:success]
      flash[success_flash_key] = result[:message]
      redirect_to success_path
    else
      flash.now[error_flash_key] = result[:message]
      render render_action, status: render_status
    end
  end

  def handle_json_response(result, success_status: :ok, error_status: :unprocessable_content)
    if result[:success]
      render json: result[:data] || { message: result[:message] }, status: success_status
    else
      render json: { error: result[:message] }, status: error_status
    end
  end

  def handle_shift_request(request_type:, request_id:, action:, redirect_path:)
    service = get_service_for_request_type(request_type)

    unless service
      flash[:error] = "無効なリクエストタイプです"
      redirect_to redirect_path
      return
    end

    result = process_shift_request(service, request_type, request_id, action)
    handle_shift_request_result(result, action, redirect_path)
  rescue StandardError => e
    handle_shift_request_error(e, action, redirect_path)
  end

  private

  def get_service_for_request_type(request_type)
    case request_type
    when "exchange"
      ShiftExchangeService.new
    when "addition"
      ShiftAdditionService.new
    when "deletion"
      ShiftDeletionService.new
    end
  end

  def process_shift_request(service, request_type, request_id, action)
    method_name = "#{action}_#{get_method_suffix(request_type)}_request"
    service.send(method_name, request_id, current_employee_id)
  end

  def get_method_suffix(request_type)
    case request_type
    when "exchange"
      "exchange"
    when "addition"
      "addition"
    when "deletion"
      "deletion"
    end
  end

  def handle_shift_request_result(result, action, redirect_path)
    if result[:success]
      flash[:success] = result[:message]
    else
      flash[:error] = result[:message]
    end

    redirect_to redirect_path
  end

  def handle_shift_request_error(error, action, redirect_path)
    Rails.logger.error "リクエスト#{action == 'approve' ? '承認' : '拒否'}エラー: #{error.message}"
    flash[:error] = "#{action == 'approve' ? '承認' : '拒否'}処理に失敗しました"
    redirect_to redirect_path
  end
end
