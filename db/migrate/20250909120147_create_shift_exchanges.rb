class CreateShiftExchanges < ActiveRecord::Migration[8.0]
  def change
    create_table :shift_exchanges do |t|
      t.string :request_id, null: false
      t.string :requester_id, null: false
      t.string :approver_id, null: false
      t.integer :shift_id
      t.string :status, default: 'pending'
      t.text :request_message
      t.text :response_message
      t.timestamp :requested_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :responded_at

      t.timestamps
    end

    add_index :shift_exchanges, :request_id, unique: true
    add_index :shift_exchanges, :requester_id
    add_index :shift_exchanges, :approver_id
    add_index :shift_exchanges, :status
  end
end
