# frozen_string_literal: true

# freee API設定の読み込み
freee_config = Rails.application.config_for(:freee_api)

Rails.application.configure do
  config.freee_api = freee_config
end
