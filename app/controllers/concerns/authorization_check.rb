# frozen_string_literal: true

module AuthorizationCheck
  extend ActiveSupport::Concern

  # 再利用可能な権限チェック関数

  def check_owner_permission(redirect_path = dashboard_path)
    unless owner?
      flash[:error] = "このページにアクセスする権限がありません"
      redirect_to redirect_path
      return false
    end
    true
  end

  def check_shift_addition_authorization(redirect_path = dashboard_path)
    check_owner_permission(redirect_path)
  end

  def check_shift_approval_authorization(request_id, request_type, redirect_path = shift_approvals_path)
    case request_type
    when "exchange"
      check_shift_exchange_approval_ownership(request_id, redirect_path)
    when "addition"
      check_shift_addition_approval_ownership(request_id, redirect_path)
    else
      flash[:error] = "無効なリクエストタイプです"
      redirect_to redirect_path
      false
    end
  end

  def check_shift_exchange_approval_ownership(request_id, redirect_path = shift_approvals_path)
    shift_exchange = ShiftExchange.find_by(request_id: request_id)

    unless shift_exchange
      flash[:error] = "リクエストが見つかりません"
      redirect_to redirect_path
      return false
    end

    # 承認者は交代先のシフトの担当者である必要がある
    unless shift_exchange.approver_id == current_employee_id
      flash[:error] = "このリクエストを承認する権限がありません"
      redirect_to redirect_path
      return false
    end

    true
  end

  def check_shift_addition_approval_ownership(request_id, redirect_path = shift_approvals_path)
    shift_addition = ShiftAddition.find_by(request_id: request_id)

    unless shift_addition
      flash[:error] = "リクエストが見つかりません"
      redirect_to redirect_path
      return false
    end

    # 承認者は対象従業員である必要がある
    unless shift_addition.target_employee_id == current_employee_id
      flash[:error] = "このリクエストを承認する権限がありません"
      redirect_to redirect_path
      return false
    end

    true
  end

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

  private

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
    else
      false
    end
  end
end
