class CleanupInvalidDataBeforeForeignKeys < ActiveRecord::Migration[8.0]
  def up
    # 存在しない従業員IDを参照しているシフトを削除
    invalid_employee_ids = ['3316116', '3316120']
    
    puts "Cleaning up shifts with invalid employee_ids: #{invalid_employee_ids.join(', ')}"
    
    # 関連するshift_exchangesを先に削除
    ShiftExchange.where(shift_id: Shift.where(employee_id: invalid_employee_ids).pluck(:id)).delete_all
    
    # 無効なemployee_idを持つシフトを削除
    deleted_shifts = Shift.where(employee_id: invalid_employee_ids).delete_all
    puts "Deleted #{deleted_shifts} shifts with invalid employee_ids"
    
    # 存在しない従業員IDを参照しているshift_exchangesを削除
    deleted_exchanges = ShiftExchange.where(requester_id: invalid_employee_ids).or(
      ShiftExchange.where(approver_id: invalid_employee_ids)
    ).delete_all
    puts "Deleted #{deleted_exchanges} shift_exchanges with invalid employee_ids"
    
    # 存在しない従業員IDを参照しているshift_additionsを削除
    deleted_additions = ShiftAddition.where(target_employee_id: invalid_employee_ids).or(
      ShiftAddition.where(requester_id: invalid_employee_ids)
    ).delete_all
    puts "Deleted #{deleted_additions} shift_additions with invalid employee_ids"
    
    # 存在しない従業員IDを参照しているverification_codesを削除
    deleted_codes = VerificationCode.where(employee_id: invalid_employee_ids).delete_all
    puts "Deleted #{deleted_codes} verification_codes with invalid employee_ids"
  end

  def down
    # このマイグレーションは不可逆的（データ削除のため）
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse data cleanup migration"
  end
end
