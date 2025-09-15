class CreateLineMessageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :line_message_logs do |t|
      t.string :line_user_id, null: false
      t.string :message_type, null: false
      t.text :message_content
      t.string :direction, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :line_message_logs, :line_user_id
    add_index :line_message_logs, :processed_at
    add_index :line_message_logs, :direction
  end
end
