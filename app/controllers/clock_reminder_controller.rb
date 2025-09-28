# frozen_string_literal: true

class ClockReminderController < ApplicationController
  # 認証をスキップ（GitHub Actionsからの呼び出し用）
  skip_before_action :require_login
  skip_before_action :require_email_authentication
  skip_before_action :verify_authenticity_token
  before_action :verify_api_key

  def trigger
    # 認証なし（無害な処理のため）
    Rails.logger.info "Clock reminder check triggered via HTTP API"

    begin
      # バックグラウンドでRakeタスクを実行

      # 直接サービスを呼び出し
      ClockService.check_forgotten_clock_ins
      ClockService.check_forgotten_clock_outs

      render json: {
        status: "success",
        message: "Clock reminder check completed",
        timestamp: Time.current
      }
    rescue StandardError => e
      Rails.logger.error "Clock reminder check failed: #{e.message}"
      render json: {
        status: "error",
        message: e.message,
        timestamp: Time.current
      }, status: :internal_server_error
    end
  end

  private

  def verify_api_key
    api_key = request.headers["X-API-Key"]

    unless api_key.present?
      Rails.logger.warn "Clock reminder API called without API key"
      render json: {
        status: "error",
        message: "API key required"
      }, status: :unauthorized
      return
    end

    unless api_key == ENV["CLOCK_REMINDER_API_KEY"]
      Rails.logger.warn "Clock reminder API called with invalid API key: #{api_key}"
      render json: {
        status: "error",
        message: "Invalid API key"
      }, status: :unauthorized
      return
    end

    Rails.logger.info "Clock reminder API called with valid API key"
  end
end
