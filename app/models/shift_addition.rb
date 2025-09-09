class ShiftAddition < ApplicationRecord
  # バリデーション
  validates :request_id, presence: true, uniqueness: true
  validates :target_employee_id, presence: true
  validates :shift_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  
  # 時間の妥当性チェック
  validate :end_time_after_start_time
  
  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :for_employee, ->(employee_id) { where(target_employee_id: employee_id) }
  
  # メソッド
  def pending?
    status == 'pending'
  end
  
  def approved?
    status == 'approved'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  def approve!(response_message = nil)
    update!(status: 'approved', responded_at: Time.current)
  end
  
  def reject!(response_message = nil)
    update!(status: 'rejected', responded_at: Time.current)
  end
  
  private
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "終了時間は開始時間より後である必要があります")
    end
  end
end
