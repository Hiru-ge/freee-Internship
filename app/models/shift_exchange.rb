class ShiftExchange < ApplicationRecord
  # バリデーション
  validates :request_id, presence: true, uniqueness: true
  validates :requester_id, presence: true
  validates :approver_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected cancelled] }
  
  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_requester, ->(requester_id) { where(requester_id: requester_id) }
  scope :for_approver, ->(approver_id) { where(approver_id: approver_id) }
  
  # 関連付け
  belongs_to :shift, optional: true
  
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
  
  def cancelled?
    status == 'cancelled'
  end
  
  def approve!(response_message = nil)
    update!(status: 'approved', responded_at: Time.current)
  end
  
  def reject!(response_message = nil)
    update!(status: 'rejected', responded_at: Time.current)
  end
  
  def cancel!
    update!(status: 'cancelled', responded_at: Time.current)
  end
end
