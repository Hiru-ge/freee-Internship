# frozen_string_literal: true

class EmailVerificationCode < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :code, presence: true, length: { is: 6 }, format: { with: /\A\d{6}\z/ }
  validates :expires_at, presence: true

  scope :valid, -> { where("expires_at > ?", Time.current) }
  scope :for_email, ->(email) { where(email: email) }

  def self.generate_code
    rand(100_000..999_999).to_s
  end

  def expired?
    expires_at < Time.current
  end

  def valid_code?
    !expired?
  end
end
