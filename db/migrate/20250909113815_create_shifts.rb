class CreateShifts < ActiveRecord::Migration[8.0]
  def change
    create_table :shifts do |t|
      t.string :employee_id, null: false
      t.date :shift_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.boolean :is_modified, default: false
      t.string :original_employee_id

      t.timestamps
    end

    add_index :shifts, :employee_id
    add_index :shifts, :shift_date
    add_index :shifts, [:shift_date, :start_time, :end_time]
  end
end
