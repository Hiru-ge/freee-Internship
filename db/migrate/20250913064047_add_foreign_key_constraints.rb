class AddForeignKeyConstraints < ActiveRecord::Migration[8.0]
  def change
    # shiftsテーブルの外部キー制約
    add_foreign_key :shifts, :employees, column: :employee_id, primary_key: :employee_id, on_delete: :restrict
    add_foreign_key :shifts, :employees, column: :original_employee_id, primary_key: :employee_id, on_delete: :restrict

    # shift_exchangesテーブルの外部キー制約
    add_foreign_key :shift_exchanges, :employees, column: :requester_id, primary_key: :employee_id, on_delete: :restrict
    add_foreign_key :shift_exchanges, :employees, column: :approver_id, primary_key: :employee_id, on_delete: :restrict
    add_foreign_key :shift_exchanges, :shifts, column: :shift_id, on_delete: :restrict

    # shift_additionsテーブルの外部キー制約
    add_foreign_key :shift_additions, :employees, column: :target_employee_id, primary_key: :employee_id, on_delete: :restrict
    add_foreign_key :shift_additions, :employees, column: :requester_id, primary_key: :employee_id, on_delete: :restrict

    # verification_codesテーブルの外部キー制約
    add_foreign_key :verification_codes, :employees, column: :employee_id, primary_key: :employee_id, on_delete: :restrict
  end
end
