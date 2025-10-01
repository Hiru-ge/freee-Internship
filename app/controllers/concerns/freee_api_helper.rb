# frozen_string_literal: true

module FreeeApiHelper
  extend ActiveSupport::Concern

  def freee_api_service
    @freee_api_service ||= FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

  def generate_request_id
    "REQ_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end

  def fetch_employees
    freee_api_service.get_employees
  rescue StandardError => e
    Rails.logger.error "従業員一覧取得エラー: #{e.message}"
    []
  end

  def fetch_employee_names
    employees = fetch_employees
    employees.index_by { |emp| emp[:id] }
  rescue StandardError => e
    Rails.logger.error "従業員名マッピングエラー: #{e.message}"
    {}
  end

  def load_employees_for_view
    @employees = fetch_employees
  rescue StandardError => e
    Rails.logger.error "従業員一覧取得エラー: #{e.message}"
    @employees = []
  end

  def load_employee_names_for_view
    @employee_names = fetch_employee_names
  rescue StandardError => e
    Rails.logger.error "従業員名マッピングエラー: #{e.message}"
    @employee_names = {}
  end
end
