# frozen_string_literal: true

module ErrorHandler
  extend ActiveSupport::Concern

  ERROR_MESSAGES = {
    validation: {
      required: "必須項目を入力してください",
      format: "入力形式が正しくありません",
      length: "文字数が制限を超えています",
      invalid: "無効な値が入力されています"
    },
    authorization: {
      login_required: "ログインが必要です",
      permission_denied: "このページにアクセスする権限がありません",
      session_expired: "セッションがタイムアウトしました。再度ログインしてください。",
      invalid_session: "セッションが無効です"
    },
    api: {
      connection_failed: "システムエラーが発生しました。しばらく時間をおいてから再度お試しください。",
      timeout: "システムが混雑しています。しばらく時間をおいてから再度お試しください。",
      server_error: "サーバーエラーが発生しました。システム管理者にお問い合わせください。"
    },
    general: {
      unknown: "予期しないエラーが発生しました。システム管理者にお問い合わせください。",
      maintenance: "システムメンテナンス中です。しばらく時間をおいてから再度アクセスしてください。"
    }
  }.freeze

  def handle_validation_error(field_name, message, redirect_path = nil)
    error_message = message.presence || ERROR_MESSAGES[:validation][:required]

    log_error("Validation error for #{field_name}: #{error_message}")
    set_flash_error(error_message)

    redirect_to redirect_path if redirect_path

    error_message
  end

  def handle_api_error(error, context = "", redirect_path = nil)
    error_message = determine_api_error_message(error)

    log_error("#{context} API error: #{sanitize_error_message(error.message)}")

    set_flash_error(error_message)

    redirect_to redirect_path if redirect_path

    error_message
  end

  def handle_authorization_error(message, redirect_path = nil)
    error_message = message.presence || ERROR_MESSAGES[:authorization][:permission_denied]

    log_error("Authorization error: #{error_message}")
    set_flash_error(error_message)

    redirect_to redirect_path if redirect_path

    error_message
  end

  def handle_unknown_error(redirect_path = nil)
    error_message = ERROR_MESSAGES[:general][:unknown]

    log_error("Unknown error occurred")
    set_flash_error(error_message)

    redirect_to redirect_path if redirect_path

    error_message
  end

  def handle_success(message)
    set_flash_success(message)
    log_info("Success: #{message}")
    message
  end

  def handle_warning(message)
    set_flash_warning(message)
    log_warning("Warning: #{message}")
    message
  end

  def handle_info(message)
    set_flash_info(message)
    log_info("Info: #{message}")
    message
  end

  def handle_standard_error(error)
    case error
    when ActiveRecord::RecordNotFound
      handle_validation_error("record", "指定されたデータが見つかりません")
    when ActiveRecord::RecordInvalid
      handle_validation_error("record", "データの保存に失敗しました")
    when ActionController::ParameterMissing
      handle_validation_error("parameter", "必要なパラメータが不足しています")
    when StandardError
      handle_api_error(error, "General error")
    else
      handle_unknown_error
    end
  end

  private

  def set_flash_error(message)
    flash[:error] = message
  end

  def set_flash_success(message)
    flash[:success] = message
  end

  def set_flash_warning(message)
    flash[:warning] = message
  end

  def set_flash_info(message)
    flash[:info] = message
  end

  def determine_api_error_message(error)
    case error
    when Timeout::Error
      ERROR_MESSAGES[:api][:timeout]
    when SocketError, Errno::ECONNREFUSED
      ERROR_MESSAGES[:api][:connection_failed]
    else
      if error.message.include?("timeout") || error.message.include?("Timeout")
        ERROR_MESSAGES[:api][:timeout]
      elsif error.message.include?("500") || error.message.include?("502") || error.message.include?("503")
        ERROR_MESSAGES[:api][:server_error]
      else
        ERROR_MESSAGES[:api][:connection_failed]
      end
    end
  end

  def sanitize_error_message(message)
    return "" if message.blank?

    sanitized = message.dup

    sanitized.gsub!(/password[=:]\s*\S+/i, "password=***")
    sanitized.gsub!(/token[=:]\s*\S+/i, "token=***")
    sanitized.gsub!(/key[=:]\s*\S+/i, "key=***")
    sanitized.gsub!(/secret[=:]\s*\S+/i, "secret=***")
    sanitized.gsub!(%r{/[^\s]*/}, "/***/")

    sanitized
  end

  def log_error(message)
    Rails.logger.error("[ErrorHandler] #{message}")
  end

  def log_warning(message)
    Rails.logger.warn("[ErrorHandler] #{message}")
  end

  def log_info(message)
    Rails.logger.info("[ErrorHandler] #{message}")
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def setup_error_handling
      rescue_from StandardError, with: :handle_standard_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    end

    private

    def handle_record_not_found(_exception)
      handle_validation_error("record", "指定されたデータが見つかりません")
    end

    def handle_record_invalid(_exception)
      handle_validation_error("record", "データの保存に失敗しました")
    end

    def handle_parameter_missing(_exception)
      handle_validation_error("parameter", "必要なパラメータが不足しています")
    end
  end
end
