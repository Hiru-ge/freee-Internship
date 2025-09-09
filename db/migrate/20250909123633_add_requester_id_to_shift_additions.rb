class AddRequesterIdToShiftAdditions < ActiveRecord::Migration[8.0]
  def change
    add_column :shift_additions, :requester_id, :string, null: false, default: '3313254'
    add_index :shift_additions, :requester_id
  end
end
