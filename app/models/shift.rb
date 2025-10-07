# frozen_string_literal: true

class Shift < ApplicationRecord
  belongs_to :employee, foreign_key: "employee_id", primary_key: "employee_id"

  validates :employee_id, presence: true
  validates :shift_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  validate :end_time_after_start_time

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_date_range, ->(start_date, end_date) { where(shift_date: start_date..end_date) }
  scope :for_month, ->(year, month) { where(shift_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }

  def display_name
    "#{shift_date.strftime('%m/%d')} #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}"
  end

  # クラスメソッド: シフト重複チェック（ShiftValidationServiceから移行）
  def self.has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    existing_shifts = where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end

  # クラスメソッド: 複数従業員の重複チェック
  def self.get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
    available_ids = []
    overlapping_names = []

    employee_ids.each do |employee_id|
      if has_shift_overlap?(employee_id, shift_date, start_time, end_time)
        employee_name = get_employee_display_name(employee_id)
        overlapping_names << employee_name
      else
        available_ids << employee_id
      end
    end

    { available_ids: available_ids, overlapping_names: overlapping_names }
  end

  # クラスメソッド: 単一従業員の重複チェック
  def self.check_addition_overlap(employee_id, shift_date, start_time, end_time)
    if has_shift_overlap?(employee_id, shift_date, start_time, end_time)
      return get_employee_display_name(employee_id)
    end
    nil
  end

  # クラスメソッド: 削除可能性チェック
  def self.check_deletion_eligibility(shift_id, employee_id)
    shift = find_by(id: shift_id, employee_id: employee_id)

    return { eligible: false, reason: "シフトが見つかりません。" } unless shift

    # 過去のシフトは削除不可
    if shift.shift_date < Date.current
      return { eligible: false, reason: "過去のシフトは削除できません。" }
    end

    # 承認待ちのリクエストがある場合は削除不可
    pending_requests = get_pending_requests_for_shift(shift_id)
    if pending_requests.any?
      return { eligible: false, reason: "承認待ちのリクエストがあるため削除できません。" }
    end

    { eligible: true, shift: shift }
  end

  # クラスメソッド: シフト重複判定
  def self.shift_overlaps?(existing_shift, new_start_time, new_end_time)
    existing_times = convert_shift_times_to_objects(existing_shift)
    new_times = convert_new_shift_times_to_objects(existing_shift.shift_date, new_start_time, new_end_time)

    new_times[:start] < existing_times[:end] && new_times[:end] > existing_times[:start]
  end

  # クラスメソッド: 既存シフトの時間オブジェクト変換
  def self.convert_shift_times_to_objects(existing_shift)
    base_date = existing_shift.shift_date
    {
      start: Time.zone.parse("#{base_date} #{existing_shift.start_time.strftime('%H:%M')}"),
      end: Time.zone.parse("#{base_date} #{existing_shift.end_time.strftime('%H:%M')}")
    }
  end

  # クラスメソッド: 新しいシフトの時間オブジェクト変換
  def self.convert_new_shift_times_to_objects(base_date, new_start_time, new_end_time)
    new_start_time_str = format_time_to_string(new_start_time)
    new_end_time_str = format_time_to_string(new_end_time)

    {
      start: Time.zone.parse("#{base_date} #{new_start_time_str}"),
      end: Time.zone.parse("#{base_date} #{new_end_time_str}")
    }
  end

  # クラスメソッド: 時間フォーマット変換
  def self.format_time_to_string(time)
    time.is_a?(String) ? time : time.strftime("%H:%M")
  end

  # クラスメソッド: 従業員名取得
  def self.get_employee_display_name(employee_id)
    employee = Employee.find_by(employee_id: employee_id)
    employee&.display_name || "ID: #{employee_id}"
  end

  # クラスメソッド: 承認待ちリクエスト取得
  def self.get_pending_requests_for_shift(shift_id)
    # ShiftExchange, ShiftAddition, ShiftDeletionの承認待ちリクエストを取得
    exchange_requests = ShiftExchange.where(shift_id: shift_id, status: "pending")
    deletion_requests = ShiftDeletion.where(shift_id: shift_id, status: "pending")

    exchange_requests + deletion_requests
  end

  # クラスメソッド: 月次シフトデータ取得（ShiftDisplayServiceから移行）
  def self.get_monthly_shifts(year, month)
    begin
      # FreeeAPIから従業員データを取得
      freee_api_service = FreeeApiService.new(
        ENV.fetch("FREEE_ACCESS_TOKEN", nil),
        ENV.fetch("FREEE_COMPANY_ID", nil)
      )
      employees = freee_api_service.get_employees

      if employees.empty?
        Rails.logger.warn("従業員データが取得できませんでした")
        return {
          success: false,
          error: "従業員データの取得に失敗しました"
        }
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
          time_string = "#{shift_record.start_time.strftime('%H')}-#{shift_record.end_time.strftime('%H')}"
          employee_shifts[day.to_s] = time_string
        end

        shifts[employee_id] = {
          name: employee[:display_name],
          shifts: employee_shifts
        }
      end

      {
        success: true,
        data: {
          year: year,
          month: month,
          shifts: shifts
        }
      }
    rescue StandardError => e
      Rails.logger.error "月次シフトデータ取得エラー: #{e.message}"
      {
        success: false,
        error: "シフトデータの取得に失敗しました"
      }
    end
  end

  # クラスメソッド: 個人シフトデータ取得（ShiftDisplayServiceから移行）
  def self.get_employee_shifts(employee_id, start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    shifts = where(
      employee_id: employee_id,
      shift_date: start_date..end_date
    ).order(:shift_date, :start_time)

    {
      success: true,
      data: shifts
    }
  rescue StandardError => e
    Rails.logger.error "個人シフトデータ取得エラー: #{e.message}"
    {
      success: false,
      error: "シフトデータの取得に失敗しました"
    }
  end

  # クラスメソッド: 全従業員シフトデータ取得（ShiftDisplayServiceから移行）
  def self.get_all_employee_shifts(start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    employees = Employee.all
    all_shifts = []

    employees.each do |employee|
      shifts = where(
        employee_id: employee.employee_id,
        shift_date: start_date..end_date
      ).order(:shift_date, :start_time)

      shifts.each do |shift|
        all_shifts << {
          employee_name: employee.display_name,
          date: shift.shift_date,
          start_time: shift.start_time.strftime("%H:%M"),
          end_time: shift.end_time.strftime("%H:%M")
        }
      end
    end

    {
      success: true,
      data: all_shifts
    }
  rescue StandardError => e
    Rails.logger.error "全従業員シフトデータ取得エラー: #{e.message}"
    {
      success: false,
      error: "シフトデータの取得に失敗しました"
    }
  end

  # クラスメソッド: LINE用シフトフォーマット（ShiftDisplayServiceから移行）
  def self.format_employee_shifts_for_line(shifts)
    return "今月のシフト情報はありません。" if shifts.empty?

    message = "📅 今月のシフト\n\n"
    shifts.each do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      message += "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    end

    message
  end

  # === バリデーション機能（InputValidationから移行） ===

  # 日付形式バリデーション
  def self.validate_date_format(date_string)
    return { success: false, error: "日付が入力されていません" } if date_string.blank?

    date_regex = /\A\d{4}-\d{2}-\d{2}\z/
    unless date_string.match?(date_regex)
      return { success: false, error: "日付の形式が正しくありません" }
    end

    begin
      parsed_date = Date.parse(date_string)
      { success: true, date: parsed_date }
    rescue ArgumentError
      { success: false, error: "無効な日付です" }
    end
  end

  # 時間形式バリデーション
  def self.validate_time_format(time_string)
    return { success: false, error: "時間が入力されていません" } if time_string.blank?

    time_regex = /\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/
    unless time_string.match?(time_regex)
      return { success: false, error: "時間の形式が正しくありません" }
    end

    { success: true }
  end

  # 必須パラメータバリデーション
  def self.validate_required_shift_params(params)
    required_fields = [:employee_id, :shift_date, :start_time, :end_time]
    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      field_names = missing_fields.map { |field|
        case field
        when :employee_id then "従業員"
        when :shift_date then "日付"
        when :start_time then "開始時間"
        when :end_time then "終了時間"
        else field.to_s
        end
      }
      return { success: false, error: "#{field_names.join('、')}を入力してください" }
    end

    { success: true }
  end

  # シフトパラメータの総合バリデーション
  def self.validate_shift_params(params)
    # 必須パラメータチェック
    required_result = validate_required_shift_params(params)
    return required_result unless required_result[:success]

    # 日付形式チェック
    date_result = validate_date_format(params[:shift_date])
    return date_result unless date_result[:success]

    # 時間形式チェック
    start_time_result = validate_time_format(params[:start_time])
    return start_time_result unless start_time_result[:success]

    end_time_result = validate_time_format(params[:end_time])
    return end_time_result unless end_time_result[:success]

    # 時間の整合性チェック
    begin
      start_time = Time.zone.parse(params[:start_time])
      end_time = Time.zone.parse(params[:end_time])

      if end_time <= start_time
        return { success: false, error: "終了時間は開始時間より後にしてください" }
      end
    rescue ArgumentError
      return { success: false, error: "時間の形式が正しくありません" }
    end

    { success: true }
  end

  # クラスメソッド: CRUD操作 - バリデーション付き作成
  def self.create_with_validation(employee_id:, shift_date:, start_time:, end_time:)
    # バリデーション
    raise ArgumentError, "必須項目が不足しています" if [employee_id, shift_date, start_time, end_time].any?(&:blank?)

    # 日付・時間の解析
    parsed_date = Date.parse(shift_date.to_s)
    parsed_start_time = Time.zone.parse(start_time.to_s)
    parsed_end_time = Time.zone.parse(end_time.to_s)

    # 過去日付チェック
    raise ArgumentError, "過去の日付は指定できません" if parsed_date < Date.current

    # 時間の妥当性チェック
    raise ArgumentError, "終了時間は開始時間より後である必要があります" if parsed_end_time <= parsed_start_time

    # 重複チェック
    if has_shift_overlap?(employee_id, parsed_date, parsed_start_time, parsed_end_time)
      raise ArgumentError, "指定時間に既存のシフトが重複しています"
    end

    # シフト作成
    create!(
      employee_id: employee_id,
      shift_date: parsed_date,
      start_time: parsed_start_time,
      end_time: parsed_end_time
    )
  end

  # インスタンスメソッド: バリデーション付き更新
  def update_with_validation(shift_data)
    # 更新データの準備
    update_params = {}

    if shift_data[:shift_date].present?
      parsed_date = Date.parse(shift_data[:shift_date].to_s)
      raise ArgumentError, "過去の日付は指定できません" if parsed_date < Date.current
      update_params[:shift_date] = parsed_date
    end

    if shift_data[:start_time].present?
      update_params[:start_time] = Time.zone.parse(shift_data[:start_time].to_s)
    end

    if shift_data[:end_time].present?
      update_params[:end_time] = Time.zone.parse(shift_data[:end_time].to_s)
    end

    # 時間の妥当性チェック
    start_time_to_check = update_params[:start_time] || start_time
    end_time_to_check = update_params[:end_time] || end_time

    if end_time_to_check <= start_time_to_check
      raise ArgumentError, "終了時間は開始時間より後である必要があります"
    end

    # 重複チェック（自分以外のシフト）
    date_to_check = update_params[:shift_date] || shift_date
    existing_shifts = self.class.where(
      employee_id: employee_id,
      shift_date: date_to_check
    ).where.not(id: id)

    if existing_shifts.any? { |shift| self.class.shift_overlaps?(shift, start_time_to_check, end_time_to_check) }
      raise ArgumentError, "指定時間に既存のシフトが重複しています"
    end

    # 更新実行
    update!(update_params)
  end

  # インスタンスメソッド: バリデーション付き削除
  def destroy_with_validation
    # 過去のシフトは削除不可
    if shift_date < Date.current
      raise ArgumentError, "過去のシフトは削除できません"
    end

    # 承認待ちのリクエストがある場合は削除不可
    pending_requests = self.class.get_pending_requests_for_shift(id)
    if pending_requests.any?
      raise ArgumentError, "承認待ちのリクエストがあるため削除できません"
    end

    # 削除実行
    destroy!
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    return unless end_time <= start_time

    errors.add(:end_time, "終了時間は開始時間より後である必要があります")
  end
end
