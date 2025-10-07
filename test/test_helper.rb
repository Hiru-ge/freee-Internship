# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["OWNER_EMPLOYEE_ID"] ||= "3313254"
require_relative "../config/environment"
require "rails/test_help"

# FreeeApiServiceのグローバルモック
class FreeeApiService
  def initialize(access_token = nil, company_id = nil)
    @access_token = access_token
    @company_id = company_id
  end

  def get_employee_info(employee_id)
    # テスト用の従業員情報を返す
    case employee_id
    when "3313254"
      { "id" => "3313254", "display_name" => "店長太郎", "email" => "owner@example.com" }
    when "3316120"
      { "id" => "3316120", "display_name" => "テスト太郎", "email" => "test1@example.com" }
    when "3317741"
      { "id" => "3317741", "display_name" => "テスト次郎", "email" => "test2@example.com" }
    else
      nil
    end
  end

  def get_employees
    [
      { "id" => "3313254", "display_name" => "店長太郎", "email" => "owner@example.com" },
      { "id" => "3316120", "display_name" => "テスト太郎", "email" => "test1@example.com" },
      { "id" => "3317741", "display_name" => "テスト次郎", "email" => "test2@example.com" }
    ]
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # SQLite3の並列実行問題を回避するため、並列実行を無効化
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # freee APIのモック用ヘルパー
    def mock_freee_api_service
      FreeeApiService.new
    end

    # ログインヘルパー
    def sign_in_as(employee)
      post login_url, params: {
        employee_id: employee.employee_id,
        password: "password123"
      }
      follow_redirect! if response.redirect?
    end
  end
end
