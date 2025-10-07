class ShiftAdditionService < ShiftBaseService
  def initialize
    super
  end
  def create_addition_request(params)
    # 1. バリデーション
    validation_result = validate_addition_params(params)
    return validation_result unless validation_result[:success]

    # 2. 重複チェック
    overlap_check_result = check_shift_overlaps(params)
    return overlap_check_result unless overlap_check_result[:success]

    # 3. リクエスト作成
    created_requests = create_addition_requests(params)

    # 4. 通知送信
    send_addition_notifications(created_requests, params)

    success_response("シフト追加依頼を作成しました", { created_requests: created_requests })
  rescue StandardError => e
    handle_shift_error(e, "シフト追加リクエスト作成")
  end
  def approve_addition_request(request_id, approver_id)
    addition_request = find_addition_request(request_id)
    return { success: false, message: "シフト追加リクエストが見つかりません。" } unless addition_request
    unless addition_request.target_employee_id == approver_id
      return { success: false, message: "このリクエストを承認する権限がありません。" }
    end
    # 追加対象従業員にシフトを作成
    shift_service = ShiftDisplayService.new
    create_result = shift_service.create_shift_record(
      employee_id: addition_request.target_employee_id,
      shift_date: addition_request.shift_date.to_s,
      start_time: addition_request.start_time.strftime("%H:%M"),
      end_time: addition_request.end_time.strftime("%H:%M")
    )
    unless create_result[:success]
      return { success: false, message: create_result[:error] || "シフトの作成に失敗しました。" }
    end
    addition_request.update!(status: "approved", responded_at: Time.current)
    send_approval_notification(addition_request)

    {
      success: true,
      message: "シフト追加を承認しました。"
    }
  rescue StandardError => e
    Rails.logger.error "シフト追加承認エラー: #{e.message}"
    { success: false, message: "シフト追加の承認に失敗しました。" }
  end
  def reject_addition_request(request_id, approver_id)
    addition_request = find_addition_request(request_id)
    return { success: false, message: "シフト追加リクエストが見つかりません。" } unless addition_request
    unless addition_request.target_employee_id == approver_id
      return { success: false, message: "このリクエストを拒否する権限がありません。" }
    end
    addition_request.update!(status: "rejected", responded_at: Time.current)
    send_rejection_notification(addition_request)

    {
      success: true,
      message: "シフト追加を拒否しました。"
    }
  rescue StandardError => e
    Rails.logger.error "シフト追加拒否エラー: #{e.message}"
    { success: false, message: "シフト追加の拒否に失敗しました。" }
  end
  def get_addition_status(employee_id)

    sent_requests = ShiftAddition.where(requester_id: employee_id)
    received_requests = ShiftAddition.where(target_employee_id: employee_id)

    all_requests = (sent_requests + received_requests).uniq

    return { success: true, message: "シフト追加リクエストはありません。" } if all_requests.empty?

    status_counts = {
      pending: all_requests.count { |r| r.status == "pending" },
      approved: all_requests.count { |r| r.status == "approved" },
      rejected: all_requests.count { |r| r.status == "rejected" }
    }

    {
      success: true,
      requests: all_requests,
      status_counts: status_counts,
      message: generate_status_message(status_counts)
    }
  rescue StandardError => e
    Rails.logger.error "シフト追加状況取得エラー: #{e.message}"
    { success: false, message: "シフト追加状況の取得に失敗しました。" }
  end

  private
  def validate_addition_params(params)
    required_fields = %i[requester_id shift_date start_time end_time target_employee_ids]

    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      return {
        success: false,
        message: "必須項目が不足しています: #{missing_fields.join(', ')}"
      }
    end

    if params[:target_employee_ids].empty?
      return {
        success: false,
        message: "シフト追加対象の従業員を選択してください。"
      }
    end

    { success: true }
  end
  def find_addition_request(request_id)

    ShiftAddition.find_by(id: request_id) || ShiftAddition.find_by(request_id: request_id)
  end
  def send_addition_notifications(requests, params)
    return if Rails.env.test? || requests.empty?

    notification_service = EmailNotificationService.new
    notification_service.send_shift_addition_request_notification(requests, params)
  end
  def send_approval_notification(addition_request)
    return if Rails.env.test?

    notification_service = EmailNotificationService.new
    notification_service.send_shift_addition_approval_notification(addition_request)
  end
  def send_rejection_notification(addition_request)
    return if Rails.env.test?

    notification_service = EmailNotificationService.new
    notification_service.send_shift_addition_rejection_notification(addition_request)
  end
  def generate_success_message(overlapping_employees)
    if overlapping_employees.any?
      "リクエストを送信しました。一部の従業員は指定時間にシフトが入っているため、依頼可能な従業員のみに送信されました。"
    else
      "シフト追加リクエストを送信しました。"
    end
  end
  def generate_status_message(status_counts)
    message = "📊 シフト追加状況\n\n"

    message += "⏳ 承認待ち (#{status_counts[:pending]}件)\n" if status_counts[:pending].positive?
    message += "✅ 承認済み (#{status_counts[:approved]}件)\n" if status_counts[:approved].positive?
    message += "❌ 拒否済み (#{status_counts[:rejected]}件)\n" if status_counts[:rejected].positive?

    message
  end

  private

  def validate_addition_params(params)
    validate_shift_params(params, %i[requester_id target_employee_ids shift_date start_time end_time])
  end

  def check_shift_overlaps(params)
    overlapping_employees = []

    log_info("重複チェック開始: #{params[:target_employee_ids]}")

    params[:target_employee_ids].each do |target_employee_id|
      overlapping_employee = check_addition_overlap(
        target_employee_id,
        params[:shift_date],
        params[:start_time],
        params[:end_time]
      )

      log_info("従業員 #{target_employee_id} の重複チェック結果: #{overlapping_employee}")

      if overlapping_employee
        overlapping_employees << overlapping_employee
      end
    end

    log_info("重複している従業員: #{overlapping_employees}")

    if overlapping_employees.any?
      error_msg = "以下の従業員は指定された時間にシフトが入っています: #{overlapping_employees.join(', ')}"
      log_info("重複エラー: #{error_msg}")
      return error_response(error_msg)
    end

    log_info("重複チェック完了 - 重複なし")
    success_response("重複チェック完了")
  end

  def create_addition_requests(params)
    created_requests = []

    params[:target_employee_ids].each do |target_employee_id|
      # 既存のリクエストをチェック
      existing_request = ShiftAddition.find_by(
        requester_id: params[:requester_id],
        target_employee_id: target_employee_id,
        shift_date: Date.parse(params[:shift_date]),
        start_time: Time.zone.parse(params[:start_time]),
        end_time: Time.zone.parse(params[:end_time]),
        status: %w[pending approved]
      )

      next if existing_request

      # 新しいリクエストを作成
      addition_request = ShiftAddition.create!(
        request_id: generate_request_id("ADDITION"),
        requester_id: params[:requester_id],
        target_employee_id: target_employee_id,
        shift_date: Date.parse(params[:shift_date]),
        start_time: Time.zone.parse(params[:start_time]),
        end_time: Time.zone.parse(params[:end_time]),
        status: "pending"
      )
      created_requests << addition_request
    end

    created_requests
  end

  def generate_request_id(prefix = "REQ")
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end
end
