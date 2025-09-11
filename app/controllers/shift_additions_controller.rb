class ShiftAdditionsController < ApplicationController
  before_action :require_login

  # シフト追加リクエスト画面の表示（オーナーのみ）
  def new
    unless owner?
      flash[:error] = 'このページにアクセスする権限がありません'
      redirect_to dashboard_path and return
    end

    @date = params[:date] || Date.current.strftime('%Y-%m-%d')
    @start_time = params[:start] || '09:00'
    @end_time = params[:end] || '18:00'
    
    begin
      @employees = freee_api_service.get_employees
    rescue => error
      handle_api_error(error, '従業員一覧取得')
      @employees = []
    end
  end

  # シフト追加リクエストの作成
  def create
    unless owner?
      flash[:error] = 'このページにアクセスする権限がありません'
      redirect_to dashboard_path and return
    end

    begin
      # パラメータの検証
      if params[:employee_id].blank? || params[:shift_date].blank? || 
         params[:start_time].blank? || params[:end_time].blank?
        flash[:error] = "すべての項目を入力してください。"
        redirect_to new_shift_addition_path and return
      end

      # 重複チェック
      overlap_service = ShiftOverlapService.new
      overlapping_employee = overlap_service.check_addition_overlap(
        params[:employee_id],
        Date.parse(params[:shift_date]),
        Time.zone.parse(params[:start_time]),
        Time.zone.parse(params[:end_time])
      )

      if overlapping_employee
        flash[:error] = "#{overlapping_employee}は指定された時間にシフトが入っています。"
        redirect_to new_shift_addition_path and return
      end

      # シフト追加リクエストの作成
      ShiftAddition.create!(
        request_id: generate_request_id,
        requester_id: current_employee_id,
        target_employee_id: params[:employee_id],
        shift_date: Date.parse(params[:shift_date]),
        start_time: Time.zone.parse(params[:start_time]),
        end_time: Time.zone.parse(params[:end_time]),
        status: 'pending'
      )

      # 通知送信（テスト環境ではスキップ）
      unless Rails.env.test?
        EmailNotificationService.new.send_shift_addition_request(
          current_employee_id,
          params[:employee_id],
          params[:shift_date],
          params[:start_time],
          params[:end_time]
        )
      end

      flash[:notice] = "シフト追加リクエストを送信しました。"
      redirect_to shifts_path

    rescue => error
      handle_api_error(error, 'シフト追加リクエスト作成')
      flash[:error] = "リクエストの送信に失敗しました。しばらく時間をおいてから再度お試しください。"
      redirect_to new_shift_addition_path
    end
  end

  private

  # リクエストIDの生成
  def generate_request_id
    "REQ_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end
end