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
        # 共通サービスを使用してシフト交代リクエストを承認
        shift_exchange_service = ShiftExchangeService.new
        result = shift_exchange_service.approve_exchange_request(request_id, current_employee_id)
        
        if result[:success]
          flash[:success] = result[:message]
        else
          flash[:error] = result[:message]
        end
        
      elsif request_type == 'addition'
        # 共通サービスを使用してシフト追加リクエストを承認
        shift_addition_service = ShiftAdditionService.new
        result = shift_addition_service.approve_addition_request(request_id, current_employee_id)
        
        if result[:success]
          flash[:success] = result[:message]
        else
          flash[:error] = result[:message]
        end
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
        # 共通サービスを使用してシフト交代リクエストを拒否
        shift_exchange_service = ShiftExchangeService.new
        result = shift_exchange_service.reject_exchange_request(request_id, current_employee_id)
        
        if result[:success]
          flash[:success] = result[:message]
        else
          flash[:error] = result[:message]
        end
        
      elsif request_type == 'addition'
        # 共通サービスを使用してシフト追加リクエストを拒否
        shift_addition_service = ShiftAdditionService.new
        result = shift_addition_service.reject_addition_request(request_id, current_employee_id)
        
        if result[:success]
          flash[:success] = result[:message]
        else
          flash[:error] = result[:message]
        end
      end
      
      redirect_to shift_approvals_path
      
    rescue => e
      Rails.logger.error "リクエスト拒否エラー: #{e.message}"
      flash[:error] = "拒否処理に失敗しました"
      redirect_to shift_approvals_path
    end
  end

  private
end