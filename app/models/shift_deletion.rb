# frozen_string_literal: true

class ShiftDeletion < ApplicationRecord
  validates :request_id, presence: true, uniqueness: true
  validates :requester_id, presence: true
  validates :shift_id, presence: true
  validates :reason, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }

  belongs_to :shift

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :for_requester, ->(requester_id) { where(requester_id: requester_id) }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def approve!
    update!(status: "approved", responded_at: Time.current)
  end

  def reject!
    update!(status: "rejected", responded_at: Time.current)
  end
end
