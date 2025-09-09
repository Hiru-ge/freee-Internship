class Employee < ApplicationRecord
  # バリデーション
  validates :employee_id, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[employee owner] }
  
  # パスワードは初回ログイン時は未設定でもOK
  # validates :password_hash, presence: true
  
  # リレーション
  has_many :verification_codes, foreign_key: 'employee_id', primary_key: 'employee_id', dependent: :destroy
  
  # スコープ
  scope :owners, -> { where(role: 'owner') }
  scope :employees, -> { where(role: 'employee') }
  
  # インスタンスメソッド
  def owner?
    role == 'owner'
  end
  
  def employee?
    role == 'employee'
  end
  
  def update_last_login!
    update!(last_login_at: Time.current)
  end
  
  def update_password!(new_password_hash)
    update!(password_hash: new_password_hash, password_updated_at: Time.current)
  end

  # freee APIから取得した従業員名を返す（将来の拡張用）
  def display_name
    # 現在は固定値を使用、将来はfreee APIから取得
    case employee_id
    when '3313254'
      '店長 太郎'
    when '3316120'
      'テスト 次郎'
    when '3317741'
      'テスト 三郎'
    when '3316116'
      'テスト 四郎'
    else
      "ID: #{employee_id}"
    end
  end
  
  private
  
  def password_required?
    # パスワードが既に設定されている場合は必須
    # 初回作成時は不要
    persisted? && password_hash.present?
  end
end
