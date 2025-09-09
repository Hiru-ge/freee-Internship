class HomeController < ApplicationController
  skip_before_action :require_login, only: [:index]
  
  def index
    # 認証されている場合はダッシュボードにリダイレクト
    if session[:authenticated] && session[:employee_id]
      redirect_to dashboard_path
    else
      # 認証されていない場合はログインページにリダイレクト
      redirect_to login_auth_path
    end
  end
end
