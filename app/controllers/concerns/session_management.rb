# frozen_string_literal: true

module SessionManagement
  extend ActiveSupport::Concern

  # セッションタイムアウト設定
  SESSION_TIMEOUT_HOURS = AppConstants::SESSION_TIMEOUT_HOURS

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
    employee_info = freee_api_service.get_employee_info(current_employee_id)
    employee_info["display_name"] || "Unknown"
  rescue StandardError => e
    Rails.logger.error "Failed to get employee name: #{e.message}"
    "Unknown"
  end
end
