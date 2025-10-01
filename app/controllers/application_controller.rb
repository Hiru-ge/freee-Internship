# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ErrorHandler
  include Authentication
  include Security
  include FreeeApiHelper
  include ServiceResponseHandler

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # セッション管理
  before_action :set_header_variables

  # エラーハンドリングの統一
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  helper_method :current_employee, :current_employee_id, :owner?, :freee_api_service

  private

  # 共通エラーハンドリング（DRY原則適用）
  # ErrorHandlerモジュールのhandle_api_errorを使用
  def handle_api_error(error, context = "")
    super
  end

  # エラーハンドリングメソッド
  def handle_record_not_found(exception)
    handle_validation_error("record", "指定されたデータが見つかりません")
  end

  def handle_record_invalid(exception)
    handle_validation_error("record", "データの保存に失敗しました")
  end

  def handle_parameter_missing(exception)
    handle_validation_error("parameter", "必要なパラメータが不足しています")
  end
end
