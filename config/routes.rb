# frozen_string_literal: true

Rails.application.routes.draw do
  # 認証・ログイン
  root "auth#access_control"

  get "login", to: "auth#login"
  post "login", to: "auth#login"
  post "logout", to: "auth#logout"

  get "password/initial", to: "auth#initial_password"
  post "password/initial", to: "auth#initial_password"
  get "password/forgot", to: "auth#forgot_password"
  post "password/forgot", to: "auth#forgot_password"
  get "password/reset", to: "auth#reset_password"
  post "password/reset", to: "auth#reset_password"
  get "password/change", to: "auth#password_change"
  post "password/change", to: "auth#password_change"

  get "verify/initial", to: "auth#verify_initial_code"
  post "verify/initial", to: "auth#verify_initial_code"
  get "verify/reset", to: "auth#verify_password_reset"
  post "verify/reset", to: "auth#verify_password_reset"
  get "verify/access", to: "auth#verify_access_code"
  post "verify/access", to: "auth#verify_access_code"

  post "auth/email", to: "auth#authenticate_email"
  post "auth/code/send", to: "auth#send_verification_code"
  post "auth/code/verify", to: "auth#verify_code"

  # メイン機能
  get "dashboard", to: "attendance#index"
  get "shifts", to: "shift_display#index"
  get "wages", to: "wages#index"
  get "home", to: "auth#home"

  # 勤怠管理
  post "attendance/clock_in", to: "attendance#clock_in"
  post "attendance/clock_out", to: "attendance#clock_out"
  get "attendance/status", to: "attendance#clock_status"
  get "attendance/history", to: "attendance#attendance_history"

  # シフト管理
  get "shift/exchange/new", to: "shift_exchanges#new"
  get "shift/addition/new", to: "shift_additions#new"
  get "shift/deletion/new", to: "shift_deletions#new"

  post "shift/exchange", to: "shift_exchanges#create"
  post "shift/addition", to: "shift_additions#create"
  post "shift/deletion", to: "shift_deletions#create"

  get "shift/approvals", to: "shift_approvals#index"
  post "shift/approve", to: "shift_approvals#approve"
  post "shift/reject", to: "shift_approvals#reject"

  get "shift/approvals/pending", to: "shift_approvals#pending_requests_for_user"
  get "shift/approvals/exchange", to: "shift_approvals#pending_exchange_requests"
  get "shift/approvals/addition", to: "shift_approvals#pending_addition_requests"

  # 給与管理
  get "wages/employees", to: "wages#employees"

  # システム・API
  get "health", to: "rails/health#show"
  post "webhook/callback", to: "webhook#callback"
  post "clock_reminder/trigger", to: "clock_reminder#trigger"
end
