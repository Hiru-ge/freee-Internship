# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_email_authentication
    before_action :require_login
  end

  private

  def require_email_authentication
    return if skip_email_authentication?
    return if session[:email_authenticated] && !email_auth_expired?

    redirect_to root_path, alert: "メールアドレス認証が必要です"
    nil
  end

  def skip_email_authentication?
    controller_name == "access_control" || Rails.env.test?
  end

  def email_auth_expired?
    return true unless session[:email_auth_expires_at]

    Time.current > Time.parse(session[:email_auth_expires_at].to_s)
  end

  def require_login
    return if session[:authenticated] && session[:employee_id] && !session_expired?

    if session_expired?
      clear_session
      redirect_to login_path, alert: "セッションがタイムアウトしました。再度ログインしてください。"
    else
      redirect_to login_path, alert: "ログインが必要です"
    end
  end

  # セッション管理機能
  def session_expired?
    return false unless session[:created_at]

    session_created_at = Time.at(session[:created_at])
    session_created_at < AppConstants::SESSION_TIMEOUT_HOURS.hours.ago
  end

  def clear_session
    session[:authenticated] = nil
    session[:employee_id] = nil
    session[:created_at] = nil
  end

  def set_header_variables
    if session[:authenticated] && session[:employee_id]
      @employee_name = get_employee_name
      @is_owner = owner?
    else
      @employee_name = nil
      @is_owner = false
    end
  end

  def get_employee_name
    employee_info = freee_api_service.get_employee_info(current_employee_id)
    employee_info["display_name"] || "Unknown"
  rescue StandardError => e
    Rails.logger.error "Failed to get employee name: #{e.message}"
    "Unknown"
  end

  def current_employee
    @current_employee ||= Employee.find_by(employee_id: session[:employee_id])
  end

  def current_employee_id
    session[:employee_id]
  end

  def owner?
    current_employee&.owner?
  end

  def check_owner_permission(redirect_path = dashboard_path, error_message = "このページにアクセスする権限がありません")
    unless owner?
      flash[:error] = error_message
      redirect_to redirect_path
      return false
    end
    true
  end

  def require_owner!
    raise AuthorizationError, "オーナー権限が必要です" unless owner?
  end

  def check_shift_addition_authorization
    unless owner?
      flash[:error] = "シフト追加リクエストはオーナーのみが作成できます"
      redirect_to dashboard_path
      return false
    end
    true
  end

  def check_shift_approval_authorization(request_id, request_type)
    case request_type
    when "exchange"
      shift_exchange = ShiftExchange.find_by(request_id: request_id)
      unless shift_exchange
        flash[:error] = "リクエストが見つかりません"
        redirect_to shift_approvals_path
        return false
      end

      # 承認者として指定されているかチェック
      unless shift_exchange.approver_id == current_employee_id
        flash[:error] = "このリクエストを承認する権限がありません"
        redirect_to shift_approvals_path
        return false
      end

    when "addition"
      shift_addition = ShiftAddition.find_by(request_id: request_id)
      unless shift_addition
        flash[:error] = "リクエストが見つかりません"
        redirect_to shift_approvals_path
        return false
      end

      # 対象従業員として指定されているかチェック
      unless shift_addition.target_employee_id == current_employee_id
        flash[:error] = "このリクエストを承認する権限がありません"
        redirect_to shift_approvals_path
        return false
      end

    when "deletion"
      shift_deletion = ShiftDeletion.find_by(request_id: request_id)
      unless shift_deletion
        flash[:error] = "リクエストが見つかりません"
        redirect_to shift_approvals_path
        return false
      end

      # オーナーのみが承認可能
      unless owner?
        flash[:error] = "このリクエストを承認する権限がありません"
        redirect_to shift_approvals_path
        return false
      end

    else
      flash[:error] = "無効なリクエストタイプです"
      redirect_to shift_approvals_path
      return false
    end

    true
  end

  # カスタム認可エラー
  class AuthorizationError < StandardError; end


  def check_shift_ownership(shift_id, redirect_path = shifts_path)
    shift = Shift.find_by(id: shift_id)

    unless shift
      flash[:error] = "シフトが見つかりません"
      redirect_to redirect_path
      return false
    end

    # シフトの担当者またはオーナーである必要がある
    unless shift.employee_id == current_employee_id || owner?
      flash[:error] = "このシフトを操作する権限がありません"
      redirect_to redirect_path
      return false
    end

    true
  end

  def check_shift_exchange_ownership(request_id, redirect_path = shift_exchanges_path)
    shift_exchange = ShiftExchange.find_by(request_id: request_id)

    unless shift_exchange
      flash[:error] = "リクエストが見つかりません"
      redirect_to redirect_path
      return false
    end

    # 申請者または承認者のみが操作可能
    unless shift_exchange.requester_id == current_employee_id ||
           shift_exchange.approver_id == current_employee_id ||
           owner?
      flash[:error] = "このリクエストを操作する権限がありません"
      redirect_to redirect_path
      return false
    end

    true
  end

  def check_resource_ownership(resource, owner_field = :employee_id, redirect_path = dashboard_path)
    # リソースの所有権をチェック
    unless resource.send(owner_field) == current_employee_id.to_s
      flash[:error] = "このリソースにアクセスする権限がありません"
      redirect_to redirect_path
      return false
    end
    true
  end

  def check_employee_permission(redirect_path = auth_login_path)
    # 従業員権限をチェック（基本的には認証済みユーザー）
    unless current_employee
      flash[:error] = "ログインが必要です"
      redirect_to redirect_path
      return false
    end
    true
  end

  def check_parameter_tampering(redirect_path = dashboard_path)
    # パラメータの改ざんをチェック
    case controller_name
    when "shift_exchanges"
      check_shift_exchange_parameter_tampering(redirect_path)
    when "shift_additions"
      check_shift_addition_parameter_tampering(redirect_path)
    else
      true
    end
  end

  def check_shift_exchange_parameter_tampering(redirect_path = shift_exchanges_path)
    # シフト交代リクエストのパラメータ改ざんチェック
    if params[:applicant_id] && params[:applicant_id] != current_employee_id.to_s
      flash[:error] = "不正なパラメータが検出されました"
      redirect_to redirect_path
      return false
    end
    true
  end

  def check_shift_addition_parameter_tampering(redirect_path = shift_additions_path)
    # シフト追加リクエストのパラメータ改ざんチェック
    # オーナーのみがシフト追加可能
    unless owner?
      flash[:error] = "不正なパラメータが検出されました"
      redirect_to redirect_path
      return false
    end
    true
  end

  def check_session_manipulation(redirect_path = auth_login_path)
    # セッションの改ざんをチェック
    unless session[:authenticated] && session[:employee_id]
      flash[:error] = "セッションが無効です"
      redirect_to redirect_path
      return false
    end
    true
  end

  def check_privilege_escalation(redirect_path = dashboard_path)
    # 権限昇格攻撃をチェック
    case controller_name
    when "shift_additions"
      # シフト追加はオーナーのみ可能
      unless owner?
        flash[:error] = "権限昇格攻撃が検出されました"
        redirect_to redirect_path
        return false
      end
    when "shift_approvals"
      # 承認権限のチェック
      unless check_approval_permission
        flash[:error] = "権限昇格攻撃が検出されました"
        redirect_to redirect_path
        return false
      end
    end
    true
  end

  def check_approval_permission
    # 承認権限の詳細チェック
    request_id = params[:request_id]
    request_type = params[:request_type]

    case request_type
    when "exchange"
      shift_exchange = ShiftExchange.find_by(request_id: request_id)
      return false unless shift_exchange

      shift_exchange.approver_id == current_employee_id
    when "addition"
      shift_addition = ShiftAddition.find_by(request_id: request_id)
      return false unless shift_addition

      shift_addition.target_employee_id == current_employee_id.to_s
    when "deletion"
      # 欠勤申請はオーナーのみ承認可能
      owner?
    else
      false
    end
  end
end
