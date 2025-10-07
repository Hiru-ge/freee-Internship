# frozen_string_literal: true

# ShiftBaseServiceの機能をConcernとして移行
# シフト関連モデルで共通利用する機能を提供
module ShiftBase
  extend ActiveSupport::Concern

  class_methods do
    # === バリデーション機能（ShiftValidatableから統合） ===

    # 日付バリデーション（過去日付不可）
    def validate_shift_date(date_string)
      return { success: false, error: "日付が指定されていません" } if date_string.blank?

      begin
        parsed_date = Date.parse(date_string.to_s)
        if parsed_date < Date.current
          { success: false, error: "過去の日付は指定できません" }
        else
          { success: true, date: parsed_date }
        end
      rescue ArgumentError
        { success: false, error: "無効な日付形式です" }
      end
    end

    # 時間バリデーション
    def validate_shift_time(time_string)
      return { success: false, error: "時間が指定されていません" } if time_string.blank?

      begin
        parsed_time = Time.zone.parse(time_string.to_s)
        { success: true, time: parsed_time }
      rescue ArgumentError
        { success: false, error: "無効な時間形式です" }
      end
    end

    # シフトパラメータの包括的バリデーション
    def validate_shift_params(params)
      errors = []

      # 必須項目チェック
      required_fields = [:employee_id, :shift_date, :start_time, :end_time]
      required_fields.each do |field|
        errors << "#{field}が不足しています" if params[field].blank?
      end

      return { success: false, errors: errors } if errors.any?

      # 日付バリデーション
      date_result = validate_shift_date(params[:shift_date])
      errors << date_result[:error] unless date_result[:success]

      # 時間バリデーション
      start_time_result = validate_shift_time(params[:start_time])
      errors << start_time_result[:error] unless start_time_result[:success]

      end_time_result = validate_shift_time(params[:end_time])
      errors << end_time_result[:error] unless end_time_result[:success]

      # 時間整合性チェック
      if start_time_result[:success] && end_time_result[:success]
        consistency_result = validate_shift_time_consistency(
          start_time_result[:time],
          end_time_result[:time]
        )
        errors << consistency_result[:error] unless consistency_result[:success]
      end

      if errors.any?
        { success: false, errors: errors }
      else
        {
          success: true,
          validated_params: {
            employee_id: params[:employee_id],
            shift_date: date_result[:date],
            start_time: start_time_result[:time],
            end_time: end_time_result[:time]
          }
        }
      end
    end

    # === ShiftBaseServiceから移行した機能 ===
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

    # 従業員IDの配列を検証
    def validate_employee_ids(employee_ids)
      return { success: false, error: "従業員IDが指定されていません" } if employee_ids.blank?

      employee_ids = [employee_ids] unless employee_ids.is_a?(Array)

      invalid_ids = employee_ids.select { |id| id.blank? }
      if invalid_ids.any?
        { success: false, error: "無効な従業員IDが含まれています" }
      else
        { success: true, employee_ids: employee_ids }
      end
    end

    # シフト時間の整合性チェック
    def validate_shift_time_consistency(start_time, end_time)
      start_time_obj = start_time.is_a?(String) ? Time.zone.parse(start_time) : start_time
      end_time_obj = end_time.is_a?(String) ? Time.zone.parse(end_time) : end_time

      if end_time_obj <= start_time_obj
        { success: false, error: "終了時間は開始時間より後である必要があります" }
      else
        { success: true }
      end
    end

    # シフト重複チェック（Shiftモデルへの委譲）
    def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
      Shift.has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    end

    def get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
      Shift.get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
    end

    def check_addition_overlap(employee_id, shift_date, start_time, end_time)
      Shift.check_addition_overlap(employee_id, shift_date, start_time, end_time)
    end

    # エラーハンドリング
    def handle_shift_error(error, context = "")
      case error
      when ActiveRecord::RecordInvalid
        error_message = error.record.errors.full_messages.join(", ")
        Rails.logger.error "#{context}: バリデーションエラー - #{error_message}"
        { success: false, error: "入力データに問題があります: #{error_message}" }
      when ActiveRecord::RecordNotFound
        Rails.logger.error "#{context}: レコードが見つかりません - #{error.message}"
        { success: false, error: "指定されたデータが見つかりません。" }
      when ArgumentError
        Rails.logger.error "#{context}: 引数エラー - #{error.message}"
        { success: false, error: error.message }
      else
        Rails.logger.error "#{context}: 予期しないエラー - #{error.message}"
        { success: false, error: "処理中にエラーが発生しました。" }
      end
    end

    # 通知送信の共通処理
    def send_notification(notification_service, method_name, *args)
      return if Rails.env.test?

      begin
        notification_service.send(method_name, *args)
        Rails.logger.info "通知送信成功: #{method_name}"
      rescue StandardError => e
        Rails.logger.error "通知送信エラー: #{e.message}"
      end
    end

    # 時間解析のヘルパーメソッド
    def parse_shift_date(date_string)
      return Date.parse(date_string) if date_string.is_a?(String)
      date_string
    end

    def parse_shift_time(time_string)
      return Time.zone.parse(time_string) if time_string.is_a?(String)
      time_string
    end

    def format_shift_date(date)
      date.is_a?(String) ? date : date.strftime("%Y-%m-%d")
    end

    def format_shift_time_range(start_time, end_time)
      start_str = start_time.is_a?(String) ? start_time : start_time.strftime("%H:%M")
      end_str = end_time.is_a?(String) ? end_time : end_time.strftime("%H:%M")
      "#{start_str}-#{end_str}"
    end
  end

  # インスタンスメソッド
  def format_shift_time_range(start_time = nil, end_time = nil)
    start_time ||= self.start_time
    end_time ||= self.end_time

    start_str = start_time.is_a?(String) ? start_time : start_time.strftime("%H:%M")
    end_str = end_time.is_a?(String) ? end_time : end_time.strftime("%H:%M")
    "#{start_str}-#{end_str}"
  end

  def format_shift_date(date = nil)
    date ||= shift_date
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
end
