class ApplicationController < ActionController::Base
  include ErrorHandler
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # セッションタイムアウト設定（24時間）
  SESSION_TIMEOUT_HOURS = 24
  
  # セキュリティヘッダー設定
  SECURITY_HEADERS = {
    'X-Frame-Options' => 'DENY',
    'X-Content-Type-Options' => 'nosniff',
    'X-XSS-Protection' => '1; mode=block',
    'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'"
  }.freeze
  
  # 認証機能
  before_action :require_email_authentication
  before_action :require_login
  before_action :set_header_variables
  
  # セキュリティヘッダーの設定
  before_action :set_security_headers
  
  private
  
  def require_email_authentication
    # メールアドレス認証が必要なページかチェック
    return if skip_email_authentication?
    
    # メールアドレス認証済みかチェック
    unless session[:email_authenticated] && !email_auth_expired?
      redirect_to root_path, alert: 'メールアドレス認証が必要です'
      return
    end
  end
  
  def skip_email_authentication?
    # アクセス制限関連のページはスキップ
    controller_name == 'access_control' ||
    # テスト環境ではスキップ
    Rails.env.test?
  end
  
  def email_auth_expired?
    return true unless session[:email_auth_expires_at]
    
    Time.current > Time.parse(session[:email_auth_expires_at].to_s)
  end
  
  def require_login
    return if session[:authenticated] && session[:employee_id] && !session_expired?
    
    if session_expired?
      clear_session
      redirect_to login_path, alert: 'セッションがタイムアウトしました。再度ログインしてください。'
    else
      redirect_to login_path, alert: 'ログインが必要です'
    end
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
  # ErrorHandlerモジュールのhandle_api_errorを使用
  def handle_api_error(error, context = '')
    super(error, context)
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

  def session_expired?
    return false unless session[:created_at]
    
    session_created_at = Time.at(session[:created_at])
    session_created_at < SESSION_TIMEOUT_HOURS.hours.ago
  end

  def clear_session
    session[:authenticated] = nil
    session[:employee_id] = nil
    session[:created_at] = nil
  end

  def set_security_headers
    # セキュリティヘッダーを設定
    SECURITY_HEADERS.each do |header, value|
      response.headers[header] = value
    end
  end

  helper_method :current_employee, :current_employee_id, :owner?, :freee_api_service
end
