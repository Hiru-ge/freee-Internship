class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # 認証機能
  before_action :require_login
  before_action :set_header_variables
  
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
  
  def set_header_variables
    if session[:authenticated] && session[:employee_id]
      @employee_name = get_employee_name
      @is_owner = owner?
    else
      @employee_name = nil
      @is_owner = false
    end
  end

  def get_employee_name
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      employee_info = freee_service.get_employee_info(current_employee_id)
      employee_info['display_name'] || 'Unknown'
    rescue => error
      Rails.logger.error "Failed to get employee name: #{error.message}"
      'Unknown'
    end
  end

  helper_method :current_employee, :current_employee_id, :owner?, :freee_api_service
end
