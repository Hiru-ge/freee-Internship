class ShiftApprovalsController < ApplicationController
  include InputValidation
  include AuthorizationCheck
  
  before_action :require_login
  
  # リクエスト一覧表示
  def index
    @employee_id = current_employee_id
    
    # 自分宛のリクエストを取得
    @shift_exchanges = ShiftExchange.for_approver(@employee_id).pending.includes(:shift)
    @shift_additions = ShiftAddition.for_employee(@employee_id).pending
    
    # freee APIから従業員情報を取得
    begin
      freee_service = freee_api_service
      @employees = freee_service.get_employees
      @employee_names = @employees.index_by { |emp| emp[:id] }
    rescue => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
      @employee_names = {}
    end
  end
  
  # シフト交代リクエストの承認
  def approve
    begin
      request_id = params[:request_id]
      request_type = params[:request_type]
      
      # 権限チェック
      return unless check_shift_approval_authorization(request_id, request_type)
      
      if request_type == 'exchange'
        # シフト交代リクエストの承認
        shift_exchange = ShiftExchange.find_by(request_id: request_id, approver_id: current_employee_id)
        
        unless shift_exchange
          flash[:error] = "リクエストが見つかりません"
          redirect_to shift_approvals_path and return
        end
        
        # シフトが削除されている場合は拒否
        unless shift_exchange.shift
          flash[:error] = "シフトが削除されているため、承認できません"
          redirect_to shift_approvals_path and return
        end
        
        # シフトの交代を実行
        if shift_exchange.shift
          # 元のシフト情報を保存
          original_shift = shift_exchange.shift
          
          # 関連するShiftExchangeのshift_idをnilに設定（外部キー制約を回避）
          ShiftExchange.where(shift_id: original_shift.id).update_all(shift_id: nil)
          
          # シフト交代承認処理（既存シフトとの結合を考慮）
          ShiftMergeService.process_shift_exchange_approval(current_employee_id, original_shift)
          
          # 元のシフトを削除
          original_shift.destroy!
        end
        
        # リクエストを承認
        shift_exchange.approve!
        
        # 他の承認者へのリクエストを拒否（shift_idがnilになった後）
        ShiftExchange.where(
          requester_id: shift_exchange.requester_id,
          shift_id: nil,  # shift_idがnilになったリクエストを対象
          status: 'pending'
        ).where.not(id: shift_exchange.id).each do |other_request|
          other_request.reject!
        end

        # 承認メール通知を送信
        send_exchange_approval_notification(shift_exchange)
        
        flash[:success] = "シフト交代リクエストを承認しました"
        
      elsif request_type == 'addition'
        # シフト追加リクエストの承認
        shift_addition = ShiftAddition.find_by(request_id: request_id, target_employee_id: current_employee_id)
        
        unless shift_addition
          flash[:error] = "リクエストが見つかりません"
          redirect_to shift_approvals_path and return
        end
        
        # シフト追加承認処理（既存シフトとの結合を考慮）
        new_shift_data = {
          shift_date: shift_addition.shift_date,
          start_time: shift_addition.start_time,
          end_time: shift_addition.end_time,
          requester_id: shift_addition.requester_id
        }
        ShiftMergeService.process_shift_addition_approval(current_employee_id, new_shift_data)
        
        # リクエストを承認
        shift_addition.approve!

        # 承認メール通知を送信
        send_addition_approval_notification(shift_addition)
        
        flash[:success] = "シフト追加リクエストを承認しました"
      end
      
      redirect_to shift_approvals_path
      
    rescue => e
      Rails.logger.error "リクエスト承認エラー: #{e.message}"
      flash[:error] = "承認処理に失敗しました"
      redirect_to shift_approvals_path
    end
  end
  
  # リクエストの拒否
  def reject
    begin
      request_id = params[:request_id]
      request_type = params[:request_type]
      
      # 権限チェック
      return unless check_shift_approval_authorization(request_id, request_type)
      
      if request_type == 'exchange'
        # シフト交代リクエストの拒否
        shift_exchange = ShiftExchange.find_by(request_id: request_id, approver_id: current_employee_id)
        
        unless shift_exchange
          flash[:error] = "リクエストが見つかりません"
          redirect_to shift_approvals_path and return
        end
        
        shift_exchange.reject!

        # 否認メール通知を送信（全員否認の場合のみ）
        send_exchange_denial_notification_if_all_denied(shift_exchange)
        
        flash[:success] = "シフト交代リクエストを拒否しました"
        
      elsif request_type == 'addition'
        # シフト追加リクエストの拒否
        shift_addition = ShiftAddition.find_by(request_id: request_id, target_employee_id: current_employee_id)
        
        unless shift_addition
          flash[:error] = "リクエストが見つかりません"
          redirect_to shift_approvals_path and return
        end
        
        shift_addition.reject!

        # 否認メール通知を送信
        send_addition_denial_notification(shift_addition)
        
        flash[:success] = "シフト追加リクエストを拒否しました"
      end
      
      redirect_to shift_approvals_path
      
    rescue => e
      Rails.logger.error "リクエスト拒否エラー: #{e.message}"
      flash[:error] = "拒否処理に失敗しました"
      redirect_to shift_approvals_path
    end
  end

  private

  # シフト交代承認のメール通知を送信
  def send_exchange_approval_notification(shift_exchange)
    begin
      # GAS時代のgetEmployeesを再現したAPIから従業員情報を取得
      freee_service = freee_api_service
      all_employees = freee_service.get_employees_full
      
      # 申請者・承認者情報を検索
      requester_info = all_employees.find { |emp| emp['id'].to_s == shift_exchange.requester_id.to_s }
      approver_info = all_employees.find { |emp| emp['id'].to_s == shift_exchange.approver_id.to_s }
      return unless requester_info&.dig('email') && approver_info

      ShiftMailer.shift_exchange_approved(
        requester_info['email'],
        requester_info['display_name'],
        approver_info['display_name'],
        shift_exchange.shift.shift_date,
        shift_exchange.shift.start_time,
        shift_exchange.shift.end_time
      ).deliver_now
    rescue => e
      Rails.logger.error "シフト交代承認メール送信エラー: #{e.message}"
    end
  end

  # シフト交代否認のメール通知を送信（全員否認の場合のみ）
  def send_exchange_denial_notification_if_all_denied(shift_exchange)
    begin
      # 同じリクエストIDの他のリクエストも全て否認されているかチェック
      all_requests = ShiftExchange.where(
        requester_id: shift_exchange.requester_id,
        shift_id: shift_exchange.shift_id
      )
      
      all_denied = all_requests.all? { |req| req.status == 'rejected' }
      
      if all_denied
        # GAS時代のgetEmployeesを再現したAPIから従業員情報を取得
        freee_service = freee_api_service
        all_employees = freee_service.get_employees_full
        
        # 申請者情報を検索
        requester_info = all_employees.find { |emp| emp['id'].to_s == shift_exchange.requester_id.to_s }
        return unless requester_info&.dig('email')

        ShiftMailer.shift_exchange_denied(
          requester_info['email'],
          requester_info['display_name']
        ).deliver_now
      end
    rescue => e
      Rails.logger.error "シフト交代否認メール送信エラー: #{e.message}"
    end
  end

  # シフト追加承認のメール通知を送信
  def send_addition_approval_notification(shift_addition)
    begin
      email_service = EmailNotificationService.new
      # 従業員情報を取得
      target_employee = Employee.find_by(employee_id: shift_addition.target_employee_id)
      
      email_service.send_shift_addition_approved(
        shift_addition.requester_id,
        target_employee&.display_name || "対象従業員",
        shift_addition.shift_date,
        shift_addition.start_time,
        shift_addition.end_time
      )
    rescue => e
      Rails.logger.error "シフト追加承認メール送信エラー: #{e.message}"
    end
  end

  # シフト追加否認のメール通知を送信
  def send_addition_denial_notification(shift_addition)
    begin
      email_service = EmailNotificationService.new
      # 従業員情報を取得
      target_employee = Employee.find_by(employee_id: shift_addition.target_employee_id)
      
      email_service.send_shift_addition_denied(
        shift_addition.requester_id,
        target_employee&.display_name || "対象従業員"
      )
    rescue => e
      Rails.logger.error "シフト追加否認メール送信エラー: #{e.message}"
    end
  end
end