# frozen_string_literal: true

class ConversationState < ApplicationRecord
  validates :line_user_id, presence: true
  validates :state_data, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at < ?", Time.current) }

  def self.find_active_state(line_user_id)
    active.find_by(line_user_id: line_user_id)
  end

  def self.cleanup_expired
    expired.delete_all
  end

  def expired?
    expires_at < Time.current
  end

  def active?
    !expired?
  end

  def state_hash
    JSON.parse(state_data)
  rescue StandardError
    {}
  end

  def state_hash=(hash)
    self.state_data = hash.to_json
  end
end
