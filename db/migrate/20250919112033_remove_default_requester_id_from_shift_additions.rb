class RemoveDefaultRequesterIdFromShiftAdditions < ActiveRecord::Migration[8.0]
  def change
    change_column_default :shift_additions, :requester_id, nil
  end
end
