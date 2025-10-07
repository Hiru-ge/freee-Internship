# frozen_string_literal: true

class ShiftBaseService < BaseService
  # シフト関連の共通バリデーション
  def validate_shift_date(date_string)
    validate_date_format(date_string, allow_past: false)
  end

  def validate_shift_time(time_string)
    validate_time_format(time_string)
  end

  def validate_shift_params(params, required_fields)
    # 基本バリデーション
    basic_validation = validate_required_params(params, required_fields)
    return basic_validation unless basic_validation[:success]

    # 日付バリデーション
    if params[:shift_date].present?
      date_validation = validate_shift_date(params[:shift_date])
      return date_validation unless date_validation[:success]
    end

    # 時間バリデーション
    if params[:start_time].present?
      start_time_validation = validate_shift_time(params[:start_time])
      return start_time_validation unless start_time_validation[:success]
    end

    if params[:end_time].present?
      end_time_validation = validate_shift_time(params[:end_time])
      return end_time_validation unless end_time_validation[:success]
    end

    success_response("シフトパラメータのバリデーション成功")
  end

  # シフト重複チェックサービスへの委譲
  def shift_validation_service
    @shift_validation_service ||= ShiftValidationService.new
  end

  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    shift_validation_service.has_shift_overlap?(employee_id, shift_date, start_time, end_time)
  end

  def get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
    shift_validation_service.get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
  end

  def check_addition_overlap(employee_id, shift_date, start_time, end_time)
    shift_validation_service.check_addition_overlap(employee_id, shift_date, start_time, end_time)
  end

  # シフト関連の共通処理
  def format_shift_time_range(start_time, end_time)
    start_str = start_time.is_a?(String) ? start_time : start_time.strftime("%H:%M")
    end_str = end_time.is_a?(String) ? end_time : end_time.strftime("%H:%M")
    "#{start_str}-#{end_str}"
  end

  def format_shift_date(date)
    date.is_a?(String) ? date : date.strftime("%Y-%m-%d")
  end

  def parse_shift_date(date_string)
    return Date.parse(date_string) if date_string.is_a?(String)
    date_string
  end

  def parse_shift_time(time_string)
    return Time.zone.parse(time_string) if time_string.is_a?(String)
    time_string
  end

  # 従業員IDの配列を検証
  def validate_employee_ids(employee_ids)
    return error_response("従業員IDが指定されていません。") if employee_ids.blank?

    employee_ids = [employee_ids] unless employee_ids.is_a?(Array)

    invalid_ids = employee_ids.select { |id| id.blank? }
    if invalid_ids.any?
      return error_response("無効な従業員IDが含まれています。")
    end

    success_response("従業員IDのバリデーション成功", employee_ids)
  end

  # シフト時間の整合性チェック
  def validate_shift_time_consistency(start_time, end_time)
    start_time_obj = parse_shift_time(start_time)
    end_time_obj = parse_shift_time(end_time)

    if end_time_obj <= start_time_obj
      return error_response("終了時間は開始時間より後にしてください。")
    end

    success_response("時間の整合性チェック成功")
  end

  # シフト作成用のパラメータ準備
  def prepare_shift_creation_params(params)
    {
      employee_id: params[:employee_id],
      shift_date: parse_shift_date(params[:shift_date]),
      start_time: parse_shift_time(params[:start_time]),
      end_time: parse_shift_time(params[:end_time])
    }
  end

  # シフトリクエスト用のパラメータ準備
  def prepare_shift_request_params(params)
    {
      requester_id: params[:requester_id],
      shift_date: format_shift_date(params[:shift_date]),
      start_time: format_shift_time_range(params[:start_time], params[:start_time]),
      end_time: format_shift_time_range(params[:end_time], params[:end_time])
    }
  end

  # 通知送信の共通処理
  def send_notification(notification_service, method_name, *args)
    return if Rails.env.test?

    begin
      notification_service.send(method_name, *args)
      log_info("通知送信成功: #{method_name}")
    rescue StandardError => e
      log_error("通知送信エラー: #{e.message}")
    end
  end

  # シフト関連のエラーハンドリング
  def handle_shift_error(error, context = "")
    case error
    when ActiveRecord::RecordInvalid
      error_message = error.record.errors.full_messages.join(", ")
      log_error("#{context}: バリデーションエラー - #{error_message}")
      error_response("入力データに問題があります: #{error_message}")
    when ActiveRecord::RecordNotFound
      log_error("#{context}: レコードが見つかりません - #{error.message}")
      error_response("指定されたデータが見つかりません。")
    else
      handle_service_error(error, context)
    end
  end
end
