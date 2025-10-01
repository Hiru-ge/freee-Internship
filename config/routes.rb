# frozen_string_literal: true

Rails.application.routes.draw do
  # アクセス制限関連ルート
  root "auth#access_control"
  post "auth/authenticate_email", as: :authenticate_email
  get "auth/verify_access_code", as: :verify_access_code_get
  post "auth/verify_access_code", as: :verify_access_code
  get "wages/index"
  get "wages/show"
  # 認証関連ルート
  get "auth/login", to: "auth#login", as: :login
  post "auth/login", to: "auth#login"
  get "auth/initial_password", to: "auth#initial_password", as: :initial_password
  post "auth/initial_password", to: "auth#initial_password"
  get "auth/verify_initial_code", to: "auth#verify_initial_code", as: :verify_initial_code
  post "auth/verify_initial_code", to: "auth#verify_initial_code"
  get "auth/setup_initial_password", to: "auth#setup_initial_password", as: :setup_initial_password
  post "auth/setup_initial_password", to: "auth#setup_initial_password"
  get "auth/password_change", to: "auth#password_change", as: :password_change
  post "auth/password_change", to: "auth#password_change"
  get "auth/forgot_password", to: "auth#forgot_password", as: :forgot_password
  post "auth/forgot_password", to: "auth#forgot_password"
  get "auth/verify_password_reset", to: "auth#verify_password_reset", as: :verify_password_reset
  post "auth/verify_password_reset", to: "auth#verify_password_reset"
  get "auth/reset_password", to: "auth#reset_password", as: :reset_password
  post "auth/reset_password", to: "auth#reset_password"
  post "auth/logout", to: "auth#logout", as: :logout

  # 認証API
  post "auth/send_verification_code", to: "auth#send_verification_code", as: :send_verification_code
  post "auth/verify_code", to: "auth#verify_code", as: :verify_auth_code

  # 勤怠打刻（ダッシュボード機能も含む）
  get "dashboard", to: "attendance#index", as: :dashboard
  post "attendance/clock_in", to: "attendance#clock_in", as: :clock_in
  post "attendance/clock_out", to: "attendance#clock_out", as: :clock_out
  get "attendance/clock_status", to: "attendance#clock_status", as: :clock_status
  get "attendance/attendance_history", to: "attendance#attendance_history", as: :attendance_history

  # シフト表示
  get "shifts", to: "shift_display#index"
  get "shifts/data", to: "shift_display#data", as: :shifts_data

  # シフト交代
  get "shift_exchanges/new", to: "shift_exchanges#new", as: :new_shift_exchange
  post "shift_exchanges", to: "shift_exchanges#create", as: :shift_exchanges

  # シフト追加
  get "shift_additions/new", to: "shift_additions#new", as: :new_shift_addition
  post "shift_additions", to: "shift_additions#create", as: :shift_additions

  # シフト削除（欠勤申請）
  get "shift_deletions/new", to: "shift_deletions#new", as: :new_shift_deletion
  post "shift_deletions", to: "shift_deletions#create", as: :shift_deletions

  # シフト承認
  get "shift_approvals", to: "shift_approvals#index", as: :shift_approvals
  post "shift_approvals/approve", to: "shift_approvals#approve", as: :approve_shift_approval
  post "shift_approvals/reject", to: "shift_approvals#reject", as: :reject_shift_approval
  get "shift_approvals/pending_requests_for_user", to: "shift_approvals#pending_requests_for_user"
  get "shift_approvals/pending_exchange_requests", to: "shift_approvals#pending_exchange_requests"
  get "shift_approvals/pending_addition_requests", to: "shift_approvals#pending_addition_requests"

  # 給与管理
  resources :wages, only: [:index] do
    collection do
      get :wage_info
      get :all_wages
      get :employees
    end
  end


  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # LINE Bot Webhook
  post "webhook/callback" => "webhook#callback"

  # Clock Reminder API (GitHub Actions用)
  post "clock_reminder/trigger", to: "clock_reminder#trigger"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 既存のホームページ（アクセス制限後）
  get "home", to: "auth#home", as: :home
end
