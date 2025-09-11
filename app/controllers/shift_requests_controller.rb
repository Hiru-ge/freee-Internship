class ShiftRequestsController < ApplicationController
  before_action :require_login
  
  # シフト交代リクエストフォーム
  def new
    @employee_id = current_employee_id
    @applicant_id = params[:applicant_id] || @employee_id
    @date = params[:date]
    @start = params[:start]
    @end = params[:end]
    
    # freee APIから従業員一覧を取得
    begin
      freee_service = freee_api_service
      @employees = freee_service.get_employees
    rescue => e
      handle_api_error(e, '従業員一覧取得')
      @employees = []
    end
  end
  
  # シフト交代リクエスト作成
  def create
    begin
      # パラメータの取得
      request_params = extract_request_params
      
      # バリデーション
      validation_result = validate_exchange_request(request_params)
      return if validation_result[:redirect]
      
      # シフト重複チェック
      overlap_result = check_shift_overlap(request_params)
      return if overlap_result[:redirect]
      
      # シフト交代リクエストを作成
      create_exchange_requests(request_params, overlap_result[:available_approver_ids])
      
      # メール通知を送信
      send_exchange_request_notifications(
        request_params[:applicant_id], 
        overlap_result[:available_approver_ids], 
        request_params[:shift_date], 
        request_params[:start_time], 
        request_params[:end_time]
      )
      
      # 成功メッセージを設定
      set_success_message(overlap_result[:overlapping_employees])
      redirect_to shifts_path
      
    rescue => e
      handle_api_error(e, 'シフト交代リクエスト作成')
      flash[:error] = "リクエストの送信に失敗しました。しばらく時間をおいてから再度お試しください。"
      redirect_to new_shift_request_path
    end
  end
  
  # シフト追加リクエストフォーム
  def new_addition
    unless owner?
      flash[:error] = "権限がありません"
      redirect_to shifts_path and return
    end
    
    # freee APIから従業員一覧を取得
    begin
      freee_service = freee_api_service
      @employees = freee_service.get_employees
    rescue => e
      handle_api_error(e, '従業員一覧取得')
      @employees = []
    end
  end
  
  # シフト追加リクエスト作成
  def create_addition
    unless owner?
      flash[:error] = "権限がありません"
      redirect_to shifts_path and return
    end
    
    begin
      # パラメータの取得
      target_employee_id = params[:target_employee_id]
      shift_date = params[:shift_date]
      start_time = params[:start_time]
      end_time = params[:end_time]
      
      # バリデーション
      if target_employee_id.blank?
        flash[:error] = "対象従業員を選択してください"
        redirect_to new_shift_addition_path and return
      end

      # シフト重複チェック
      overlap_service = ShiftOverlapService.new
      overlapping_employee = overlap_service.check_addition_overlap(target_employee_id, shift_date, start_time, end_time)
      
      if overlapping_employee
        flash[:error] = "#{overlapping_employee}さんは、その時間に既に別のシフトが入っています。"
        redirect_to new_shift_addition_path and return
      end

      # 時間の妥当性チェック
      if start_time >= end_time
        flash[:error] = "終了時間は開始時間より後である必要があります"
        redirect_to new_shift_addition_path and return
      end

      # リクエストIDを生成
      request_id = SecureRandom.uuid
      
      # シフト追加リクエストを作成
      ShiftAddition.create!(
        request_id: request_id,
        target_employee_id: target_employee_id,
        shift_date: shift_date,
        start_time: start_time,
        end_time: end_time,
        requester_id: current_employee_id,
        status: 'pending'
      )

      # メール通知を送信
      send_addition_request_notification(target_employee_id, shift_date, start_time, end_time)
      
      flash[:success] = "シフト追加リクエストを送信しました"
      redirect_to shifts_path
      
    rescue => e
      Rails.logger.error "シフト追加リクエスト作成エラー: #{e.message}"
      flash[:error] = "リクエストの送信に失敗しました"
      redirect_to new_shift_addition_path
    end
  end

  private

  # リクエストパラメータを抽出
  def extract_request_params
    {
      applicant_id: params[:applicant_id],
      approver_ids: params[:approver_ids] || [],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time]
    }
  end

  # シフト交代リクエストのバリデーション
  def validate_exchange_request(params)
    if params[:approver_ids].empty?
      flash[:error] = "交代を依頼する相手を選択してください。複数の人に同時に依頼することも可能です。"
      redirect_to new_shift_request_path
      return { redirect: true }
    end

    unless Shift.exists?(
      employee_id: params[:applicant_id], 
      shift_date: params[:shift_date], 
      start_time: params[:start_time], 
      end_time: params[:end_time]
    )
      flash[:error] = "指定されたシフトが見つかりません。シフト表を確認して、正しい日時を選択してください。"
      redirect_to new_shift_request_path
      return { redirect: true }
    end

    { redirect: false }
  end

  # シフト重複チェック
  def check_shift_overlap(params)
    overlap_service = ShiftOverlapService.new
    result = overlap_service.get_available_and_overlapping_employees(
      params[:approver_ids], 
      params[:shift_date], 
      params[:start_time], 
      params[:end_time]
    )
    
    if result[:available_ids].empty?
      flash[:error] = "選択した相手は全員、その時間に既にシフトが入っています。別の時間帯を選択するか、他の人に依頼してください。"
      redirect_to new_shift_request_path
      return { redirect: true }
    end

    { 
      redirect: false, 
      available_approver_ids: result[:available_ids], 
      overlapping_employees: result[:overlapping_names] 
    }
  end

  # シフト交代リクエストを作成
  def create_exchange_requests(params, available_approver_ids)
    target_shift = Shift.find_by(
      employee_id: params[:applicant_id],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time]
    )
    
    available_approver_ids.each do |approver_id|
      request_id = SecureRandom.uuid
      
      ShiftExchange.create!(
        request_id: request_id,
        requester_id: params[:applicant_id],
        approver_id: approver_id,
        shift_id: target_shift.id,
        status: 'pending'
      )
    end
  end

  # 成功メッセージを設定
  def set_success_message(overlapping_employees)
    if overlapping_employees.any?
      flash[:success] = "シフト交代リクエストを送信しました。以下の人は既にシフトが入っているため依頼できませんでした: #{overlapping_employees.join(', ')}"
    else
      flash[:success] = "シフト交代リクエストを送信しました。承認者にメール通知が送信されました。"
    end
  end

  # シフト交代依頼のメール通知を送信
  def send_exchange_request_notifications(applicant_id, approver_ids, shift_date, start_time, end_time)
    email_service = EmailNotificationService.new
    email_service.send_shift_exchange_request(applicant_id, approver_ids, shift_date, start_time, end_time)
  end

  # シフト追加依頼のメール通知を送信
  def send_addition_request_notification(target_employee_id, shift_date, start_time, end_time)
    email_service = EmailNotificationService.new
    email_service.send_shift_addition_request(target_employee_id, shift_date, start_time, end_time)
  end
end