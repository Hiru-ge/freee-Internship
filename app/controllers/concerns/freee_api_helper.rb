# frozen_string_literal: true

# FreeeApiHelper Concern
# Freee API連携に関する共通処理を提供
module FreeeApiHelper
  extend ActiveSupport::Concern

  # FreeeApiServiceの共通インスタンス化（DRY原則適用）
  def freee_api_service
    @freee_api_service ||= FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

  # リクエストIDの生成（共通化）
  def generate_request_id
    "REQ_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end

  # 従業員一覧の取得（エラーハンドリング込み）
  def fetch_employees
    freee_api_service.get_employees
  rescue StandardError => e
    Rails.logger.error "従業員一覧取得エラー: #{e.message}"
    []
  end

  # 従業員情報の取得と名前のマッピング
  def fetch_employee_names
    employees = fetch_employees
    employees.index_by { |emp| emp[:id] }
  rescue StandardError => e
    Rails.logger.error "従業員名マッピングエラー: #{e.message}"
    {}
  end

  # 従業員情報の取得（インスタンス変数にセット）
  def load_employees_for_view
    @employees = fetch_employees
  rescue StandardError => e
    Rails.logger.error "従業員一覧取得エラー: #{e.message}"
    @employees = []
  end

  # 従業員名のマッピング（インスタンス変数にセット）
  def load_employee_names_for_view
    @employee_names = fetch_employee_names
  rescue StandardError => e
    Rails.logger.error "従業員名マッピングエラー: #{e.message}"
    @employee_names = {}
  end
end
