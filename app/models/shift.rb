# frozen_string_literal: true

class Shift < ApplicationRecord
  include ShiftBase

  belongs_to :employee, foreign_key: "employee_id", primary_key: "employee_id"
  validates :employee_id, presence: true

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_date_range, ->(start_date, end_date) { where(shift_date: start_date..end_date) }
  scope :for_month, ->(year, month) { where(shift_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }

  def self.has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    check_shift_overlap(employee_id, shift_date, start_time, end_time)
  end

  def self.get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
    ShiftBase.get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
  end

  def self.check_addition_overlap(employee_id, shift_date, start_time, end_time)
    ShiftBase.check_addition_overlap(employee_id, shift_date, start_time, end_time)
  end

  def self.shift_overlaps?(existing_shift, new_start_time, new_end_time)
    ShiftBase.shift_overlaps?(existing_shift, new_start_time, new_end_time)
  end

  def self.get_employee_display_name(employee_id)
    ShiftBase.get_employee_display_name(employee_id)
  end

  def self.check_deletion_eligibility(shift_id, employee_id)
    shift = find_by(id: shift_id, employee_id: employee_id)
    return { eligible: false, reason: "シフトが見つかりません。" } unless shift

    if shift.shift_date < Date.current
      return { eligible: false, reason: "過去のシフトは削除できません。" }
    end

    pending_requests = get_pending_requests_for_shift(shift_id)
    if pending_requests.any?
      return { eligible: false, reason: "承認待ちのリクエストがあるため削除できません。" }
    end

    { eligible: true, shift: shift }
  end

  def self.get_pending_requests_for_shift(shift_id)
    exchange_requests = ShiftExchange.where(shift_id: shift_id, status: "pending")
    deletion_requests = ShiftDeletion.where(shift_id: shift_id, status: "pending")
    exchange_requests + deletion_requests
  end

  def self.get_monthly_shifts(year, month)
    freee_api_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
    employees = freee_api_service.get_employees

    if employees.empty?
      Rails.logger.warn("従業員データが取得できませんでした")
      return { success: false, error: "従業員データの取得に失敗しました" }
    end

    shifts_in_db = for_month(year, month).includes(:employee)
    shifts = {}
    shifts_by_employee = shifts_in_db.group_by(&:employee_id)

    employees.each do |employee|
      employee_shifts = {}
      employee_id = employee[:id]
      employee_shift_records = shifts_by_employee[employee_id] || []

      employee_shift_records.each do |shift_record|
        day = shift_record.shift_date.day
        time_string = shift_record.format_hour_range_string
        employee_shifts[day.to_s] = time_string
      end

      shifts[employee_id] = {
        name: employee[:display_name],
        shifts: employee_shifts
      }
    end

    { success: true, data: { year: year, month: month, shifts: shifts } }
  rescue StandardError => e
    Rails.logger.error "月次シフトデータ取得エラー: #{e.message}"
    { success: false, error: "シフトデータの取得に失敗しました" }
  end

  def self.get_employee_shifts(employee_id, start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    shifts = where(employee_id: employee_id, shift_date: start_date..end_date)
             .order(:shift_date, :start_time)

    { success: true, data: shifts }
  rescue StandardError => e
    Rails.logger.error "個人シフトデータ取得エラー: #{e.message}"
    { success: false, error: "シフトデータの取得に失敗しました" }
  end

  def self.get_all_employee_shifts(start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    employees = Employee.all
    all_shifts = []

    employees.each do |employee|
      shifts = where(employee_id: employee.employee_id, shift_date: start_date..end_date)
               .order(:shift_date, :start_time)

      shifts.each do |shift|
        all_shifts << {
          employee_name: employee.display_name,
          date: shift.shift_date,
          start_time: shift.start_time.strftime("%H:%M"),
          end_time: shift.end_time.strftime("%H:%M")
        }
      end
    end

    { success: true, data: all_shifts }
  rescue StandardError => e
    Rails.logger.error "全従業員シフトデータ取得エラー: #{e.message}"
    { success: false, error: "シフトデータの取得に失敗しました" }
  end

  def self.format_employee_shifts_for_line(shifts)
    return "今月のシフト情報はありません。" if shifts.empty?

    message = "📅 今月のシフト\n\n"
    shifts.each do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      message += "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.format_time_range_string}\n"
    end
    message
  end

  def self.create_with_validation(employee_id:, shift_date:, start_time:, end_time:)
    validate_required_fields(employee_id, shift_date, start_time, end_time)
    parsed_data = parse_date_and_times(shift_date, start_time, end_time)
    validate_future_date(parsed_data[:date])
    validate_time_consistency(parsed_data[:start_time], parsed_data[:end_time])
    validate_no_overlap(employee_id, parsed_data[:date], parsed_data[:start_time], parsed_data[:end_time])

    create!(
      employee_id: employee_id,
      shift_date: parsed_data[:date],
      start_time: parsed_data[:start_time],
      end_time: parsed_data[:end_time]
    )
  rescue ValidationError => e
    raise ArgumentError, e.message
  end

  def update_with_validation(shift_data)
    update_params = {}

    if shift_data[:shift_date].present?
      parsed_date = Date.parse(shift_data[:shift_date].to_s)
      self.class.validate_future_date(parsed_date)
      update_params[:shift_date] = parsed_date
    end

    if shift_data[:start_time].present?
      update_params[:start_time] = Time.zone.parse(shift_data[:start_time].to_s)
    end

    if shift_data[:end_time].present?
      update_params[:end_time] = Time.zone.parse(shift_data[:end_time].to_s)
    end

    start_time_to_check = update_params[:start_time] || start_time
    end_time_to_check = update_params[:end_time] || end_time
    self.class.validate_time_consistency(start_time_to_check, end_time_to_check)

    date_to_check = update_params[:shift_date] || shift_date
    self.class.validate_no_overlap(employee_id, date_to_check, start_time_to_check, end_time_to_check, id)

    update!(update_params)
  rescue ValidationError => e
    raise ArgumentError, e.message
  end

  def destroy_with_validation
    self.class.validate_future_date(shift_date)
    self.class.validate_no_pending_requests(id)
    destroy!
  rescue ValidationError => e
    raise ArgumentError, e.message
  end

  def self.validate_shift_date(date_string)
    return { success: false, error: "日付が指定されていません" } if date_string.blank?

    parsed_date = Date.parse(date_string.to_s)
    if parsed_date < Date.current
      { success: false, error: "過去の日付は指定できません" }
    else
      { success: true, date: parsed_date }
    end
  rescue ArgumentError
    { success: false, error: "無効な日付形式です" }
  end

  def self.validate_shift_time(time_string)
    return { success: false, error: "時間が入力されていません" } if time_string.blank?

    parsed_time = Time.zone.parse(time_string.to_s)
    { success: true, time: parsed_time }
  rescue ArgumentError
    { success: false, error: "無効な時間形式です" }
  end

  def self.validate_shift_params(params)
    errors = []
    required_fields = [:employee_id, :shift_date, :start_time, :end_time]
    required_fields.each { |field| errors << "#{field}が不足しています" if params[field].blank? }

    return { success: false, errors: errors } if errors.any?

    date_result = validate_shift_date(params[:shift_date])
    errors << date_result[:error] unless date_result[:success]

    start_time_result = validate_shift_time(params[:start_time])
    errors << start_time_result[:error] unless start_time_result[:success]

    end_time_result = validate_shift_time(params[:end_time])
    errors << end_time_result[:error] unless end_time_result[:success]

    if start_time_result[:success] && end_time_result[:success]
      consistency_result = validate_shift_time_consistency(start_time_result[:time], end_time_result[:time])
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

  def self.validate_shift_time_consistency(start_time, end_time)
    start_time_obj = start_time.is_a?(String) ? Time.zone.parse(start_time) : start_time
    end_time_obj = end_time.is_a?(String) ? Time.zone.parse(end_time) : end_time

    if end_time_obj <= start_time_obj
      { success: false, error: "終了時間は開始時間より後である必要があります" }
    else
      { success: true }
    end
  end

  def self.validate_required_shift_params(params)
    validate_shift_params(params)
  end

  def self.validate_date_format(date_string)
    validate_shift_date(date_string)
  end

  def self.validate_time_format(time_string)
    validate_shift_time(time_string)
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time && end_time <= start_time
    errors.add(:end_time, "終了時間は開始時間より後である必要があります")
  end
end
