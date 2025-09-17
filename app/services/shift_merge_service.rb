class ShiftMergeService
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
    merged_start_time_only = Time.zone.parse(merged_start_time.strftime('%H:%M'))
    merged_end_time_only = Time.zone.parse(merged_end_time.strftime('%H:%M'))
    
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
    # 承認者の既存シフトを確認
    existing_shift = Shift.find_by(
      employee_id: approver_employee_id,
      shift_date: shift_to_approve.shift_date
    )
    
    if existing_shift
      # 既存シフトがある場合はマージ
      new_shift_data = Shift.new(
        employee_id: approver_employee_id,
        shift_date: shift_to_approve.shift_date,
        start_time: shift_to_approve.start_time,
        end_time: shift_to_approve.end_time,
        is_modified: true,
        original_employee_id: shift_to_approve.employee_id
      )
      
      # 申請者のシフトが既存シフトに完全に含まれているかチェック
      if shift_fully_contained?(existing_shift, new_shift_data)
        # 完全に含まれている場合は既存シフトを変更しない
        merged_shift = existing_shift
      else
        # 含まれていない場合はマージ
        merged_shift = merge_shifts(existing_shift, new_shift_data)
      end
    else
      # 既存シフトがない場合は新規作成
      merged_shift = Shift.create!(
        employee_id: approver_employee_id,
        shift_date: shift_to_approve.shift_date,
        start_time: shift_to_approve.start_time,
        end_time: shift_to_approve.end_time,
        is_modified: true,
        original_employee_id: shift_to_approve.employee_id
      )
    end
    
    merged_shift
  end
end
