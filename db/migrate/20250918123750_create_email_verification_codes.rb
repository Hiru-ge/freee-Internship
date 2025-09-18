class CreateEmailVerificationCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :email_verification_codes do |t|
      t.string :email, null: false
      t.string :code, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :email_verification_codes, :email
    add_index :email_verification_codes, :code
    add_index :email_verification_codes, :expires_at
  end
end
