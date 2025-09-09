class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # 認証機能
  before_action :authenticate_user!
  
  private
  
  def authenticate_user!
    return if session[:authenticated] && session[:employee_id]
    
    redirect_to login_auth_path, alert: 'ログインが必要です'
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
  
  helper_method :current_employee, :current_employee_id, :owner?
end
