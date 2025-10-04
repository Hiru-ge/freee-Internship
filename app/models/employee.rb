# frozen_string_literal: true

class Employee < ApplicationRecord
  validates :employee_id, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[employee owner] }
  validates :line_id, uniqueness: true, allow_nil: true

  has_many :verification_codes, foreign_key: "employee_id", primary_key: "employee_id", dependent: :destroy

  scope :owners, -> { where(role: "owner") }
  scope :employees, -> { where(role: "employee") }

  def owner?
    role == "owner"
  end

  def employee?
    role == "employee"
  end

  def update_last_login!
    update!(last_login_at: Time.current)
  end

  def update_password!(new_password_hash)
    update!(password_hash: new_password_hash, password_updated_at: Time.current)
  end

  def linked_to_line?
    line_id.present?
  end

  def link_to_line(line_user_id)
    update!(line_id: line_user_id)
  end

  def unlink_from_line
    update!(line_id: nil)
  end

  def display_name
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    employee_info = freee_service.get_employee_info(employee_id)
    employee_info&.dig("display_name") || "ID: #{employee_id}"
  rescue StandardError => e
    Rails.logger.error "従業員名取得エラー: #{e.message}"
    "ID: #{employee_id}"
  end

  private

  def password_required?
    persisted? && password_hash.present?
  end
end
