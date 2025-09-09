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
      employee_id: employee_id,
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
    
    existing_start_time = Time.zone.parse("#{base_date} #{existing_start}")
    existing_end_time = Time.zone.parse("#{base_date} #{existing_end}")
    new_start_time_obj = Time.zone.parse("#{base_date} #{new_start_time}")
    new_end_time_obj = Time.zone.parse("#{base_date} #{new_end_time}")
    
    # 重複チェック: 新しいシフトの開始時間が既存シフトの終了時間より前で、
    # 新しいシフトの終了時間が既存シフトの開始時間より後
    new_start_time_obj < existing_end_time && new_end_time_obj > existing_start_time
  end
end
