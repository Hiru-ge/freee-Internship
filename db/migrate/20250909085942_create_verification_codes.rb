class CreateVerificationCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :verification_codes do |t|
      t.string :line_user_id
      t.string :employee_id
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end
    
    add_index :verification_codes, :code
    add_index :verification_codes, :employee_id
    add_index :verification_codes, :expires_at
    # 外部キー制約は後で追加（employeesテーブルが先に作成される必要がある）
  end
end
