# frozen_string_literal: true

# 統合通知サービス
# メール通知とLINE通知を一元管理
class NotificationService
  def initialize
    @freee_service = FreeeApiService.new(ENV.fetch("FREEE_ACCESS_TOKEN", nil), ENV.fetch("FREEE_COMPANY_ID", nil))

    # テスト環境ではLINE Botクライアントを初期化しない
    unless Rails.env.test?
      @line_client = Line::Bot::Client.new do |config|
        config.channel_secret = ENV.fetch("LINE_CHANNEL_SECRET", nil)
        config.channel_token = ENV.fetch("LINE_CHANNEL_TOKEN", nil)
      end
    end
  end

  # ===== シフト交代通知 =====

  # シフト交代依頼通知の送信
  def send_shift_exchange_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      # メール通知
      send_shift_exchange_request_email(
        request.requester_id,
        [request.approver_id],
        request.shift.shift_date,
        request.shift.start_time,
        request.shift.end_time
      )

      # LINE通知は無効化
    end
  end

  # シフト交代承認通知の送信
  def send_shift_exchange_approval_notification(exchange_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_exchange_approved_email(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト交代承認通知送信エラー: #{e.message}"
    end
  end

  # シフト交代拒否通知の送信
  def send_shift_exchange_rejection_notification(exchange_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_exchange_denied_email(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト交代拒否通知送信エラー: #{e.message}"
    end
  end

  # ===== シフト追加通知 =====

  # シフト追加依頼通知の送信
  def send_shift_addition_request_notification(requests, _params)
    return if Rails.env.test? || requests.empty?

    requests.each do |request|
      # メール通知
      send_shift_addition_request_email(
        request.target_employee_id,
        request.shift_date,
        request.start_time,
        request.end_time
      )

      # LINE通知は無効化
    end
  end

  # シフト追加承認通知の送信
  def send_shift_addition_approval_notification(addition_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_addition_approved_email(
        addition_request.requester_id,
        addition_request.target_employee_id,
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト追加承認通知送信エラー: #{e.message}"
    end
  end

  # シフト追加拒否通知の送信
  def send_shift_addition_rejection_notification(addition_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_addition_denied_email(
        addition_request.requester_id,
        addition_request.target_employee_id,
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )

      # LINE通知は無効化
    rescue StandardError => e
      Rails.logger.error "シフト追加拒否通知送信エラー: #{e.message}"
    end
  end

  # ===== 欠勤申請通知 =====

  # 欠勤申請通知の送信
  def send_shift_deletion_request_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_deletion_request_email(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time,
        deletion_request.reason
      )
    rescue StandardError => e
      Rails.logger.error "欠勤申請通知送信エラー: #{e.message}"
    end
  end

  # 欠勤申請承認通知の送信
  def send_shift_deletion_approval_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_deletion_approved_email(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "欠勤申請承認通知送信エラー: #{e.message}"
    end
  end

  # 欠勤申請拒否通知の送信
  def send_shift_deletion_rejection_notification(deletion_request)
    return if Rails.env.test?

    begin
      # メール通知
      send_shift_deletion_denied_email(
        deletion_request.requester_id,
        deletion_request.shift.shift_date,
        deletion_request.shift.start_time,
        deletion_request.shift.end_time
      )
    rescue StandardError => e
      Rails.logger.error "欠勤申請拒否通知送信エラー: #{e.message}"
    end
  end

  # ===== LINE通知機能 =====

  # シフト交代承認通知を申請者に送信
  def send_approval_notification_to_requester(exchange_request, action, shift_date, start_time, end_time)
    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: exchange_request.requester_id)
    return unless requester&.line_id

    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: exchange_request.approver_id)
    approver_name = approver&.display_name || "不明"

    if action == "approve"
      message = "✅ シフト交代が承認されました！\n\n"
      message += "📅 日付: #{shift_date.strftime('%m/%d')}\n"
      message += "⏰ 時間: #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n"
      message += "👤 承認者: #{approver_name}さん"
    else
      message = "❌ シフト交代が否認されました。\n\n"
      message += "📅 日付: #{shift_date.strftime('%m/%d')}\n"
      message += "⏰ 時間: #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n"
      message += "👤 否認者: #{approver_name}さん"
    end

    send_line_message(requester.line_id, message)
  end

  # シフト交代依頼通知を承認者に送信
  def send_shift_exchange_request_line_notification(exchange_request)
    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: exchange_request.approver_id)
    return unless approver&.line_id

    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: exchange_request.requester_id)
    requester_name = requester&.display_name || "不明"

    # シフト情報を取得
    shift = Shift.find(exchange_request.shift_id)

    message = "🔄 シフト交代依頼が届きました\n\n"
    message += "📅 日付: #{shift.shift_date.strftime('%m/%d')}\n"
    message += "⏰ 時間: #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    message += "👤 申請者: #{requester_name}さん\n\n"
    message += "「依頼確認」コマンドで承認・否認を行ってください。"

    send_line_message(approver.line_id, message)
  end

  # 認証コード送信通知
  def send_verification_code_notification(line_user_id, employee_name)
    message = "🔐 認証コードを送信しました\n\n"
    message += "従業員: #{employee_name}\n"
    message += "メールに送信された6桁の認証コードを入力してください。\n"
    message += "（認証コードの有効期限は10分間です）"

    send_line_message(line_user_id, message)
  end

  # 認証完了通知
  def send_authentication_success_notification(line_user_id, employee_name)
    message = "✅ 認証が完了しました！\n\n"
    message += "従業員: #{employee_name}\n"
    message += "これでLINE Botの機能をご利用いただけます。\n"
    message += "「ヘルプ」と入力すると利用可能なコマンドを確認できます。"

    send_line_message(line_user_id, message)
  end

  # エラー通知
  def send_error_notification(line_user_id, error_message)
    message = "❌ エラーが発生しました\n\n"
    message += error_message

    send_line_message(line_user_id, message)
  end

  # 成功通知
  def send_success_notification(line_user_id, success_message)
    message = "✅ #{success_message}"

    send_line_message(line_user_id, message)
  end

  # 警告通知
  def send_warning_notification(line_user_id, warning_message)
    message = "⚠️ #{warning_message}"

    send_line_message(line_user_id, message)
  end

  # 情報通知
  def send_info_notification(line_user_id, info_message)
    message = "ℹ️ #{info_message}"

    send_line_message(line_user_id, message)
  end

  # シフト追加依頼通知を対象従業員に送信
  def send_shift_addition_request_line_notification(addition_request)
    # 対象従業員の情報を取得
    target_employee = Employee.find_by(employee_id: addition_request.target_employee_id)
    return unless target_employee&.line_id

    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: addition_request.requester_id)
    requester_name = requester&.display_name || "不明"

    message = "➕ シフト追加依頼が届きました\n\n"
    message += "📅 日付: #{addition_request.shift_date.strftime('%m/%d')}\n"
    message += "⏰ 時間: #{addition_request.start_time.strftime('%H:%M')}-#{addition_request.end_time.strftime('%H:%M')}\n"
    message += "👤 申請者: #{requester_name}さん\n\n"
    message += "承認する場合は「承認 #{addition_request.request_id}」\n"
    message += "拒否する場合は「拒否 #{addition_request.request_id}」と入力してください。"

    send_line_message(target_employee.line_id, message)
  end

  # シフト追加承認通知を申請者に送信
  def send_shift_addition_approval_line_notification(addition_request)
    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: addition_request.requester_id)
    return unless requester&.line_id

    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: addition_request.target_employee_id)
    approver_name = approver&.display_name || "不明"

    message = "✅ シフト追加が承認されました！\n\n"
    message += "📅 日付: #{addition_request.shift_date.strftime('%m/%d')}\n"
    message += "⏰ 時間: #{addition_request.start_time.strftime('%H:%M')}-#{addition_request.end_time.strftime('%H:%M')}\n"
    message += "👤 承認者: #{approver_name}さん"

    send_line_message(requester.line_id, message)
  end

  # シフト追加拒否通知を申請者に送信
  def send_shift_addition_rejection_line_notification(addition_request)
    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: addition_request.requester_id)
    return unless requester&.line_id

    # 拒否者の情報を取得
    rejector = Employee.find_by(employee_id: addition_request.target_employee_id)
    rejector_name = rejector&.display_name || "不明"

    message = "❌ シフト追加が拒否されました。\n\n"
    message += "📅 日付: #{addition_request.shift_date.strftime('%m/%d')}\n"
    message += "⏰ 時間: #{addition_request.start_time.strftime('%H:%M')}-#{addition_request.end_time.strftime('%H:%M')}\n"
    message += "👤 拒否者: #{rejector_name}さん"

    send_line_message(requester.line_id, message)
  end

  # グループ通知
  def send_group_notification(group_id, message)
    # テスト環境では実際の送信は行わない
    return if Rails.env.test?

    begin
      message_obj = {
        type: "text",
        text: message
      }

      response = @line_client.push_message(group_id, message_obj)

      if response.code == "200"
        Rails.logger.info "グループ通知送信成功: #{group_id}"
      else
        Rails.logger.error "グループ通知送信失敗: #{group_id} - #{response.code}"
      end
    rescue StandardError => e
      Rails.logger.error "グループ通知送信エラー: #{e.message}"
    end
  end

  # 複数ユーザーへの一括通知
  def send_bulk_notification(line_user_ids, message)
    line_user_ids.each do |line_user_id|
      send_line_message(line_user_id, message)
    end
  end

  # ===== メール通知機能 =====

  # 従業員情報を取得（メールアドレス付き）
  def get_employee_with_email(employee_id)
    all_employees = @freee_service.get_employees_full
    all_employees.find { |emp| emp["id"].to_s == employee_id.to_s }
  end

  # シフト交代依頼メールを送信
  def send_shift_exchange_request_email(applicant_id, approver_ids, shift_date, start_time, end_time)
    applicant_info = get_employee_with_email(applicant_id)
    return false unless applicant_info&.dig("email")

    approver_ids.each do |approver_id|
      approver_info = get_employee_with_email(approver_id)
      next unless approver_info&.dig("email")

      ShiftMailer.shift_exchange_request(
        approver_info["email"],
        approver_info["display_name"],
        applicant_info["display_name"],
        shift_date,
        start_time,
        end_time
      ).deliver_now
    end
    true
  rescue StandardError => e
    Rails.logger.error "シフト交代依頼メール送信エラー: #{e.message}"
    false
  end

  # シフト追加依頼メールを送信
  def send_shift_addition_request_email(target_employee_id, shift_date, start_time, end_time)
    target_employee_info = get_employee_with_email(target_employee_id)
    return false unless target_employee_info&.dig("email")

    ShiftMailer.shift_addition_request(
      target_employee_info["email"],
      target_employee_info["display_name"],
      shift_date,
      start_time,
      end_time
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "シフト追加依頼メール送信エラー: #{e.message}"
    false
  end

  # シフト交代承認メールを送信
  def send_shift_exchange_approved_email(requester_id, approver_id, shift_date, start_time, end_time)
    requester_info = get_employee_with_email(requester_id)
    approver_info = get_employee_with_email(approver_id)
    return false unless requester_info&.dig("email") && approver_info

    ShiftMailer.shift_exchange_approved(
      requester_info["email"],
      requester_info["display_name"],
      approver_info["display_name"],
      shift_date,
      start_time,
      end_time
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "シフト交代承認メール送信エラー: #{e.message}"
    false
  end

  # シフト交代否認メールを送信
  def send_shift_exchange_denied_email(requester_id, approver_id, shift_date, start_time, end_time)
    requester_info = get_employee_with_email(requester_id)
    return false unless requester_info&.dig("email")

    ShiftMailer.shift_exchange_denied(
      requester_info["email"],
      requester_info["display_name"]
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "シフト交代否認メール送信エラー: #{e.message}"
    false
  end

  # シフト追加承認メールを送信
  def send_shift_addition_approved_email(owner_id, target_name, shift_date, start_time, end_time)
    owner_info = get_employee_with_email(owner_id)
    return false unless owner_info&.dig("email")

    ShiftMailer.shift_addition_approved(
      owner_info["email"],
      target_name,
      shift_date,
      start_time,
      end_time
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "シフト追加承認メール送信エラー: #{e.message}"
    false
  end

  # シフト追加否認メールを送信
  def send_shift_addition_denied_email(owner_id, target_name, shift_date, start_time, end_time)
    owner_info = get_employee_with_email(owner_id)
    return false unless owner_info&.dig("email")

    ShiftMailer.shift_addition_denied(
      owner_info["email"],
      target_name
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "シフト追加否認メール送信エラー: #{e.message}"
    false
  end

  # 欠勤申請メールを送信（オーナー宛）
  def send_shift_deletion_request_email(requester_id, shift_date, start_time, end_time, reason)
    # オーナーに通知を送信
    owners = Employee.where(role: "owner")
    owners.each do |owner|
      owner_info = get_employee_with_email(owner.employee_id)
      next unless owner_info&.dig("email")

      requester_info = get_employee_with_email(requester_id)
      next unless requester_info

      ShiftMailer.shift_deletion_request(
        owner_info["email"],
        owner_info["display_name"],
        requester_info["display_name"],
        shift_date,
        start_time,
        end_time,
        reason
      ).deliver_now
    end
    true
  rescue StandardError => e
    Rails.logger.error "欠勤申請メール送信エラー: #{e.message}"
    false
  end

  # 欠勤申請承認メールを送信
  def send_shift_deletion_approved_email(requester_id, shift_date, start_time, end_time)
    requester_info = get_employee_with_email(requester_id)
    return false unless requester_info&.dig("email")

    ShiftMailer.shift_deletion_approved(
      requester_info["email"],
      requester_info["display_name"],
      shift_date,
      start_time,
      end_time
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "欠勤申請承認メール送信エラー: #{e.message}"
    false
  end

  # 欠勤申請拒否メールを送信
  def send_shift_deletion_denied_email(requester_id, shift_date, start_time, end_time)
    requester_info = get_employee_with_email(requester_id)
    return false unless requester_info&.dig("email")

    ShiftMailer.shift_deletion_denied(
      requester_info["email"],
      requester_info["display_name"],
      shift_date,
      start_time,
      end_time
    ).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error "欠勤申請拒否メール送信エラー: #{e.message}"
    false
  end

  # ===== ユーティリティ機能 =====

  # メール通知のみの送信
  def send_email_only(notification_type, *)
    case notification_type
    when :shift_exchange_request
      send_shift_exchange_request_email(*)
    when :shift_addition_request
      send_shift_addition_request_email(*)
    when :shift_exchange_approved
      send_shift_exchange_approved_email(*)
    when :shift_exchange_denied
      send_shift_exchange_denied_email(*)
    when :shift_addition_approved
      send_shift_addition_approved_email(*)
    when :shift_addition_denied
      send_shift_addition_denied_email(*)
    end
  end

  # LINE通知のみの送信
  def send_line_only(notification_type, *)
    case notification_type
    when :shift_exchange_request
      # LINE通知は無効化
    when :shift_addition_request
      # LINE通知は無効化
    when :shift_exchange_approval
      # LINE通知は無効化
    when :shift_addition_approval
      # LINE通知は無効化
    when :shift_addition_rejection
      # LINE通知は無効化
    end
  end

  private

  # LINEメッセージ送信
  def send_line_message(line_user_id, message)
    # テスト環境では実際の送信は行わない
    return if Rails.env.test?

    begin
      message_obj = {
        type: "text",
        text: message
      }

      response = @line_client.push_message(line_user_id, message_obj)

      if response.code == "200"
        Rails.logger.info "LINE通知送信成功: #{line_user_id}"
      else
        Rails.logger.error "LINE通知送信失敗: #{line_user_id} - #{response.code}"
      end
    rescue StandardError => e
      Rails.logger.error "LINE通知送信エラー: #{e.message}"
    end
  end

  # Flex Message送信
  def send_flex_message(line_user_id, flex_message)
    # テスト環境では実際の送信は行わない
    return if Rails.env.test?

    begin
      response = @line_client.push_message(line_user_id, flex_message)

      if response.code == "200"
        Rails.logger.info "LINE Flex通知送信成功: #{line_user_id}"
      else
        Rails.logger.error "LINE Flex通知送信失敗: #{line_user_id} - #{response.code}"
      end
    rescue StandardError => e
      Rails.logger.error "LINE Flex通知送信エラー: #{e.message}"
    end
  end
end
