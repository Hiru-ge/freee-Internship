# frozen_string_literal: true

class ShiftValidationService < BaseService
  # シフト重複チェック処理
  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end

  def get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
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

  def check_addition_overlap(employee_id, shift_date, start_time, end_time)
    if has_shift_overlap?(employee_id, shift_date, start_time, end_time)
      return get_employee_display_name(employee_id)
    end
    nil
  end

  # 複数の従業員の重複チェック
  def check_multiple_employee_overlaps(employee_ids, shift_date, start_time, end_time)
    overlapping_employees = []
    available_employees = []

    employee_ids.each do |employee_id|
      if has_shift_overlap?(employee_id, shift_date, start_time, end_time)
        employee_name = get_employee_display_name(employee_id)
        overlapping_employees << employee_name
      else
        available_employees << employee_id
      end
    end

    {
      available_employees: available_employees,
      overlapping_employees: overlapping_employees,
      has_overlaps: overlapping_employees.any?
    }
  end

  # シフト交代用の重複チェック
  def check_exchange_overlap(employee_id, shift_date, start_time, end_time, exclude_shift_id = nil)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    # 除外するシフトIDがある場合は除外
    existing_shifts = existing_shifts.where.not(id: exclude_shift_id) if exclude_shift_id

    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end

  # 利用可能な従業員の取得
  def get_available_employees_for_shift(shift_date, start_time, end_time, exclude_employee_ids = [])
    all_employees = freee_api_service.get_employees
    available_employees = []

    all_employees.each do |employee|
      employee_id = employee[:id] || employee["id"]

      # 除外リストに含まれている場合はスキップ
      next if exclude_employee_ids.include?(employee_id)

      # 重複チェック
      unless has_shift_overlap?(employee_id, shift_date, start_time, end_time)
        available_employees << employee
      end
    end

    available_employees
  end

  # シフト削除用の重複チェック
  def check_deletion_eligibility(shift_id, employee_id)
    shift = Shift.find_by(id: shift_id, employee_id: employee_id)

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

  private

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
    new_start_time_str = format_time_to_string(new_start_time)
    new_end_time_str = format_time_to_string(new_end_time)

    {
      start: Time.zone.parse("#{base_date} #{new_start_time_str}"),
      end: Time.zone.parse("#{base_date} #{new_end_time_str}")
    }
  end

  def format_time_to_string(time)
    time.is_a?(String) ? time : time.strftime("%H:%M")
  end

  def get_pending_requests_for_shift(shift_id)
    # シフトに関連する承認待ちのリクエストを取得
    pending_exchanges = ShiftExchange.joins(:shift).where(shifts: { id: shift_id }, status: 'pending')
    pending_additions = ShiftAddition.where(shift_id: shift_id, status: 'pending')
    pending_deletions = ShiftDeletion.joins(:shift).where(shifts: { id: shift_id }, status: 'pending')

    pending_exchanges + pending_additions + pending_deletions
  end
end
