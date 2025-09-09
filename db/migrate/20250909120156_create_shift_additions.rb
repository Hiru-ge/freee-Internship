class CreateShiftAdditions < ActiveRecord::Migration[8.0]
  def change
    create_table :shift_additions do |t|
      t.string :request_id, null: false
      t.string :target_employee_id, null: false
      t.date :shift_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :status, default: 'pending'
      t.text :request_message
      t.text :response_message
      t.timestamp :requested_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :responded_at

      t.timestamps
    end

    add_index :shift_additions, :request_id, unique: true
    add_index :shift_additions, :target_employee_id
    add_index :shift_additions, :status
  end
end
