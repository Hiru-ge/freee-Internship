class ShiftOverlapService
  def initialize
  end

  # シフト交代依頼時の重複チェック
  def check_exchange_overlap(approver_ids, shift_date, start_time, end_time)
    overlapping_employees = []
    
    approver_ids.each do |approver_id|
      if has_shift_overlap?(approver_id, shift_date, start_time, end_time)
        employee = Employee.find_by(employee_id: approver_id)
        employee_name = employee&.display_name || "ID: #{approver_id}"
        overlapping_employees << employee_name
      end
    end
    
    overlapping_employees
  end

  # 利用可能な従業員IDと重複している従業員名を返す
  def get_available_and_overlapping_employees(approver_ids, shift_date, start_time, end_time)
    available_ids = []
    overlapping_names = []
    
    approver_ids.each do |approver_id|
      if has_shift_overlap?(approver_id, shift_date, start_time, end_time)
        employee = Employee.find_by(employee_id: approver_id.to_s)
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

  # 指定された従業員が指定された時間にシフトが入っているかチェック
  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    # 既存のシフトを取得
    existing_shifts = Shift.where(
      employee_id: employee_id.to_s,
      shift_date: shift_date
    )
    
    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end

  # 2つのシフト時間が重複しているかチェック
  def shift_overlaps?(existing_shift, new_start_time, new_end_time)
    existing_start = existing_shift.start_time
    existing_end = existing_shift.end_time
    
    # 時間をTimeオブジェクトに変換（日付は同じ日として扱う）
    base_date = existing_shift.shift_date
    
    # 既存シフトの時間をTimeオブジェクトに変換
    existing_start_time_obj = Time.zone.parse("#{base_date} #{existing_start.strftime('%H:%M')}")
    existing_end_time_obj = Time.zone.parse("#{base_date} #{existing_end.strftime('%H:%M')}")
    
    # 新しいシフトの時間をTimeオブジェクトに変換（文字列の場合はそのまま使用）
    new_start_time_str = new_start_time.is_a?(String) ? new_start_time : new_start_time.strftime('%H:%M')
    new_end_time_str = new_end_time.is_a?(String) ? new_end_time : new_end_time.strftime('%H:%M')
    
    new_start_time_obj = Time.zone.parse("#{base_date} #{new_start_time_str}")
    new_end_time_obj = Time.zone.parse("#{base_date} #{new_end_time_str}")
    
    # 重複チェック: 新しいシフトの開始時間が既存シフトの終了時間より前で、
    # 新しいシフトの終了時間が既存シフトの開始時間より後
    new_start_time_obj < existing_end_time_obj && new_end_time_obj > existing_start_time_obj
  end
end
