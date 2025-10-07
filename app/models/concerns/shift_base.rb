# frozen_string_literal: true

module ShiftBase
  extend ActiveSupport::Concern

  class ValidationError < StandardError; end
  class AuthorizationError < StandardError; end

  included do
    validates :shift_date, presence: true, if: :has_shift_date?
    validates :start_time, presence: true, if: :has_time_fields?
    validates :end_time, presence: true, if: :has_time_fields?
    validate :end_time_after_start_time_validation, if: :has_time_fields?
    validate :future_date_only_validation, if: :shift_date_present?

    validates :request_id, presence: true, uniqueness: true, if: :has_request_id?
    validates :status, presence: true, inclusion: { in: %w[pending approved rejected cancelled] }, if: :has_status?
  end

  class_methods do
    def get_employee_display_name(employee_id)
      employee = Employee.find_by(employee_id: employee_id)
      return employee.display_name if employee

      "ID: #{employee_id}"
    rescue StandardError => e
      Rails.logger.error "従業員名取得エラー: #{e.message}"
      "ID: #{employee_id}"
    end

    def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
      check_shift_overlap(employee_id, shift_date, start_time, end_time)
    end

    def check_shift_overlap(employee_id, shift_date, start_time, end_time)
      existing_shifts = Shift.where(employee_id: employee_id, shift_date: shift_date)
      existing_shifts.any? do |shift|
        existing_times = convert_shift_times_to_objects(shift)
        new_times = convert_new_shift_times_to_objects(shift.shift_date, start_time, end_time)
        new_times[:start] < existing_times[:end] && new_times[:end] > existing_times[:start]
      end
    end

    def get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
      available_ids = []
      overlapping_names = []

      employee_ids.each do |employee_id|
        if check_shift_overlap(employee_id, shift_date, start_time, end_time)
          overlapping_names << get_employee_display_name(employee_id)
        else
          available_ids << employee_id
        end
      end

      { available_ids: available_ids, overlapping_names: overlapping_names }
    end

    def check_addition_overlap(employee_id, shift_date, start_time, end_time)
      return nil unless check_shift_overlap(employee_id, shift_date, start_time, end_time)
      get_employee_display_name(employee_id)
    end

    def shift_overlaps?(existing_shift, new_start_time, new_end_time)
      existing_times = convert_shift_times_to_objects(existing_shift)
      new_times = convert_new_shift_times_to_objects(existing_shift.shift_date, new_start_time, new_end_time)

      new_times[:start] < existing_times[:end] && new_times[:end] > existing_times[:start]
    end

    def convert_shift_times_to_objects(existing_shift)
      base_date = existing_shift.shift_date
      {
        start: Time.zone.parse("#{base_date} #{existing_shift.start_time.strftime('%H:%M')}"),
        end: Time.zone.parse("#{base_date} #{existing_shift.end_time.strftime('%H:%M')}")
      }
    end

    def convert_new_shift_times_to_objects(base_date, new_start_time, new_end_time)
      {
        start: Time.zone.parse("#{base_date} #{format_time_to_string(new_start_time)}"),
        end: Time.zone.parse("#{base_date} #{format_time_to_string(new_end_time)}")
      }
    end

    def format_time_to_string(time)
      time.is_a?(String) ? time : time.strftime("%H:%M")
    end

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

    def validate_required_fields(*fields)
      missing_fields = fields.select(&:blank?)
      raise ValidationError, "必須項目が不足しています" if missing_fields.any?
    end

    def parse_date_and_times(shift_date, start_time, end_time)
      {
        date: Date.parse(shift_date.to_s),
        start_time: Time.zone.parse(start_time.to_s),
        end_time: Time.zone.parse(end_time.to_s)
      }
    end

    def validate_future_date(date)
      raise ValidationError, "過去の日付は指定できません" if date < Date.current
    end

    def validate_time_consistency(start_time, end_time)
      raise ValidationError, "終了時間は開始時間より後である必要があります" if end_time <= start_time
    end

    def validate_no_overlap(employee_id, shift_date, start_time, end_time, exclude_id = nil)
      return unless has_shift_overlap?(employee_id, shift_date, start_time, end_time)

      if exclude_id
        existing_shifts = Shift.where(employee_id: employee_id, shift_date: shift_date).where.not(id: exclude_id)
        overlapping = existing_shifts.any? { |shift| shift.shift_overlaps?(shift, start_time, end_time) }
        raise ValidationError, "指定時間に既存のシフトが重複しています" if overlapping
      else
        raise ValidationError, "指定時間に既存のシフトが重複しています"
      end
    end

    def validate_no_pending_requests(shift_id)
      pending_requests = Shift.get_pending_requests_for_shift(shift_id)
      raise ValidationError, "承認待ちのリクエストがあるため削除できません" if pending_requests.any?
    end

    def generate_request_id(prefix = "REQUEST")
      "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
    end

    def send_notification(notification_service, method_name, *args)
      return if Rails.env.test?

      begin
        notification_service.send(method_name, *args)
        Rails.logger.info "通知送信成功: #{method_name}"
      rescue StandardError => e
        Rails.logger.error "通知送信エラー: #{e.message}"
      end
    end
  end

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def cancelled?
    status == "cancelled"
  end

  def approve_status!
    update!(status: "approved", responded_at: Time.current)
  end

  def reject_status!
    update!(status: "rejected", responded_at: Time.current)
  end

  def cancel_status!
    update!(status: "cancelled", responded_at: Time.current)
  end

  def format_time_range_string(start_time = nil, end_time = nil)
    start_time ||= self.start_time
    end_time ||= self.end_time

    "#{format_time_to_string(start_time)}-#{format_time_to_string(end_time)}"
  end

  def format_hour_range_string(start_time = nil, end_time = nil)
    start_time ||= self.start_time
    end_time ||= self.end_time

    start_hour = start_time.is_a?(String) ? start_time.split(':')[0] : start_time.strftime('%H')
    end_hour = end_time.is_a?(String) ? end_time.split(':')[0] : end_time.strftime('%H')
    "#{start_hour}-#{end_hour}"
  end

  def format_time_to_string(time)
    time.is_a?(String) ? time : time.strftime("%H:%M")
  end

  def format_shift_time_range(start_time = nil, end_time = nil)
    format_time_range_string(start_time, end_time)
  end

  def display_name
    return "#{shift_date.strftime('%m/%d')} #{format_shift_time_range}" if respond_to?(:shift_date)
    format_shift_time_range
  end

  def end_time_after_start_time_validation
    return unless start_time && end_time && end_time <= start_time
    errors.add(:end_time, "終了時間は開始時間より後である必要があります")
  end

  def future_date_only_validation
    return unless shift_date && shift_date < Date.current
    errors.add(:shift_date, "過去の日付は指定できません")
  end

  def shift_date_present?
    respond_to?(:shift_date) && shift_date.present?
  end

  def has_request_id?
    respond_to?(:request_id)
  end

  def has_status?
    respond_to?(:status)
  end

  def has_time_fields?
    respond_to?(:start_time) && respond_to?(:end_time)
  end

  def has_shift_date?
    respond_to?(:shift_date)
  end

  def no_shift_overlap_validation
    return unless respond_to?(:target_employee_id) && target_employee_id.present?
    return unless shift_date && start_time && end_time

    employee_id = respond_to?(:target_employee_id) ? target_employee_id : self.employee_id
    return unless self.class.has_shift_overlap?(employee_id, shift_date, start_time, end_time)

    errors.add(:base, "指定時間に既存のシフトが重複しています")
  end
end
