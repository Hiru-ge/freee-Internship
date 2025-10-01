# frozen_string_literal: true

module SessionManagement
  extend ActiveSupport::Concern

  # セッションタイムアウト設定（24時間）
  SESSION_TIMEOUT_HOURS = 24

  private

  def session_expired?
    return false unless session[:created_at]

    session_created_at = Time.at(session[:created_at])
    session_created_at < SESSION_TIMEOUT_HOURS.hours.ago
  end

  def clear_session
    session[:authenticated] = nil
    session[:employee_id] = nil
    session[:created_at] = nil
  end

  def set_header_variables
    if session[:authenticated] && session[:employee_id]
      @employee_name = get_employee_name
      @is_owner = owner?
    else
      @employee_name = nil
      @is_owner = false
    end
  end

  def get_employee_name
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
    employee_info = freee_service.get_employee_info(current_employee_id)
    employee_info["display_name"] || "Unknown"
  rescue StandardError => e
    Rails.logger.error "Failed to get employee name: #{e.message}"
    "Unknown"
  end
end
