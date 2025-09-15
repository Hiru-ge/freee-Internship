class AddLineIdToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :line_id, :string
    add_index :employees, :line_id, unique: true
  end
end
