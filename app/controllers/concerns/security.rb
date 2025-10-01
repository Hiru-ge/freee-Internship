# frozen_string_literal: true

module Security
  extend ActiveSupport::Concern

  # セキュリティヘッダー設定
  SECURITY_HEADERS = {
    "X-Frame-Options" => "DENY",
    "X-Content-Type-Options" => "nosniff",
    "X-XSS-Protection" => "1; mode=block",
    "Content-Security-Policy" => "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'"
  }.freeze

  included do
    before_action :set_security_headers
  end

  private

  def set_security_headers
    # セキュリティヘッダーを設定
    SECURITY_HEADERS.each do |header, value|
      response.headers[header] = value
    end
  end

  # FreeeApiServiceの共通インスタンス化（DRY原則適用）
  def freee_api_service
    @freee_api_service ||= FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

end
