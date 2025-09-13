class Shift < ApplicationRecord
  # アソシエーション
  belongs_to :employee, foreign_key: 'employee_id', primary_key: 'employee_id'
  
  # バリデーション
  validates :employee_id, presence: true
  validates :shift_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  
  # 時間の妥当性チェック
  validate :end_time_after_start_time
  
  # スコープ
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_date_range, ->(start_date, end_date) { where(shift_date: start_date..end_date) }
  scope :for_month, ->(year, month) { where(shift_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  
  private
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "終了時間は開始時間より後である必要があります")
    end
  end
end
