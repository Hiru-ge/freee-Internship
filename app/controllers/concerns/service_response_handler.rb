# frozen_string_literal: true

# ServiceResponseHandler Concern
# サービス層のレスポンスを統一的に処理する共通処理を提供
module ServiceResponseHandler
  extend ActiveSupport::Concern

  # サービスレスポンスの処理（成功時と失敗時のフラッシュメッセージとリダイレクト）
  def handle_service_response(result, success_path:, failure_path:, success_flash_key: :notice, error_flash_key: :error)
    if result[:success]
      flash[success_flash_key] = result[:message]
      redirect_to success_path
    else
      flash[error_flash_key] = result[:message]
      redirect_to failure_path
    end
  end

  # サービスレスポンスの処理（成功時のみリダイレクト、失敗時はrenderオプション付き）
  def handle_service_response_with_render(result, success_path:, render_action:, success_flash_key: :notice, error_flash_key: :error, render_status: :unprocessable_content)
    if result[:success]
      flash[success_flash_key] = result[:message]
      redirect_to success_path
    else
      flash.now[error_flash_key] = result[:message]
      render render_action, status: render_status
    end
  end

  # JSON APIレスポンスの処理
  def handle_json_response(result, success_status: :ok, error_status: :unprocessable_content)
    if result[:success]
      render json: result[:data] || { message: result[:message] }, status: success_status
    else
      render json: { error: result[:message] }, status: error_status
    end
  end

  # 複数タイプのリクエスト処理（approve/reject系）
  def handle_shift_request(request_type:, request_id:, action:, redirect_path:)
    service = get_service_for_request_type(request_type)

    unless service
      flash[:error] = "無効なリクエストタイプです"
      redirect_to redirect_path
      return
    end

    method_name = "#{action}_#{get_method_suffix(request_type)}_request"
    result = service.send(method_name, request_id, current_employee_id)

    if result[:success]
      flash[:success] = result[:message]
    else
      flash[:error] = result[:message]
    end

    redirect_to redirect_path
  rescue StandardError => e
    Rails.logger.error "リクエスト#{action == 'approve' ? '承認' : '拒否'}エラー: #{e.message}"
    flash[:error] = "#{action == 'approve' ? '承認' : '拒否'}処理に失敗しました"
    redirect_to redirect_path
  end

  private

  # リクエストタイプに応じたサービスを取得
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

  # リクエストタイプに応じたメソッド名のサフィックスを取得
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
end
