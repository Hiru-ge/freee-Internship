Rails.application.routes.draw do
  # 認証関連ルート
  get "auth/login", to: "auth#login", as: :login_auth
  post "auth/login", to: "auth#login"
  get "auth/initial_password", to: "auth#initial_password", as: :initial_password_auth
  post "auth/initial_password", to: "auth#initial_password"
  get "auth/password_change", to: "auth#password_change", as: :password_change_auth
  post "auth/password_change", to: "auth#password_change"
  get "auth/forgot_password", to: "auth#forgot_password", as: :forgot_password_auth
  post "auth/forgot_password", to: "auth#forgot_password"
  get "auth/verify_password_reset", to: "auth#verify_password_reset", as: :verify_password_reset_auth
  post "auth/verify_password_reset", to: "auth#verify_password_reset"
  get "auth/reset_password", to: "auth#reset_password", as: :reset_password_auth
  post "auth/reset_password", to: "auth#reset_password"
  post "auth/logout", to: "auth#logout", as: :logout_auth
  
  # 認証API
  post "auth/send_verification_code", to: "auth#send_verification_code", as: :send_verification_code_auth
  post "auth/verify_code", to: "auth#verify_code", as: :verify_code_auth
  
  # ダッシュボード
  get "dashboard", to: "dashboard#index", as: :dashboard
  post "dashboard/clock_in", to: "dashboard#clock_in", as: :dashboard_clock_in
  post "dashboard/clock_out", to: "dashboard#clock_out", as: :dashboard_clock_out
  get "dashboard/clock_status", to: "dashboard#clock_status", as: :dashboard_clock_status
  get "dashboard/attendance_history", to: "dashboard#attendance_history", as: :dashboard_attendance_history
  
  # シフト管理
  get "shifts", to: "shifts#index"
  get "shifts/data", to: "shifts#data", as: :shifts_data
  get "shifts/employees", to: "shifts#employees", as: :shifts_employees
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # LINE Bot Webhook
  post "webhook/callback" => "webhook#callback"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
