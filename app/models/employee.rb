# frozen_string_literal: true

class Employee < ApplicationRecord
  # バリデーション
  validates :employee_id, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[employee owner] }
  validates :line_id, uniqueness: true, allow_nil: true

  # パスワードは初回ログイン時は未設定でもOK
  # validates :password_hash, presence: true

  # リレーション
  has_many :verification_codes, foreign_key: "employee_id", primary_key: "employee_id", dependent: :destroy

  # スコープ
  scope :owners, -> { where(role: "owner") }
  scope :employees, -> { where(role: "employee") }

  # インスタンスメソッド
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

  # freee APIから取得した従業員名を返す
  def display_name
    # freeeAPIから従業員情報を取得
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
    # パスワードが既に設定されている場合は必須
    # 初回作成時は不要
    persisted? && password_hash.present?
  end
end
