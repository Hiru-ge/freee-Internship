class CreateShiftDeletions < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:shift_deletions)
      create_table :shift_deletions do |t|
        t.string :request_id, null: false
        t.string :requester_id, null: false
        t.references :shift, null: false, foreign_key: true
        t.text :reason, null: false
        t.string :status, null: false, default: "pending"
        t.datetime :responded_at

        t.timestamps
      end

      add_index :shift_deletions, :request_id, unique: true
      add_index :shift_deletions, :requester_id
      add_index :shift_deletions, :status
      add_index :shift_deletions, :responded_at
    end
  end
end
