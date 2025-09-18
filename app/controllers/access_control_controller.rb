class AccessControlController < ApplicationController
  include ErrorHandler
  
  skip_before_action :require_login, only: [:index, :authenticate_email, :verify_code]
  skip_before_action :set_header_variables, only: [:index, :authenticate_email, :verify_code]
  
  def index
    # 既にメールアドレス認証済みの場合はホームページにリダイレクト
    if session[:email_authenticated]
      redirect_to '/home'
      return
    end
  end

  def authenticate_email
    if request.post?
      email = params[:email]
      
      # 入力値検証
      if email.blank?
        handle_validation_error('email', 'メールアドレスを入力してください')
        render :index
        return
      end
      
      # メールアドレス認証
      result = AccessControlService.send_verification_code(email)
      
      if result[:success]
        session[:pending_email] = email
        handle_success(result[:message])
        redirect_to verify_code_path
      else
        handle_validation_error('email', result[:message])
        render :index
      end
    end
  end

  def verify_code
    # メールアドレス認証が開始されていない場合はトップページにリダイレクト
    unless session[:pending_email]
      redirect_to root_path
      return
    end
    
    if request.post?
      code = params[:code]
      
      # 入力値検証
      if code.blank?
        handle_validation_error('code', '認証コードを入力してください')
        render :verify_code
        return
      end
      
      # 認証コード検証
      result = AccessControlService.verify_code(session[:pending_email], code)
      
      if result[:success]
        # メールアドレス認証成功
        session[:email_authenticated] = true
        session[:authenticated_email] = session[:pending_email]
        session[:email_auth_expires_at] = 24.hours.from_now
        session.delete(:pending_email)
        
        handle_success(result[:message])
        redirect_to '/home'
      else
        handle_validation_error('code', result[:message])
        render :verify_code
      end
    end
  end
end
