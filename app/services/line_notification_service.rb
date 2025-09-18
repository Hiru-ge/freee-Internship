class LineNotificationService
  def initialize
    # テスト環境ではLINE Botクライアントを初期化しない
    unless Rails.env.test?
      @line_client = Line::Bot::Client.new do |config|
        config.channel_secret = ENV['LINE_CHANNEL_SECRET']
        config.channel_token = ENV['LINE_CHANNEL_TOKEN']
      end
    end
  end

  # シフト交代承認通知を申請者に送信
  def send_approval_notification_to_requester(exchange_request, action, shift_date, start_time, end_time)
    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: exchange_request.requester_employee_id)
    return unless requester&.line_id

    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: exchange_request.target_employee_id)
    approver_name = approver&.display_name || '不明'

    if action == 'approve'
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
  def send_shift_exchange_request_notification(exchange_request)
    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: exchange_request.target_employee_id)
    return unless approver&.line_id

    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: exchange_request.requester_employee_id)
    requester_name = requester&.display_name || '不明'

    # シフト情報を取得
    shift = Shift.find(exchange_request.shift_id)
    
    message = "🔄 シフト交代依頼が届きました\n\n"
    message += "📅 日付: #{shift.date.strftime('%m/%d')}\n"
    message += "⏰ 時間: #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    message += "👤 申請者: #{requester_name}さん\n\n"
    message += "「リクエスト確認」コマンドで承認・否認を行ってください。"

    send_line_message(approver.line_id, message)
  end

  # シフト交代依頼のメール通知
  def send_shift_exchange_request_email_notification(exchange_request)
    # テスト環境ではメール送信をスキップ
    return nil if Rails.env.test?
    
    begin
      # 申請者と承認者の情報を取得
      requester = Employee.find_by(employee_id: exchange_request.requester_employee_id)
      approver = Employee.find_by(employee_id: exchange_request.target_employee_id)
      
      return unless requester&.email && approver&.email
      
      # シフト情報を取得
      shift = Shift.find(exchange_request.shift_id)
      
      # メール送信
      ShiftMailer.shift_exchange_request(
        requester.email,
        approver.email,
        shift.date,
        shift.start_time,
        shift.end_time,
        requester.display_name,
        approver.display_name
      ).deliver_now
      
      Rails.logger.info "シフト交代依頼メール送信完了: #{requester.email} -> #{approver.email}"
    rescue => e
      Rails.logger.error "シフト交代依頼メール送信エラー: #{e.message}"
    end
  end

  # シフト交代承認のメール通知
  def send_shift_exchange_approved_email_notification(exchange_request)
    # テスト環境ではメール送信をスキップ
    return nil if Rails.env.test?
    
    begin
      # 申請者と承認者の情報を取得
      requester = Employee.find_by(employee_id: exchange_request.requester_employee_id)
      approver = Employee.find_by(employee_id: exchange_request.target_employee_id)
      
      return unless requester&.email && approver&.email
      
      # シフト情報を取得
      shift = Shift.find(exchange_request.shift_id)
      
      # メール送信
      ShiftMailer.shift_exchange_approved(
        requester.email,
        approver.email,
        shift.date,
        shift.start_time,
        shift.end_time,
        requester.display_name,
        approver.display_name
      ).deliver_now
      
      Rails.logger.info "シフト交代承認メール送信完了: #{approver.email} -> #{requester.email}"
    rescue => e
      Rails.logger.error "シフト交代承認メール送信エラー: #{e.message}"
    end
  end

  # シフト交代否認のメール通知
  def send_shift_exchange_denied_email_notification(exchange_request)
    # テスト環境ではメール送信をスキップ
    return nil if Rails.env.test?
    
    begin
      # 申請者と承認者の情報を取得
      requester = Employee.find_by(employee_id: exchange_request.requester_employee_id)
      approver = Employee.find_by(employee_id: exchange_request.target_employee_id)
      
      return unless requester&.email && approver&.email
      
      # シフト情報を取得
      shift = Shift.find(exchange_request.shift_id)
      
      # メール送信
      ShiftMailer.shift_exchange_denied(
        requester.email,
        approver.email,
        shift.date,
        shift.start_time,
        shift.end_time,
        requester.display_name,
        approver.display_name
      ).deliver_now
      
      Rails.logger.info "シフト交代否認メール送信完了: #{approver.email} -> #{requester.email}"
    rescue => e
      Rails.logger.error "シフト交代否認メール送信エラー: #{e.message}"
    end
  end

  # シフト追加通知
  def send_shift_addition_notifications(shift_additions)
    return if Rails.env.test? # テスト環境ではスキップ
    
    email_service = EmailNotificationService.new
    
    shift_additions.each do |addition_request|
      begin
        # 対象従業員の情報を取得
        target_employee = Employee.find_by(employee_id: addition_request.target_employee_id)
        next unless target_employee&.email
        
        # 申請者の情報を取得
        requester = Employee.find_by(employee_id: addition_request.requester_employee_id)
        requester_name = requester&.display_name || '不明'
        
        # メール送信
        email_service.send_shift_addition_request(
          target_employee.email,
          addition_request.date,
          addition_request.start_time,
          addition_request.end_time,
          requester_name,
          target_employee.display_name
        )
        
        Rails.logger.info "シフト追加依頼メール送信完了: #{target_employee.email}"
      rescue => e
        Rails.logger.error "シフト追加依頼メール送信エラー: #{e.message}"
      end
    end
  end

  # シフト追加承認メール送信
  def send_shift_addition_approval_email(addition_request)
    begin
      email_service = EmailNotificationService.new
      # 従業員情報を取得
      requester = Employee.find_by(employee_id: addition_request.requester_employee_id)
      target_employee = Employee.find_by(employee_id: addition_request.target_employee_id)
      
      return unless requester&.email && target_employee&.email
      
      # メール送信
      email_service.send_shift_addition_approved(
        requester.email,
        addition_request.date,
        addition_request.start_time,
        addition_request.end_time,
        requester.display_name,
        target_employee.display_name
      )
      
      Rails.logger.info "シフト追加承認メール送信完了: #{requester.email}"
    rescue => e
      Rails.logger.error "シフト追加承認メール送信エラー: #{e.message}"
    end
  end

  # シフト追加否認メール送信
  def send_shift_addition_rejection_email(addition_request)
    begin
      email_service = EmailNotificationService.new
      # 従業員情報を取得
      requester = Employee.find_by(employee_id: addition_request.requester_employee_id)
      target_employee = Employee.find_by(employee_id: addition_request.target_employee_id)
      
      return unless requester&.email && target_employee&.email
      
      # メール送信
      email_service.send_shift_addition_rejected(
        requester.email,
        addition_request.date,
        addition_request.start_time,
        addition_request.end_time,
        requester.display_name,
        target_employee.display_name
      )
      
      Rails.logger.info "シフト追加否認メール送信完了: #{requester.email}"
    rescue => e
      Rails.logger.error "シフト追加否認メール送信エラー: #{e.message}"
    end
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

  private

  # LINEメッセージ送信
  def send_line_message(line_user_id, message)
    # テスト環境では実際の送信は行わない
    return if Rails.env.test?
    
    begin
      message_obj = {
        type: 'text',
        text: message
      }

      response = @line_client.push_message(line_user_id, message_obj)
      
      if response.code == '200'
        Rails.logger.info "LINE通知送信成功: #{line_user_id}"
      else
        Rails.logger.error "LINE通知送信失敗: #{line_user_id} - #{response.code}"
      end
    rescue => e
      Rails.logger.error "LINE通知送信エラー: #{e.message}"
    end
  end

  # Flex Message送信
  def send_flex_message(line_user_id, flex_message)
    # テスト環境では実際の送信は行わない
    return if Rails.env.test?
    
    begin
      response = @line_client.push_message(line_user_id, flex_message)
      
      if response.code == '200'
        Rails.logger.info "LINE Flex通知送信成功: #{line_user_id}"
      else
        Rails.logger.error "LINE Flex通知送信失敗: #{line_user_id} - #{response.code}"
      end
    rescue => e
      Rails.logger.error "LINE Flex通知送信エラー: #{e.message}"
    end
  end

  # 複数ユーザーへの一括通知
  def send_bulk_notification(line_user_ids, message)
    line_user_ids.each do |line_user_id|
      send_line_message(line_user_id, message)
    end
  end

  # グループ通知
  def send_group_notification(group_id, message)
    # テスト環境では実際の送信は行わない
    return if Rails.env.test?
    
    begin
      message_obj = {
        type: 'text',
        text: message
      }

      response = @line_client.push_message(group_id, message_obj)
      
      if response.code == '200'
        Rails.logger.info "グループ通知送信成功: #{group_id}"
      else
        Rails.logger.error "グループ通知送信失敗: #{group_id} - #{response.code}"
      end
    rescue => e
      Rails.logger.error "グループ通知送信エラー: #{e.message}"
    end
  end
end
