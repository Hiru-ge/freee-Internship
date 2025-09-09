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
      freee_service = FreeeApiService.new(ENV['FREEE_ACCESS_TOKEN'], ENV['FREEE_COMPANY_ID'])
      @employees = freee_service.get_employees
    rescue => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
      @employees = []
    end
  end
  
  # シフト交代リクエスト作成
  def create
    begin
      # パラメータの取得
      applicant_id = params[:applicant_id]
      approver_ids = params[:approver_ids] || []
      shift_date = params[:shift_date]
      start_time = params[:start_time]
      end_time = params[:end_time]
      
      # バリデーション
      if approver_ids.empty?
        flash[:error] = "交代を依頼する相手を選択してください"
        redirect_to new_shift_request_path and return
      end

      # シフト重複チェック
      overlap_service = ShiftOverlapService.new
      overlapping_employees = overlap_service.check_exchange_overlap(approver_ids, shift_date, start_time, end_time)
      
      if overlapping_employees.any?
        flash[:error] = "選択した相手は全員、その時間に既にシフトが入っています。"
        redirect_to new_shift_request_path and return
      end

      # 申請者自身のシフト存在チェック
      unless Shift.exists?(employee_id: applicant_id, shift_date: shift_date, start_time: start_time, end_time: end_time)
        flash[:error] = "指定されたシフトが見つかりません。"
        redirect_to new_shift_request_path and return
      end
      
      # 対象シフトを検索
      target_shift = Shift.find_by(
        employee_id: applicant_id,
        shift_date: shift_date,
        start_time: start_time,
        end_time: end_time
      )
      
      # 各承認者に対してリクエストを作成
      approver_ids.each do |approver_id|
        request_id = SecureRandom.uuid
        
        ShiftExchange.create!(
          request_id: request_id,
          requester_id: applicant_id,
          approver_id: approver_id,
          shift_id: target_shift.id,
          status: 'pending'
        )
      end

      # メール通知を送信
      send_exchange_request_notifications(applicant_id, approver_ids, shift_date, start_time, end_time)
      
      flash[:success] = "シフト交代リクエストを送信しました"
      redirect_to shifts_path
      
    rescue => e
      Rails.logger.error "シフト交代リクエスト作成エラー: #{e.message}"
      flash[:error] = "リクエストの送信に失敗しました"
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
      freee_service = FreeeApiService.new(ENV['FREEE_ACCESS_TOKEN'], ENV['FREEE_COMPANY_ID'])
      @employees = freee_service.get_employees
    rescue => e
      Rails.logger.error "従業員一覧取得エラー: #{e.message}"
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

  # シフト交代依頼のメール通知を送信
  def send_exchange_request_notifications(applicant_id, approver_ids, shift_date, start_time, end_time)
    begin
      # 申請者情報を取得
      applicant = Employee.find_by(employee_id: applicant_id)
      return unless applicant&.email

      approver_ids.each do |approver_id|
        approver = Employee.find_by(employee_id: approver_id)
        next unless approver&.email

        ShiftMailer.shift_exchange_request(
          approver.email,
          approver.display_name,
          applicant.display_name,
          shift_date,
          start_time,
          end_time
        ).deliver_now
      end
    rescue => e
      Rails.logger.error "シフト交代依頼メール送信エラー: #{e.message}"
    end
  end

  # シフト追加依頼のメール通知を送信
  def send_addition_request_notification(target_employee_id, shift_date, start_time, end_time)
    begin
      target_employee = Employee.find_by(employee_id: target_employee_id)
      return unless target_employee&.email

      ShiftMailer.shift_addition_request(
        target_employee.email,
        target_employee.display_name,
        shift_date,
        start_time,
        end_time
      ).deliver_now
    rescue => e
      Rails.logger.error "シフト追加依頼メール送信エラー: #{e.message}"
    end
  end
end