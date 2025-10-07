# frozen_string_literal: true

class BaseService
  def initialize
    # 共通の初期化処理
  end

  # 共通のバリデーション処理
  def validate_required_params(params, required_fields)
    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      return error_response("必須項目が不足しています: #{missing_fields.join(', ')}")
    end

    success_response("バリデーション成功")
  end

  # 共通のレスポンス生成
  def success_response(message, data = nil)
    response = { success: true, message: message }
    response[:data] = data if data
    response
  end

  def error_response(message)
    { success: false, message: message }
  end

  # 従業員名取得の共通処理
  def get_employee_display_name(employee_id)
    employee = Employee.find_by(employee_id: employee_id)
    employee&.display_name || "ID: #{employee_id}"
  end

  # FreeeApiServiceの共通初期化
  def freee_api_service
    @freee_api_service ||= FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

  # 日付バリデーションの共通処理
  def validate_date_format(date_string, allow_past: false)
    return error_response("日付が入力されていません。") if date_string.blank?

    begin
      date = Date.parse(date_string)

      unless allow_past
        if date < Date.current
          return error_response("過去の日付は指定できません。")
        end
      end

      { success: true, date: date }
    rescue ArgumentError
      error_response("無効な日付形式です。")
    end
  end

  # 時間バリデーションの共通処理
  def validate_time_format(time_string)
    return error_response("時間が入力されていません。") if time_string.blank?

    begin
      Time.zone.parse(time_string)
      { success: true }
    rescue ArgumentError
      error_response("無効な時間形式です。")
    end
  end

  # 数値バリデーションの共通処理
  def validate_numeric(value, min: nil, max: nil, field_name: "値")
    return error_response("#{field_name}が入力されていません。") if value.blank?

    begin
      number = value.to_i

      if min && number < min
        return error_response("#{field_name}は#{min}以上である必要があります。")
      end

      if max && number > max
        return error_response("#{field_name}は#{max}以下である必要があります。")
      end

      { success: true, value: number }
    rescue ArgumentError
      error_response("#{field_name}は有効な数値である必要があります。")
    end
  end

  # 配列バリデーションの共通処理
  def validate_array_not_empty(array, field_name: "配列")
    if array.blank? || array.empty?
      return error_response("#{field_name}は空にできません。")
    end

    success_response("#{field_name}のバリデーション成功")
  end

  # ログ出力の共通処理
  def log_info(message)
    Rails.logger.info "[#{self.class.name}] #{message}"
  end

  def log_error(message)
    Rails.logger.error "[#{self.class.name}] #{message}"
  end

  def log_warn(message)
    Rails.logger.warn "[#{self.class.name}] #{message}"
  end

  def log_debug(message)
    Rails.logger.debug "[#{self.class.name}] #{message}"
  end

  # エラーハンドリングの共通処理
  def handle_service_error(error, context = "")
    error_message = context.present? ? "#{context}: #{error.message}" : error.message
    log_error(error_message)
    log_error("Error backtrace: #{error.backtrace.join('\n')}")
    error_response("処理中にエラーが発生しました。")
  end

  # トランザクション処理の共通メソッド
  def with_transaction(&block)
    ActiveRecord::Base.transaction do
      yield
    end
  rescue StandardError => e
    handle_service_error(e, "トランザクション処理中")
  end

  # リクエストID生成の共通処理
  def generate_request_id(prefix = "REQ")
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end
end
