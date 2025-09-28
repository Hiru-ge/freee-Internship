# frozen_string_literal: true

# 統合シフト表示サービス
# シフト表示、マージ、重複チェックを一元管理
class ShiftDisplayService
  def initialize(freee_api_service = nil)
    @freee_api_service = freee_api_service
  end

  # 月次シフトデータの取得（Webアプリ用）
  def get_monthly_shifts(year, month)
    # freee APIから従業員一覧を取得
    employees = get_employees_from_api

    # DBからシフトデータを取得（N+1問題を解決するためincludesを使用）
    shifts_in_db = Shift.for_month(year, month).includes(:employee)

    # 従業員データをシフト形式に変換（N+1問題を解決するため一括処理）
    shifts = {}
    employees.map { |emp| emp[:id] }

    # 従業員ごとにシフトデータをグループ化
    shifts_by_employee = shifts_in_db.group_by(&:employee_id)

    employees.each do |employee|
      employee_shifts = {}
      employee_id = employee[:id]

      # 該当従業員のシフトデータを取得（N+1問題を解決）
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

  # 個人シフトデータの取得（LINE Bot用）
  def get_employee_shifts(employee_id, start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    shifts = Shift.where(
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

  # 全従業員シフトデータの取得（LINE Bot用）
  def get_all_employee_shifts(start_date = nil, end_date = nil)
    start_date ||= Date.current
    end_date ||= start_date + 1.month

    employees = Employee.all
    all_shifts = []

    employees.each do |employee|
      shifts = Shift.where(
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

  # シフトデータのフォーマット（LINE Bot用）
  def format_employee_shifts_for_line(shifts)
    return "今月のシフト情報はありません。" if shifts.empty?

    message = "📅 今月のシフト\n\n"
    shifts.each do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      message += "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    end

    message
  end

  # 全従業員シフトデータのフォーマット（LINE Bot用）
  def format_all_shifts_for_line(all_shifts)
    return "【今月の全員シフト】\n今月のシフト情報はありません。" if all_shifts.empty?

    # 日付ごとにグループ化
    grouped_shifts = all_shifts.group_by { |shift| shift[:date] }

    # シフト情報をフォーマット
    message = "【今月の全員シフト】\n\n"
    grouped_shifts.sort_by { |date, _| date }.each do |date, shifts|
      day_of_week = %w[日 月 火 水 木 金 土][date.wday]
      message += "#{date.strftime('%m/%d')} (#{day_of_week})\n"

      shifts.each do |shift|
        message += "  #{shift[:employee_name]}: #{shift[:start_time]}-#{shift[:end_time]}\n"
      end
      message += "\n"
    end

    message
  end

  # ===== シフトマージ機能 =====

  # シフトをマージする
  def self.merge_shifts(existing_shift, new_shift)
    return new_shift unless existing_shift

    # 既存シフトと新しいシフトの時間を比較してマージ
    # 時間のみを比較するため、同じ日付のTimeオブジェクトを作成
    existing_start_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    new_start_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.start_time.strftime('%H:%M')}")
    new_end_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.end_time.strftime('%H:%M')}")

    merged_start_time = [existing_start_time, new_start_time].min
    merged_end_time = [existing_end_time, new_end_time].max

    # 時間のみを抽出してTime型で保存
    merged_start_time_only = Time.zone.parse(merged_start_time.strftime("%H:%M"))
    merged_end_time_only = Time.zone.parse(merged_end_time.strftime("%H:%M"))

    # 既存シフトを更新
    existing_shift.update!(
      start_time: merged_start_time_only,
      end_time: merged_end_time_only,
      is_modified: true,
      original_employee_id: new_shift.original_employee_id || new_shift.employee_id
    )

    existing_shift
  end

  # 申請者のシフトが承認者のシフトに完全に含まれているかチェック
  def self.shift_fully_contained?(existing_shift, new_shift)
    # 時間のみを比較するため、同じ日付のTimeオブジェクトを作成
    existing_start_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    new_start_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.start_time.strftime('%H:%M')}")
    new_end_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.end_time.strftime('%H:%M')}")

    # 申請者のシフトが既存シフトに完全に含まれているかチェック
    new_start_time >= existing_start_time && new_end_time <= existing_end_time
  end

  # シフト交代承認時のシフト処理
  def self.process_shift_exchange_approval(approver_employee_id, shift_to_approve)
    new_shift_data = {
      employee_id: approver_employee_id,
      shift_date: shift_to_approve.shift_date,
      start_time: shift_to_approve.start_time,
      end_time: shift_to_approve.end_time,
      is_modified: true,
      original_employee_id: shift_to_approve.employee_id
    }

    process_shift_approval(approver_employee_id, new_shift_data)
  end

  # シフト追加承認時のシフト処理
  def self.process_shift_addition_approval(employee_id, new_shift_data)
    shift_data = {
      employee_id: employee_id,
      shift_date: new_shift_data[:shift_date],
      start_time: new_shift_data[:start_time],
      end_time: new_shift_data[:end_time],
      is_modified: true,
      original_employee_id: new_shift_data[:requester_id]
    }

    process_shift_approval(employee_id, shift_data)
  end

  # 共通のシフト承認処理
  def self.process_shift_approval(employee_id, shift_data)
    # 既存シフトを確認
    existing_shift = Shift.find_by(
      employee_id: employee_id,
      shift_date: shift_data[:shift_date]
    )

    if existing_shift
      # 既存シフトがある場合はマージ
      new_shift = Shift.new(shift_data)

      # 申請者のシフトが既存シフトに完全に含まれているかチェック
      merged_shift = if shift_fully_contained?(existing_shift, new_shift)
                       # 完全に含まれている場合は既存シフトを変更しない
                       existing_shift
                     else
                       # 含まれていない場合はマージ
                       merge_shifts(existing_shift, new_shift)
                     end
    else
      # 既存シフトがない場合は新規作成
      merged_shift = Shift.create!(shift_data)
    end

    merged_shift
  end

  # ===== シフト重複チェック機能 =====

  # シフト交代依頼時の重複チェック
  def check_exchange_overlap(approver_ids, shift_date, start_time, end_time)
    overlapping_employees = []

    approver_ids.each do |approver_id|
      next unless has_shift_overlap?(approver_id, shift_date, start_time, end_time)

      employee = Employee.find_by(employee_id: approver_id)
      employee_name = employee&.display_name || "ID: #{approver_id}"
      overlapping_employees << employee_name
    end

    overlapping_employees
  end

  # 依頼可能な従業員IDと重複している従業員名を返す
  def get_available_and_overlapping_employees(approver_ids, shift_date, start_time, end_time)
    available_ids = []
    overlapping_names = []

    approver_ids.each do |approver_id|
      if has_shift_overlap?(approver_id, shift_date, start_time, end_time)
        employee = Employee.find_by(employee_id: approver_id)
        employee_name = employee&.display_name || "ID: #{approver_id}"
        overlapping_names << employee_name
      else
        available_ids << approver_id
      end
    end

    { available_ids: available_ids, overlapping_names: overlapping_names }
  end

  # シフト追加依頼時の重複チェック
  def check_addition_overlap(target_employee_id, shift_date, start_time, end_time)
    if has_shift_overlap?(target_employee_id, shift_date, start_time, end_time)
      employee = Employee.find_by(employee_id: target_employee_id)
      employee_name = employee&.display_name || "ID: #{target_employee_id}"
      return employee_name
    end

    nil
  end

  private

  # freee APIから従業員情報を取得
  def get_employees_from_api
    if @freee_api_service
      @freee_api_service.get_employees
    else
      # フォールバック: DBから従業員情報を取得
      Employee.all.map do |emp|
        {
          id: emp.employee_id,
          display_name: emp.display_name
        }
      end
    end
  end

  # 指定された従業員が指定された時間にシフトが入っているかチェック
  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    # 既存のシフトを取得
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end

  # 2つのシフト時間が重複しているかチェック
  def shift_overlaps?(existing_shift, new_start_time, new_end_time)
    existing_times = convert_shift_times_to_objects(existing_shift)
    new_times = convert_new_shift_times_to_objects(existing_shift.shift_date, new_start_time, new_end_time)

    # 重複チェック: 新しいシフトの開始時間が既存シフトの終了時間より前で、
    # 新しいシフトの終了時間が既存シフトの開始時間より後
    new_times[:start] < existing_times[:end] && new_times[:end] > existing_times[:start]
  end

  # 既存シフトの時間をTimeオブジェクトに変換
  def convert_shift_times_to_objects(existing_shift)
    base_date = existing_shift.shift_date

    {
      start: Time.zone.parse("#{base_date} #{existing_shift.start_time.strftime('%H:%M')}"),
      end: Time.zone.parse("#{base_date} #{existing_shift.end_time.strftime('%H:%M')}")
    }
  end

  # 新しいシフトの時間をTimeオブジェクトに変換
  def convert_new_shift_times_to_objects(base_date, new_start_time, new_end_time)
    new_start_time_str = format_time_to_string(new_start_time)
    new_end_time_str = format_time_to_string(new_end_time)

    {
      start: Time.zone.parse("#{base_date} #{new_start_time_str}"),
      end: Time.zone.parse("#{base_date} #{new_end_time_str}")
    }
  end

  # 時間オブジェクトを文字列に変換
  def format_time_to_string(time)
    time.is_a?(String) ? time : time.strftime("%H:%M")
  end
end
