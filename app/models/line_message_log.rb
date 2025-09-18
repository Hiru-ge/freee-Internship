# frozen_string_literal: true

class LineMessageLog < ApplicationRecord
  validates :line_user_id, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[text image sticker location] }
  validates :direction, presence: true, inclusion: { in: %w[inbound outbound] }

  belongs_to :employee, foreign_key: :line_user_id, primary_key: :line_id, optional: true

  scope :inbound, -> { where(direction: "inbound") }
  scope :outbound, -> { where(direction: "outbound") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(line_user_id) { where(line_user_id: line_user_id) }

  def self.log_inbound_message(line_user_id, message_type, content)
    create!(
      line_user_id: line_user_id,
      message_type: message_type,
      message_content: content,
      direction: "inbound",
      processed_at: Time.current
    )
  end

  def self.log_outbound_message(line_user_id, message_type, content)
    create!(
      line_user_id: line_user_id,
      message_type: message_type,
      message_content: content,
      direction: "outbound",
      processed_at: Time.current
    )
  end
end
