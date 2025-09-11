class ShiftExchangesController < ApplicationController
  before_action :require_login

  # シフト交代リクエスト画面の表示
  def new
    @employee_id = current_employee_id
    @date = params[:date] || Date.current.strftime('%Y-%m-%d')
    @start_time = params[:start] || '09:00'
    @end_time = params[:end] || '18:00'
    
    begin
      @employees = freee_api_service.get_employees
      @applicant_id = @employee_id
    rescue => error
      handle_api_error(error, '従業員一覧取得')
      @employees = []
    end
  end

  # シフト交代リクエストの作成
  def create
    begin
      request_params = extract_request_params

      validation_result = validate_exchange_request(request_params)
      return if validation_result[:redirect]

      overlap_result = check_shift_overlap(request_params)
      return if overlap_result[:redirect]

      create_exchange_requests(request_params, overlap_result[:available_ids])

      send_exchange_request_notifications(
        request_params[:applicant_id],
        overlap_result[:available_ids],
        request_params[:shift_date],
        request_params[:start_time],
        request_params[:end_time]
      )

      set_success_message(overlap_result[:overlapping_names])
      redirect_to shifts_path

    rescue => error
      handle_api_error(error, 'シフト交代リクエスト作成')
      flash[:error] = "リクエストの送信に失敗しました。しばらく時間をおいてから再度お試しください。"
      redirect_to new_shift_exchange_path
    end
  end

  private

  # リクエストパラメータの抽出
  def extract_request_params
    {
      applicant_id: params[:applicant_id],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time],
      approver_ids: params[:approver_ids] || []
    }
  end

  # シフト交代リクエストの検証
  def validate_exchange_request(params)
    if params[:applicant_id].blank? || params[:shift_date].blank? || 
       params[:start_time].blank? || params[:end_time].blank?
      flash[:error] = "すべての項目を入力してください。"
      redirect_to new_shift_exchange_path
      return { redirect: true }
    end

    if params[:approver_ids].blank?
      flash[:error] = "交代を依頼する相手を選択してください。"
      redirect_to new_shift_exchange_path
      return { redirect: true }
    end

    { redirect: false }
  end

  # シフト重複チェック
  def check_shift_overlap(params)
    overlap_service = ShiftOverlapService.new
    result = overlap_service.get_available_and_overlapping_employees(
      params[:approver_ids],
      Date.parse(params[:shift_date]),
      Time.zone.parse(params[:start_time]),
      Time.zone.parse(params[:end_time])
    )


    if result[:available_ids].empty?
      flash[:error] = "選択された従業員は全員、指定された時間にシフトが入っています。"
      redirect_to new_shift_exchange_path
      return { redirect: true }
    end

    result
  end

  # シフト交代リクエストの作成
  def create_exchange_requests(params, available_approver_ids)
    # 申請者のシフトを取得または作成
    shift = find_or_create_shift(params)

    return unless shift

    available_approver_ids.each do |approver_id|
      ShiftExchange.create!(
        request_id: generate_request_id,
        requester_id: params[:applicant_id],
        approver_id: approver_id,
        shift_id: shift.id,
        status: 'pending'
      )
    end
  end

  # シフトの取得または作成
  def find_or_create_shift(params)
    shift = Shift.find_by(
      employee_id: params[:applicant_id],
      shift_date: Date.parse(params[:shift_date]),
      start_time: Time.zone.parse(params[:start_time]),
      end_time: Time.zone.parse(params[:end_time])
    )

    # シフトが存在しない場合は作成（テスト用）
    unless shift
      shift = Shift.create!(
        employee_id: params[:applicant_id],
        shift_date: Date.parse(params[:shift_date]),
        start_time: Time.zone.parse(params[:start_time]),
        end_time: Time.zone.parse(params[:end_time])
      )
    end

    shift
  end

  # リクエストIDの生成
  def generate_request_id
    "REQ_#{Time.current.to_f}_#{SecureRandom.hex(4)}"
  end

  # 成功メッセージの設定
  def set_success_message(overlapping_employees)
    if overlapping_employees.any?
      flash[:notice] = "リクエストを送信しました。一部の従業員は指定時間にシフトが入っているため、利用可能な従業員のみに送信されました。"
    else
      flash[:notice] = "リクエストを送信しました。承認をお待ちください。"
    end
  end

  # シフト交代リクエスト通知の送信
  def send_exchange_request_notifications(applicant_id, approver_ids, shift_date, start_time, end_time)
    # テスト環境ではメール送信をスキップ
    return if Rails.env.test?
    
    EmailNotificationService.new.send_shift_exchange_request(
      applicant_id,
      approver_ids,
      shift_date,
      start_time,
      end_time
    )
  end
end