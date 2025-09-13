class AuthController < ApplicationController
  include InputValidation
  
  skip_before_action :require_login, only: [:login, :initial_password, :verify_initial_code, :setup_initial_password, :forgot_password, :verify_password_reset, :reset_password, :send_verification_code, :verify_code]
  skip_before_action :set_header_variables, only: [:login, :initial_password, :verify_initial_code, :setup_initial_password, :forgot_password, :verify_password_reset, :reset_password, :send_verification_code, :verify_code]
  before_action :set_employee, only: [:password_change]
  before_action :load_employees, only: [:login, :initial_password, :forgot_password]
  
  def login
    if request.post?
      employee_id = params[:employee_id]
      password = params[:password]
      
      # 入力値検証
      return unless validate_employee_id_format(employee_id, auth_login_path)
      return unless validate_password_length(password, auth_login_path)
      
      # SQLインジェクション対策
      if contains_sql_injection?(employee_id) || contains_sql_injection?(password)
        flash[:alert] = '無効な文字が含まれています'
        render :login
        return
      end
      
      result = AuthService.login(employee_id, password)
      
      if result[:success]
        session[:employee_id] = employee_id
        session[:authenticated] = true
        session[:created_at] = Time.current.to_i
        redirect_to dashboard_path, notice: result[:message]
      else
        if result[:needs_password_setup]
          redirect_to initial_password_path, alert: result[:message]
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
      
      # 認証コード送信処理
      result = AuthService.send_verification_code(employee_id)
      
      if result[:success]
        redirect_to verify_initial_code_path(employee_id: employee_id), notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :initial_password
      end
    end
  end
  
  def verify_initial_code
    @employee_id = params[:employee_id]
    
    if request.post?
      verification_code = params[:verification_code]
      
      result = AuthService.verify_code(@employee_id, verification_code)
      
      if result[:success]
        redirect_to setup_initial_password_path(employee_id: @employee_id, verification_code: verification_code), notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :verify_initial_code
      end
    end
  end
  
  def setup_initial_password
    @employee_id = params[:employee_id]
    @verification_code = params[:verification_code]
    
    if request.post?
      password = params[:password]
      confirm_password = params[:confirm_password]
      
      if password != confirm_password
        flash.now[:alert] = 'パスワードが一致しません'
        render :setup_initial_password
        return
      end
      
      result = AuthService.set_initial_password_with_verification(@employee_id, password, @verification_code)
      
      if result[:success]
        redirect_to login_path, notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :setup_initial_password
      end
    end
  end
  
  def send_verification_code
    employee_id = params[:employee_id]
    
    result = AuthService.send_verification_code(employee_id)
    
    respond_to do |format|
      format.html do
        if result[:success]
          redirect_to verify_initial_code_path(employee_id: employee_id), notice: result[:message]
        else
          flash.now[:alert] = result[:message]
          render :initial_password
        end
      end
      format.json { render json: result }
    end
  end
  
  def verify_code
    employee_id = params[:employee_id]
    code = params[:code]
    
    result = AuthService.verify_code(employee_id, code)
    
    respond_to do |format|
      format.html do
        if result[:success]
          redirect_to setup_initial_password_path(employee_id: employee_id, verification_code: code), notice: result[:message]
        else
          flash.now[:alert] = result[:message]
          render :verify_initial_code
        end
      end
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
        redirect_to verify_password_reset_path(employee_id: employee_id), notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :forgot_password
      end
    end
  end
  
  def verify_password_reset
    @employee_id = params[:employee_id]
    
    if @employee_id.blank?
      redirect_to forgot_password_path, alert: '従業員IDが指定されていません'
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
        redirect_to reset_password_path(employee_id: @employee_id, code: verification_code), notice: result[:message]
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
      redirect_to forgot_password_path, alert: 'パラメータが不正です'
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
        redirect_to login_path, notice: result[:message]
      else
        flash.now[:alert] = result[:message]
        render :reset_password
      end
    end
  end
  
  def logout
    clear_session
    redirect_to login_path, notice: 'ログアウトしました'
  end
  
  private
  
  def contains_sql_injection?(input)
    return false if input.blank?
    
    # SQLインジェクション攻撃のパターンを検出
    sql_patterns = [
      /('|(\\')|(;)|(\-\-)|(\/\*)|(\*\/)|(\|)|(\*)|(%)|(\+)|(\=)|(\<)|(\>)|(\[)|(\])|(\{)|(\})|(\()|(\))|(\^)|(\$)|(\?)|(\!)|(\~)|(\`)|(\@)|(\#)|(\&)|(\\)|(\|)|(\:)|(\;)|(\")|(\')|(\x00)|(\x1a)|(\x0d)|(\x0a)|(\x09)|(\x08)|(\x07)|(\x1b)|(\x0c)|(\x0b)|(\x0e)|(\x0f)|(\x10)|(\x11)|(\x12)|(\x13)|(\x14)|(\x15)|(\x16)|(\x17)|(\x18)|(\x19)|(\x1c)|(\x1d)|(\x1e)|(\x1f))/i,
      /(union|select|insert|update|delete|drop|create|alter|exec|execute|script|javascript|vbscript|onload|onerror|onclick|onmouseover|onfocus|onblur|onchange|onsubmit|onreset|onselect|onkeydown|onkeyup|onkeypress|onmousedown|onmouseup|onmousemove|onmouseout|onmouseover|onmouseenter|onmouseleave|ondblclick|oncontextmenu|onwheel|ontouchstart|ontouchend|ontouchmove|ontouchcancel|ongesturestart|ongesturechange|ongestureend|onabort|onafterprint|onbeforeprint|onbeforeunload|onerror|onhashchange|onload|onmessage|onoffline|ononline|onpagehide|onpageshow|onpopstate|onresize|onstorage|onunload)/i
    ]
    
    sql_patterns.any? { |pattern| input.match?(pattern) }
  end
  
  def set_employee
    @employee = Employee.find_by(employee_id: session[:employee_id])
    redirect_to login_path unless @employee
  end
  
  def load_employees
    # freee APIから従業員一覧を取得（必須）
    begin
      freee_service = FreeeApiService.new(
        Rails.application.config.freee_api['access_token'],
        Rails.application.config.freee_api['company_id']
      )

      freee_employees = freee_service.get_all_employees

      if freee_employees.any?
        @employees = freee_employees.map do |employee|
          {
            employee_id: employee['id'].to_s,
            display_name: employee['display_name']
          }
        end
        return
      end
    rescue => e
      Rails.logger.error "freee API連携エラー: #{e.message}"
    end

    # freeeAPIから取得できない場合は空の配列を返す
    # テストデータやハードコーディングされた従業員データは使用しない
    Rails.logger.warn "freeeAPIから従業員データを取得できませんでした。従業員選択肢は表示されません。"
    @employees = []
  end
end
