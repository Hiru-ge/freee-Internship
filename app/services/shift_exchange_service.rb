# frozen_string_literal: true

class ShiftExchangeService
  def initialize; end

  # シフト交代リクエストの作成（共通処理）
  def create_exchange_request(params)
    # パラメータの検証
    validation_result = validate_exchange_params(params)
    return validation_result unless validation_result[:success]

    # 重複チェック
    overlap_result = check_shift_overlap(params)
    return overlap_result unless overlap_result[:success]

    # シフトの取得または作成
    shift = find_or_create_shift(params)
    return { success: false, message: "シフトの取得に失敗しました。" } unless shift

    # 期限切れチェック：過去の日付のシフト交代依頼は不可
    return { success: false, message: "過去の日付のシフト交代依頼はできません。" } if shift.shift_date < Date.current

    # 重複チェック：同じシフトに対して同じ承認者へのpendingリクエストが存在しないか確認
    existing_requests = ShiftExchange.where(
      requester_id: params[:applicant_id],
      approver_id: overlap_result[:available_ids],
      shift_id: shift.id,
      status: "pending"
    )

    if existing_requests.any?
      existing_approver_names = existing_requests.map do |req|
        approver = Employee.find_by(employee_id: req.approver_id)
        approver&.display_name || "ID: #{req.approver_id}"
      end
      return { success: false, message: "以下の従業員には既にシフト交代依頼が存在します: #{existing_approver_names.join(', ')}" }
    end

    # シフト交代リクエストの作成
    created_requests = []
    overlap_result[:available_ids].each do |approver_id|
      exchange_request = ShiftExchange.create!(
        request_id: LineBotService.new.generate_request_id("EXCHANGE"),
        requester_id: params[:applicant_id],
        approver_id: approver_id,
        shift_id: shift.id,
        status: "pending"
      )
      created_requests << exchange_request
    end

    # 通知の送信
    send_exchange_notifications(created_requests, params)

    {
      success: true,
      created_requests: created_requests,
      overlapping_employees: overlap_result[:overlapping_names],
      message: generate_success_message(overlap_result[:overlapping_names])
    }
  rescue StandardError => e
    Rails.logger.error "シフト交代リクエスト作成エラー: #{e.message}"
    { success: false, message: "シフト交代リクエストの作成に失敗しました。" }
  end

  # シフト交代リクエストの承認
  def approve_exchange_request(request_id, approver_id)
    exchange_request = find_exchange_request(request_id)
    return { success: false, message: "シフト交代リクエストが見つかりません。" } unless exchange_request

    # 権限チェック
    return { success: false, message: "このリクエストを承認する権限がありません。" } unless exchange_request.approver_id == approver_id

    # シフトの所有者を変更
    shift = exchange_request.shift
    return { success: false, message: "シフトが削除されているため、承認できません。" } unless shift

    # シフト情報を保存（削除前に）
    shift.employee_id
    shift_date = shift.shift_date
    shift.start_time
    shift.end_time

    # シフト交代承認処理（既存シフトとの結合を考慮）
    ShiftDisplayService.process_shift_exchange_approval(approver_id, shift)

    # 関連するShiftExchangeのshift_idをnilに更新（外部キー制約を回避）
    ShiftExchange.where(shift_id: shift.id).update_all(shift_id: nil)

    # 元のシフトを削除
    shift.destroy!

    # リクエストを承認
    exchange_request.approve!

    # 他の承認者へのリクエストを拒否（shift_idがnilになった後）
    ShiftExchange.where(
      requester_id: exchange_request.requester_id,
      shift_id: nil, # shift_idがnilになったリクエストを対象
      status: "pending"
    ).where.not(id: exchange_request.id).each(&:reject!)

    # 通知の送信
    send_approval_notification(exchange_request)

    {
      success: true,
      message: "シフト交代リクエストを承認しました。",
      shift_date: shift_date&.strftime("%m/%d")
    }
  rescue StandardError => e
    Rails.logger.error "シフト交代承認エラー: #{e.message}"
    { success: false, message: "シフト交代の承認に失敗しました。" }
  end

  # シフト交代リクエストの拒否
  def reject_exchange_request(request_id, approver_id)
    exchange_request = find_exchange_request(request_id)
    return { success: false, message: "シフト交代リクエストが見つかりません。" } unless exchange_request

    # 権限チェック
    return { success: false, message: "このリクエストを拒否する権限がありません。" } unless exchange_request.approver_id == approver_id

    # 拒否処理
    exchange_request.update!(status: "rejected", responded_at: Time.current)

    # 通知の送信
    send_rejection_notification(exchange_request)

    {
      success: true,
      message: "シフト交代リクエストを拒否しました。"
    }
  rescue StandardError => e
    Rails.logger.error "シフト交代拒否エラー: #{e.message}"
    { success: false, message: "シフト交代の拒否に失敗しました。" }
  end

  # シフト交代リクエストのキャンセル
  def cancel_exchange_request(request_id, requester_id)
    exchange_request = find_exchange_request(request_id)
    return { success: false, message: "シフト交代リクエストが見つかりません。" } unless exchange_request

    # 権限チェック
    return { success: false, message: "このリクエストをキャンセルする権限がありません。" } unless exchange_request.requester_id == requester_id

    # キャンセル処理
    exchange_request.update!(status: "cancelled", responded_at: Time.current)

    {
      success: true,
      message: "シフト交代リクエストをキャンセルしました。"
    }
  rescue StandardError => e
    Rails.logger.error "シフト交代キャンセルエラー: #{e.message}"
    { success: false, message: "シフト交代のキャンセルに失敗しました。" }
  end

  private

  # パラメータの検証
  def validate_exchange_params(params)
    required_fields = %i[applicant_id shift_date start_time end_time approver_ids]

    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      return {
        success: false,
        message: "必須項目が不足しています: #{missing_fields.join(', ')}"
      }
    end

    if params[:approver_ids].empty?
      return {
        success: false,
        message: "交代を依頼する相手を選択してください。"
      }
    end

    { success: true }
  end

  # シフト重複チェック
  def check_shift_overlap(params)
    display_service = ShiftDisplayService.new
    result = display_service.get_available_and_overlapping_employees(
      params[:approver_ids],
      Date.parse(params[:shift_date]),
      Time.zone.parse(params[:start_time]),
      Time.zone.parse(params[:end_time])
    )

    if result[:available_ids].empty?
      return {
        success: false,
        message: "選択された従業員は全員、指定された時間にシフトが入っています。"
      }
    end

    { success: true, available_ids: result[:available_ids], overlapping_names: result[:overlapping_names] }
  end

  # シフトの取得または作成
  def find_or_create_shift(params)
    shift = Shift.find_by(
      employee_id: params[:applicant_id],
      shift_date: Date.parse(params[:shift_date]),
      start_time: Time.zone.parse(params[:start_time]),
      end_time: Time.zone.parse(params[:end_time])
    )

    # シフトが存在しない場合は作成
    shift ||= Shift.create!(
      employee_id: params[:applicant_id],
      shift_date: Date.parse(params[:shift_date]),
      start_time: Time.zone.parse(params[:start_time]),
      end_time: Time.zone.parse(params[:end_time])
    )

    shift
  end

  # シフト交代リクエストの検索
  def find_exchange_request(request_id)
    # IDまたはrequest_idで検索
    ShiftExchange.find_by(id: request_id) || ShiftExchange.find_by(request_id: request_id)
  end

  # 通知の送信
  def send_exchange_notifications(requests, params)
    return if Rails.env.test? || requests.empty?

    notification_service = EmailNotificationService.new
    notification_service.send_shift_exchange_request_notification(requests, params)
  end

  # 承認通知の送信
  def send_approval_notification(exchange_request)
    return if Rails.env.test?

    # shiftが削除されている場合は通知をスキップ
    return unless exchange_request.shift

    notification_service = EmailNotificationService.new
    notification_service.send_shift_exchange_approval_notification(exchange_request)
  end

  # 拒否通知の送信
  def send_rejection_notification(exchange_request)
    return if Rails.env.test?

    # shiftが削除されている場合は通知をスキップ
    return unless exchange_request.shift

    notification_service = EmailNotificationService.new
    notification_service.send_shift_exchange_rejection_notification(exchange_request)
  end

  # 成功メッセージの生成
  def generate_success_message(overlapping_employees)
    if overlapping_employees.any?
      "リクエストを送信しました。一部の従業員は指定時間にシフトが入っているため、依頼可能な従業員のみに送信されました。"
    else
      "リクエストを送信しました。承認をお待ちください。"
    end
  end
end
