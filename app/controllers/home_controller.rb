# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :require_login, only: [:index]

  def index
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
end
