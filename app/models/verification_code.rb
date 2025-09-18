# frozen_string_literal: true

class VerificationCode < ApplicationRecord
  # バリデーション
  validates :code, presence: true, length: { is: 6 }
  validates :expires_at, presence: true

  # リレーション
  belongs_to :employee, foreign_key: "employee_id", primary_key: "employee_id"

  # スコープ
  scope :active, -> { where("expires_at > ? AND used_at IS NULL", Time.current) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :used, -> { where.not(used_at: nil) }

  # クラスメソッド
  def self.generate_code
    rand(100_000..999_999).to_s
  end

  def self.cleanup_expired
    expired.delete_all
  end

  def self.find_valid_code(employee_id, code)
    active.find_by(employee_id: employee_id, code: code)
  end

  # インスタンスメソッド
  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def active?
    !expired? && !used?
  end

  def mark_as_used!
    update!(used_at: Time.current)
  end
end
