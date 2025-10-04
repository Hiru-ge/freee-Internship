class ShiftAdditionService
  def initialize; end
  def create_addition_request(params)

    validation_result = validate_addition_params(params)
    return validation_result unless validation_result[:success]
    return { success: false, message: "過去の日付のシフト追加依頼はできません。" } if Date.parse(params[:shift_date]) < Date.current
    created_requests = []
    params[:target_employee_ids].each do |target_employee_id|

      existing_request = ShiftAddition.find_by(
        requester_id: params[:requester_id],
        target_employee_id: target_employee_id,
        shift_date: Date.parse(params[:shift_date]),
        start_time: Time.zone.parse(params[:start_time]),
        end_time: Time.zone.parse(params[:end_time]),
        status: %w[pending approved]
      )

      next if existing_request

      addition_request = ShiftAddition.create!(
        request_id: LineBotService.new.generate_request_id("ADDITION"),
        requester_id: params[:requester_id],
        target_employee_id: target_employee_id,
        shift_date: Date.parse(params[:shift_date]),
        start_time: Time.zone.parse(params[:start_time]),
        end_time: Time.zone.parse(params[:end_time]),
        status: "pending"
      )
      created_requests << addition_request
    end
    send_addition_notifications(created_requests, params)

    {
      success: true,
      created_requests: created_requests,
      message: generate_success_message([])
    }
  rescue StandardError => e
    Rails.logger.error "シフト追加リクエスト作成エラー: #{e.message}"
    { success: false, message: "シフト追加リクエストの作成に失敗しました。" }
  end
  def approve_addition_request(request_id, approver_id)
    addition_request = find_addition_request(request_id)
    return { success: false, message: "シフト追加リクエストが見つかりません。" } unless addition_request
    unless addition_request.target_employee_id == approver_id
      return { success: false, message: "このリクエストを承認する権限がありません。" }
    end
    new_shift_data = {
      shift_date: addition_request.shift_date,
      start_time: addition_request.start_time,
      end_time: addition_request.end_time,
      requester_id: addition_request.requester_id
    }
    ShiftDisplayService.process_shift_addition_approval(addition_request.target_employee_id, new_shift_data)
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
end
