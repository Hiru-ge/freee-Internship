class CreateConversationStates < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_states do |t|
      t.string :line_user_id
      t.text :state_data
      t.datetime :expires_at

      t.timestamps
    end
    add_index :conversation_states, :line_user_id
  end
end
