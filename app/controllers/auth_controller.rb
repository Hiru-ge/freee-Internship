class AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :initial_password, :forgot_password, :verify_password_reset, :reset_password, :send_verification_code, :verify_code]
  before_action :set_employee, only: [:password_change]
  before_action :load_employees, only: [:login, :initial_password, :forgot_password]
  
  def login
    if request.post?
      employee_id = params[:employee_id]
      password = params[:password]
      
      result = AuthService.login(employee_id, password)
      
      if result[:success]
        session[:employee_id] = employee_id
        session[:authenticated] = true
        redirect_to dashboard_path, notice: result[:message]
      else
        if result[:needs_password_setup]
          redirect_to initial_password_auth_path, alert: result[:message]
        else
          flash.now[:alert] = result[:message]
          render :login
        end
      end
    end
  end
  
  def initial_password
    if request.post?
      employee_id = params[:employee_id]
      verification_code = params[:verification_code]
      password = params[:password]
      confirm_password = params[:confirm_password]
      
      if password != confirm_password
        flash.now[:alert] = 'パスワードが一致しません'
        render :initial_password
        return
      end
      
      result = AuthService.set_initial_password_with_verification(employee_id, password, verification_code)
      
      if result[:success]
        redirect_to login_auth_path, notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :initial_password
      end
    end
  end
  
  def send_verification_code
    employee_id = params[:employee_id]
    
    result = AuthService.send_verification_code(employee_id)
    
    respond_to do |format|
      format.json { render json: result }
    end
  end
  
  def verify_code
    employee_id = params[:employee_id]
    code = params[:code]
    
    result = AuthService.verify_code(employee_id, code)
    
    respond_to do |format|
      format.json { render json: result }
    end
  end
  
  def password_change
    if request.post?
      current_password = params[:current_password]
      new_password = params[:new_password]
      confirm_password = params[:confirm_password]
      
      if new_password != confirm_password
        flash.now[:alert] = 'パスワードが一致しません'
        render :password_change
        return
      end
      
      result = AuthService.change_password(@employee.employee_id, current_password, new_password)
      
      if result[:success]
        redirect_to dashboard_path, notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :password_change
      end
    end
  end
  
  def forgot_password
    if request.post?
      employee_id = params[:employee_id]
      
      if employee_id.blank?
        flash.now[:alert] = '従業員を選択してください'
        render :forgot_password
        return
      end
      
      result = AuthService.send_password_reset_code(employee_id)
      
      if result[:success]
        # 認証コード送信成功時は、認証コード入力画面にリダイレクト
        redirect_to verify_password_reset_auth_path(employee_id: employee_id), notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :forgot_password
      end
    end
  end
  
  def verify_password_reset
    @employee_id = params[:employee_id]
    
    if @employee_id.blank?
      redirect_to forgot_password_auth_path, alert: '従業員IDが指定されていません'
      return
    end
    
    if request.post?
      verification_code = params[:verification_code]
      
      if verification_code.blank?
        flash.now[:alert] = '認証コードを入力してください'
        render :verify_password_reset
        return
      end
      
      result = AuthService.verify_password_reset_code(@employee_id, verification_code)
      
      if result[:success]
        # 認証成功時は、パスワード再設定画面にリダイレクト
        redirect_to reset_password_auth_path(employee_id: @employee_id, code: verification_code), notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :verify_password_reset
      end
    end
  end
  
  def reset_password
    @employee_id = params[:employee_id]
    @verification_code = params[:code]
    
    if @employee_id.blank? || @verification_code.blank?
      redirect_to forgot_password_auth_path, alert: 'パラメータが不正です'
      return
    end
    
    if request.post?
      new_password = params[:new_password]
      confirm_password = params[:confirm_password]
      
      if new_password.blank? || confirm_password.blank?
        flash.now[:alert] = 'パスワードを入力してください'
        render :reset_password
        return
      end
      
      if new_password != confirm_password
        flash.now[:alert] = 'パスワードが一致しません'
        render :reset_password
        return
      end
      
      result = AuthService.reset_password_with_verification(@employee_id, new_password, @verification_code)
      
      if result[:success]
        redirect_to login_auth_path, notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :reset_password
      end
    end
  end
  
  def logout
    session[:employee_id] = nil
    session[:authenticated] = nil
    redirect_to login_auth_path, notice: 'ログアウトしました'
  end
  
  private
  
  def set_employee
    @employee = Employee.find_by(employee_id: session[:employee_id])
    redirect_to login_auth_path unless @employee
  end
  
  def load_employees
    # freee APIから従業員一覧を取得（優先）
    begin
      freee_service = FreeeApiService.new(
        Rails.application.config.freee_api['access_token'],
        Rails.application.config.freee_api['company_id']
      )

      freee_employees = freee_service.get_all_employees

      if freee_employees.any?
        @employees = freee_employees.map do |employee|
          {
            employee_id: employee['id'].to_s.rjust(7, '0'),
            display_name: employee['display_name']
          }
        end
        return
      end
    rescue => e
      Rails.logger.error "freee API連携エラー: #{e.message}"
    end

    # フォールバック: DBの従業員
    @employees = Employee.order(:employee_id).map do |employee|
      {
        employee_id: employee.employee_id,
        display_name: employee.owner? ? '店長 太郎' : "従業員 #{employee.employee_id}"
      }
    end
  end
end
