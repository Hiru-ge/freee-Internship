class RemoveMessagesFromShiftExchangesAndAdditions < ActiveRecord::Migration[8.0]
  def change
    # シフト交代テーブルからメッセージカラムを削除
    remove_column :shift_exchanges, :request_message, :text
    remove_column :shift_exchanges, :response_message, :text
    
    # シフト追加テーブルからメッセージカラムを削除
    remove_column :shift_additions, :request_message, :text
    remove_column :shift_additions, :response_message, :text
  end
end
