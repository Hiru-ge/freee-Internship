class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.string :employee_id
      t.string :password_hash
      t.string :role
      t.datetime :last_login_at
      t.datetime :password_updated_at

      t.timestamps
    end
    add_index :employees, :employee_id, unique: true
  end
end
