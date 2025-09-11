class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # 認証機能
  before_action :require_login
  
  private
  
  def require_login
    return if session[:authenticated] && session[:employee_id]
    
    redirect_to login_path, alert: 'ログインが必要です'
  end
  
  def current_employee
    @current_employee ||= Employee.find_by(employee_id: session[:employee_id])
  end
  
  def current_employee_id
    session[:employee_id]
  end
  
  def owner?
    current_employee&.owner?
  end
  
  # FreeeApiServiceの共通インスタンス化（DRY原則適用）
  def freee_api_service
    @freee_api_service ||= FreeeApiService.new(
      ENV['FREEE_ACCESS_TOKEN'], 
      ENV['FREEE_COMPANY_ID']
    )
  end
  
  # 共通エラーハンドリング（DRY原則適用）
  def handle_api_error(error, context = '')
    error_message = "#{context}エラー: #{error.message}"
    Rails.logger.error error_message
    Rails.logger.error "Error class: #{error.class}"
    Rails.logger.error "Error backtrace: #{error.backtrace.join('\n')}" if error.backtrace
    error_message
  end
  
  helper_method :current_employee, :current_employee_id, :owner?, :freee_api_service
end
