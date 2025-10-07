# frozen_string_literal: true

class AuthController < ApplicationController
  include ErrorHandler
  include FreeeApiHelper

  skip_before_action :require_email_authentication,
                     only: %i[login initial_password verify_initial_code setup_initial_password forgot_password verify_password_reset
                              reset_password send_verification_code verify_code access_control home authenticate_email verify_access_code]
  skip_before_action :require_login,
                     only: %i[login initial_password verify_initial_code setup_initial_password forgot_password verify_password_reset
                              reset_password send_verification_code verify_code access_control home authenticate_email verify_access_code]
  skip_before_action :set_header_variables,
                     only: %i[login initial_password verify_initial_code setup_initial_password forgot_password verify_password_reset
                              reset_password send_verification_code verify_code access_control home authenticate_email verify_access_code]
  before_action :set_employee, only: [:password_change]
  before_action :load_employees_for_view, only: %i[initial_password forgot_password]

  def login
    if request.get?
      begin
        @employees = freee_api_service.get_employees
        Rails.logger.info "Employees loaded: #{@employees.inspect}"
      rescue => e
        Rails.logger.error "Error loading employees: #{e.message}"
        @employees = []
      end
      render :login
      return
    end

    employee_id = params[:employee_id]
    password = params[:password]

    # バリデーションはEmployeeモデルで実行

    begin
      employee = Employee.authenticate_login(employee_id, password)
      session[:employee_id] = employee_id
      session[:authenticated] = true
      session[:created_at] = Time.current.to_i
      handle_success("ログインしました")
      redirect_to dashboard_path
    rescue Employee::AuthenticationError => e
      if e.message.include?("パスワードが設定されていません")
        handle_warning(e.message)
        redirect_to password_initial_path
      else
        handle_validation_error("login", e.message)
        render :login
      end
    rescue Employee::ValidationError => e
      handle_validation_error("login", e.message)
      render :login
    end
  end

  def initial_password
    return unless request.post?

    employee_id = params[:employee_id]

    begin
      result = Employee.send_verification_code(employee_id)
      redirect_to verify_initial_code_path(employee_id: employee_id), notice: result[:message]
    rescue Employee::ValidationError => e
      flash.now[:alert] = e.message
      render :initial_password
    end
  end

  def verify_initial_code
    @employee_id = params[:employee_id]

    return unless request.post?

    verification_code = params[:verification_code]

    begin
      result = Employee.verify_code(@employee_id, verification_code)
      redirect_to setup_initial_password_path(employee_id: @employee_id, verification_code: verification_code),
                  notice: result[:message]
    rescue Employee::ValidationError, Employee::AuthenticationError => e
      flash.now[:alert] = e.message
      render :verify_initial_code
    end
  end

  def setup_initial_password
    @employee_id = params[:employee_id]
    @verification_code = params[:verification_code]

    return unless request.post?

    password = params[:password]
    confirm_password = params[:confirm_password]

    begin
      # 認証コード検証
      Employee.verify_code(@employee_id, @verification_code)

      employee = Employee.setup_initial_password(@employee_id, password, confirm_password)
      redirect_to login_path, notice: "パスワードが設定されました"
    rescue Employee::ValidationError, Employee::AuthenticationError => e
      flash.now[:alert] = e.message
      render :setup_initial_password
    end
  end

  def send_verification_code
    employee_id = params[:employee_id]

    begin
      result = Employee.send_verification_code(employee_id)
      respond_to do |format|
        format.html do
          redirect_to verify_initial_code_path(employee_id: employee_id), notice: result[:message]
        end
        format.json { render json: result }
      end
    rescue Employee::ValidationError => e
      respond_to do |format|
        format.html do
          flash.now[:alert] = e.message
          render :initial_password
        end
        format.json { render json: { success: false, message: e.message } }
      end
    end
  end

  def verify_code
    employee_id = params[:employee_id]
    code = params[:code]

    begin
      result = Employee.verify_code(employee_id, code)
      respond_to do |format|
        format.html do
          redirect_to setup_initial_password_path(employee_id: employee_id, verification_code: code),
                      notice: result[:message]
        end
        format.json { render json: result }
      end
    rescue Employee::ValidationError, Employee::AuthenticationError => e
      respond_to do |format|
        format.html do
          flash.now[:alert] = e.message
          render :verify_initial_code
        end
        format.json { render json: { success: false, message: e.message } }
      end
    end
  end

  def password_change
    return unless request.post?

    current_password = params[:current_password]
    new_password = params[:new_password]
    confirm_password = params[:confirm_password]

    begin
      @employee.change_password!(current_password, new_password, confirm_password)
      redirect_to dashboard_path, notice: "パスワードが変更されました"
    rescue Employee::ValidationError, Employee::AuthenticationError => e
      flash.now[:alert] = e.message
      render :password_change
    end
  end

  def forgot_password
    return unless request.post?

    employee_id = params[:employee_id]

    if employee_id.blank?
      flash.now[:alert] = "従業員を選択してください"
      render :forgot_password
      return
    end

    begin
      result = Employee.send_password_reset_code(employee_id)
      # 認証コード送信成功時は、認証コード入力画面にリダイレクト
      redirect_to verify_reset_path(employee_id: employee_id), notice: result[:message]
    rescue Employee::ValidationError => e
      flash.now[:alert] = e.message
      render :forgot_password
    end
  end

  def verify_password_reset
    @employee_id = params[:employee_id]

    if @employee_id.blank?
      redirect_to password_forgot_path, alert: "従業員IDが指定されていません"
      return
    end

    return unless request.post?

    verification_code = params[:verification_code]

    if verification_code.blank?
      flash.now[:alert] = "認証コードを入力してください"
      render :verify_password_reset
      return
    end

    begin
      result = Employee.verify_password_reset_code(@employee_id, verification_code)
      # 認証成功時は、パスワード再設定画面にリダイレクト
      redirect_to password_reset_path(employee_id: @employee_id, code: verification_code), notice: result[:message]
    rescue Employee::ValidationError, Employee::AuthenticationError => e
      flash.now[:alert] = e.message
      render :verify_password_reset
    end
  end

  def reset_password
    @employee_id = params[:employee_id]
    @verification_code = params[:code]

    if @employee_id.blank? || @verification_code.blank?
      redirect_to password_forgot_path, alert: "パラメータが不正です"
      return
    end

    return unless request.post?

    new_password = params[:new_password]
    confirm_password = params[:confirm_password]

    if new_password.blank? || confirm_password.blank?
      flash.now[:alert] = "パスワードを入力してください"
      render :reset_password
      return
    end

    if new_password != confirm_password
      flash.now[:alert] = "パスワードが一致しません"
      render :reset_password
      return
    end

    begin
      result = Employee.reset_password_with_verification(@employee_id, new_password, @verification_code)
      redirect_to login_path, notice: result[:message]
    rescue Employee::ValidationError, Employee::AuthenticationError => e
      flash.now[:alert] = e.message
      render :reset_password
    end
  end

  def logout
    clear_session
    redirect_to login_path, notice: "ログアウトしました"
  end

  # アクセス制御関連の機能
  def access_control
    # 既にメールアドレス認証済みの場合はホームページにリダイレクト
    if session[:email_authenticated]
      redirect_to home_path
      return
    end

    # メールアドレス認証ページを表示
    render :access_control
  end

  def home
    # メールアドレス認証済みでログイン済みの場合はダッシュボードにリダイレクト
    if session[:authenticated] && session[:employee_id]
      redirect_to dashboard_path
    elsif session[:email_authenticated]
      # メールアドレス認証済みだがログインしていない場合はログインページにリダイレクト
      redirect_to login_path
    else
      # メールアドレス認証もされていない場合はトップページにリダイレクト
      redirect_to root_path
    end
  end

  def authenticate_email
    if request.post?
      email = params[:email]

      # 入力値検証
      if email.blank?
        handle_validation_error("email", "メールアドレスを入力してください")
        render :access_control
        return
      end

      begin
        # メールアドレス認証
        result = Employee.send_access_control_verification_code(email)
        session[:pending_email] = email
        session[:access_verification_code] = result[:code]  # 認証コードをセッションに保存
        handle_success(result[:message])
        redirect_to verify_access_path
      rescue Employee::ValidationError => e
        if e.message.include?("freee.co.jp")
          # freee.co.jpドメインの場合は成功として扱う（テスト環境）
          handle_success("テスト環境のため、メール送信をスキップしました。")
          render :access_control
        else
          # 許可されていないメールアドレスやその他のエラー
          handle_validation_error("email", e.message)
          render :access_control
        end
      end
    else
      # GETリクエストの場合はアクセス制御ページを表示
      render :access_control
    end
  end

  def verify_access_code
    # メールアドレス認証が開始されていない場合はトップページにリダイレクト
    unless session[:pending_email]
      redirect_to root_path
      return
    end

    if request.post?
      code = params[:code]

      # 入力値検証
      if code.blank?
        handle_validation_error("code", "認証コードを入力してください")
        render :verify_access_code
        return
      end

      begin
        # 認証コード検証
        result = Employee.verify_access_control_code(session[:pending_email], code, session[:access_verification_code])

        # メールアドレス認証成功
        session[:email_authenticated] = true
        session[:authenticated_email] = session[:pending_email]
        session[:email_auth_expires_at] = AppConstants::EMAIL_AUTH_TIMEOUT_HOURS.hours.from_now
        session.delete(:pending_email)
        session.delete(:access_verification_code)

        handle_success(result[:message])
        redirect_to home_path
      rescue Employee::ValidationError, Employee::AuthenticationError => e
        handle_validation_error("code", e.message)
        render :verify_access_code
      end
    else
      # GETリクエストの場合は認証コード入力ページを表示
      render :verify_access_code
    end
  end

  private

  def set_employee
    @employee = Employee.find_by(employee_id: session[:employee_id])
    redirect_to login_path unless @employee
  end

end
