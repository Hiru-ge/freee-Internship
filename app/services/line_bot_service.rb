class LineBotService
  COMMANDS = {
    'ヘルプ' => :help,
    '認証' => :auth,
    'シフト確認' => :shift,
    '全員シフト確認' => :all_shifts,
    '交代依頼' => :shift_exchange,
    '追加依頼' => :shift_addition,
    '依頼確認' => :request_check
  }.freeze

  def initialize
    # サービスクラスの初期化は遅延ロードする
  end

  def auth_service
    @auth_service ||= LineAuthenticationService.new
  end

  def shift_service
    @shift_service ||= LineShiftService.new
  end

  def exchange_service
    @exchange_service ||= LineShiftExchangeService.new
  end

  def addition_service
    @addition_service ||= LineShiftAdditionService.new
  end

  def message_service
    @message_service ||= LineMessageService.new
  end

  def conversation_service
    @conversation_service ||= LineConversationService.new
  end

  def validation_service
    @validation_service ||= LineValidationService.new
  end

  def notification_service
    @notification_service ||= LineNotificationService.new
  end

  def utility_service
    @utility_service ||= LineUtilityService.new
  end

  def handle_message(event)
    # Postbackイベントの処理
    if event['type'] == 'postback'
      return handle_postback_event(event)
    end

    message_text = event['message']['text']
    line_user_id = utility_service.extract_user_id(event)
    
    # 会話状態をチェック
    state = conversation_service.get_conversation_state(line_user_id)
    if state
      return conversation_service.handle_stateful_message(line_user_id, message_text, state)
    end
    
    command = COMMANDS[message_text]
    
    case command
    when :help
      message_service.generate_help_message(event)
    when :auth
      auth_service.handle_auth_command(event)
    when :shift
      shift_service.handle_shift_command(event)
    when :all_shifts
      shift_service.handle_all_shifts_command(event)
    when :shift_exchange
      exchange_service.handle_shift_exchange_command(event)
    when :shift_addition
      addition_service.handle_shift_addition_command(event)
    when :request_check
      handle_request_check_command(event)
    else
      # コマンド以外のメッセージは無視する（nilを返す）
      nil
    end
  end

  # Postbackイベントの処理
  def handle_postback_event(event)
    line_user_id = utility_service.extract_user_id(event)
    postback_data = event['postback']['data']
    
    # 認証チェック
    unless utility_service.employee_already_linked?(line_user_id)
      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end
    
    # シフト選択のPostback処理
    if postback_data.match?(/^shift_\d+$/)
      return handle_shift_selection_input(line_user_id, postback_data)
    elsif postback_data.match?(/^approve_\d+$/)
      return exchange_service.handle_approval_postback(line_user_id, postback_data, 'approve')
    elsif postback_data.match?(/^reject_\d+$/)
      return exchange_service.handle_approval_postback(line_user_id, postback_data, 'reject')
    elsif postback_data.match?(/^approve_addition_.+$/)
      return addition_service.handle_shift_addition_approval_postback(line_user_id, postback_data, 'approve')
    elsif postback_data.match?(/^reject_addition_.+$/)
      return addition_service.handle_shift_addition_approval_postback(line_user_id, postback_data, 'reject')
    end
    
    "不明なPostbackイベントです。"
  end

  def handle_shift_addition_approval_postback(line_user_id, postback_data, action)
    request_id = extract_request_id_from_postback(postback_data, 'addition')
    addition_request = ShiftAddition.find_by(request_id: request_id)
    
    return "シフト追加リクエストが見つかりません。" unless addition_request
    
    # 権限チェック（承認者は対象従業員である必要がある）
    employee = Employee.find_by(line_id: line_user_id)
    unless addition_request.target_employee_id == employee.employee_id
      return "このリクエストを承認する権限がありません。"
    end
    
    if action == 'approve'
      approve_shift_addition(addition_request, employee)
    else
      reject_shift_addition(addition_request)
    end
  end

  private

  def extract_request_id_from_postback(postback_data, type)
    case type
    when 'addition'
      # approve_addition_REQUEST_ID -> REQUEST_ID
      postback_data.sub(/^approve_addition_/, '').sub(/^reject_addition_/, '')
    when 'exchange'
      postback_data.split('_')[1]  # approve_4 -> 4
    else
      postback_data.split('_')[1]
    end
  end

  def approve_shift_addition(addition_request, employee)
    begin
      # シフト追加承認処理（既存シフトとの結合を考慮）
      new_shift_data = {
        shift_date: addition_request.shift_date,
        start_time: addition_request.start_time,
        end_time: addition_request.end_time,
        requester_id: addition_request.requester_id
      }
      ShiftMergeService.process_shift_addition_approval(employee.employee_id, new_shift_data)
      
      # リクエストのステータスを承認に更新
      addition_request.update!(status: 'approved')
      
      # メール通知を送信
      send_shift_addition_approval_email(addition_request)
      
      generate_shift_addition_response(addition_request, 'approved')
      
    rescue => e
      Rails.logger.error "シフト追加承認エラー: #{e.message}"
      "❌ シフト追加の承認に失敗しました。"
    end
  end

  def reject_shift_addition(addition_request)
    # リクエストのステータスを拒否に更新
    addition_request.update!(status: 'rejected')
    
    # メール通知を送信
    send_shift_addition_rejection_email(addition_request)
    
    generate_shift_addition_response(addition_request, 'rejected')
  end

  def generate_shift_addition_response(addition_request, status)
    date_str = addition_request.shift_date.strftime('%m/%d')
    day_of_week = %w[日 月 火 水 木 金 土][addition_request.shift_date.wday]
    time_str = "#{addition_request.start_time.strftime('%H:%M')}-#{addition_request.end_time.strftime('%H:%M')}"
    
    if status == 'approved'
      "✅ シフト追加を承認しました。\n" +
      "📅 #{date_str} (#{day_of_week})\n" +
      "⏰ #{time_str}\n" +
      "シフトが追加されました。"
    else
      "❌ シフト追加を拒否しました。\n" +
      "📅 #{date_str} (#{day_of_week})\n" +
      "⏰ #{time_str}"
    end
  end

  public

  def handle_approval_postback(line_user_id, postback_data, action)
    request_id = postback_data.split('_')[1]
    exchange_request = ShiftExchange.find_by(id: request_id)
    
    unless exchange_request
      return "シフト交代リクエストが見つかりません。"
    end
    
    # 権限チェック（承認者は交代先のシフトの担当者である必要がある）
    employee = Employee.find_by(line_id: line_user_id)
    unless exchange_request.approver_id == employee.employee_id
      return "このリクエストを承認する権限がありません。"
    end
    
    if action == 'approve'
      # シフト交代を実行
      shift = exchange_request.shift
      if shift
        # シフト情報を保存（削除前に）
        original_employee_id = shift.employee_id
        shift_date = shift.shift_date
        start_time = shift.start_time
        end_time = shift.end_time
        
        # 承認者の既存シフトを確認
        existing_shift = Shift.find_by(
          employee_id: employee.employee_id,
          shift_date: shift_date
        )
        
        if existing_shift
          # 既存シフトがある場合はマージ
          new_shift_data = Shift.new(
            employee_id: employee.employee_id,
            shift_date: shift_date,
            start_time: start_time,
            end_time: end_time,
            is_modified: true,
            original_employee_id: original_employee_id
          )
          
          # 申請者のシフトが既存シフトに完全に含まれているかチェック
          if shift_fully_contained?(existing_shift, new_shift_data)
            # 完全に含まれている場合は既存シフトを変更しない
            merged_shift = existing_shift
          else
            # 含まれていない場合はマージ
            merged_shift = merge_shifts(existing_shift, new_shift_data)
          end
        else
          # 既存シフトがない場合は新規作成
          merged_shift = Shift.create!(
            employee_id: employee.employee_id,
            shift_date: shift_date,
            start_time: start_time,
            end_time: end_time,
            is_modified: true,
            original_employee_id: original_employee_id
          )
        end
        
        # 関連するShiftExchangeのshift_idをnilに更新（外部キー制約を回避）
        ShiftExchange.where(shift_id: shift.id).update_all(shift_id: nil)
        
        # 元のシフトを削除
        shift.destroy!
      end
      
      # リクエストを承認
      exchange_request.approve!
      
      # 他の承認者へのリクエストを拒否（同じrequester_idとshift_idの組み合わせ）
      ShiftExchange.where(
        requester_id: exchange_request.requester_id,
        shift_id: exchange_request.shift_id,
        status: 'pending'
      ).where.not(id: exchange_request.id).each do |other_request|
        other_request.reject!
      end
      
      # 申請者に通知を送信
      send_approval_notification_to_requester(exchange_request, 'approved', shift_date, start_time, end_time)
      
      # メール通知を送信
      send_shift_exchange_approved_email_notification(exchange_request)
      
      "✅ シフト交代リクエストを承認しました！\n" +
      "📅 #{shift_date.strftime('%m/%d')}のシフトを担当します"
      
    elsif action == 'reject'
      # リクエストを拒否
      exchange_request.reject!
      
      # 申請者に通知を送信
      shift = exchange_request.shift
      if shift
        send_approval_notification_to_requester(exchange_request, 'rejected', shift.shift_date, shift.start_time, shift.end_time)
      end
      
      # メール通知を送信
      send_shift_exchange_denied_email_notification(exchange_request)
      
      "❌ シフト交代リクエストを拒否しました"
    else
      "不明なアクションです。"
    end
  end

  def send_approval_notification_to_requester(exchange_request, action, shift_date, start_time, end_time)
    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: exchange_request.requester_id)
    return unless requester&.line_id
    
    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: exchange_request.approver_id)
    approver_name = approver&.display_name || "ID: #{exchange_request.approver_id}"
    
    # 通知メッセージを作成
    day_of_week = %w[日 月 火 水 木 金 土][shift_date.wday]
    
    if action == 'approved'
      message_text = "🎉 シフト交代リクエストが承認されました！\n\n" +
                    "📅 #{shift_date.strftime('%m/%d')} (#{day_of_week})\n" +
                    "⏰ #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n" +
                    "👤 承認者: #{approver_name}"
    elsif action == 'rejected'
      message_text = "❌ シフト交代リクエストが拒否されました\n\n" +
                    "📅 #{shift_date.strftime('%m/%d')} (#{day_of_week})\n" +
                    "⏰ #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n" +
                    "👤 承認者: #{approver_name}"
    end
    
    # LINE Bot APIでプッシュメッセージを送信
    begin
      line_bot_client.push_message(requester.line_id, {
        type: 'text',
        text: message_text
      })
    rescue Net::TimeoutError => e
      Rails.logger.error "通知送信タイムアウトエラー: #{e.message}"
    rescue Net::HTTPError => e
      Rails.logger.error "通知送信HTTPエラー: #{e.message}"
    rescue => e
      Rails.logger.error "通知送信エラー: #{e.message}"
      Rails.logger.error "エラーバックトレース: #{e.backtrace.join('\n')}"
    end
  end

  def send_shift_exchange_request_notification(exchange_request)
    # 承認者の情報を取得
    approver = Employee.find_by(employee_id: exchange_request.approver_id)
    return unless approver&.line_id
    
    # 申請者の情報を取得
    requester = Employee.find_by(employee_id: exchange_request.requester_id)
    requester_name = requester&.display_name || "ID: #{exchange_request.requester_id}"
    
    # シフト情報を取得
    shift = exchange_request.shift
    return unless shift
    
    # 通知メッセージを作成
    day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
    
    message_text = "📋 シフト交代依頼が届きました！\n\n" +
                  "👤 申請者: #{requester_name}\n" +
                  "📅 #{shift.shift_date.strftime('%m/%d')} (#{day_of_week})\n" +
                  "⏰ #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n\n" +
                  "💬 「リクエスト確認」と入力して承認・拒否を行ってください"
    
    # LINE Bot APIでプッシュメッセージを送信
    begin
      line_bot_client.push_message(approver.line_id, {
        type: 'text',
        text: message_text
      })
    rescue Net::TimeoutError => e
      Rails.logger.error "シフト交代依頼通知送信タイムアウトエラー: #{e.message}"
    rescue Net::HTTPError => e
      Rails.logger.error "シフト交代依頼通知送信HTTPエラー: #{e.message}"
    rescue => e
      Rails.logger.error "シフト交代依頼通知送信エラー: #{e.message}"
      Rails.logger.error "エラーバックトレース: #{e.backtrace.join('\n')}"
    end
  end

  def line_bot_client
    @line_bot_client ||= begin
      if Rails.env.production?
        # 本番環境では実際のLINE Bot APIクライアントを使用
        # ここでは簡易的な実装
        Class.new do
          def push_message(user_id, message)
            Rails.logger.info "LINE Bot push message to #{user_id}: #{message}"
            # 実際の実装では、LINE Bot APIを呼び出す
          end
        end.new
      else
        # テスト環境ではモッククライアントを使用
        Class.new do
          def push_message(user_id, message)
            Rails.logger.info "Mock LINE Bot push message to #{user_id}: #{message}"
          end
        end.new
      end
    end
  end

  # シフトをマージする
  def merge_shifts(existing_shift, new_shift)
    return new_shift unless existing_shift
    
    # 既存シフトと新しいシフトの時間を比較してマージ
    # 時間のみを比較するため、同じ日付のTimeオブジェクトを作成
    existing_start_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    new_start_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.start_time.strftime('%H:%M')}")
    new_end_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.end_time.strftime('%H:%M')}")
    
    merged_start_time = [existing_start_time, new_start_time].min
    merged_end_time = [existing_end_time, new_end_time].max
    
    # 時間のみを抽出してTime型で保存
    merged_start_time_only = Time.zone.parse(merged_start_time.strftime('%H:%M'))
    merged_end_time_only = Time.zone.parse(merged_end_time.strftime('%H:%M'))
    
    # 既存シフトを更新
    existing_shift.update!(
      start_time: merged_start_time_only,
      end_time: merged_end_time_only,
      is_modified: true,
      original_employee_id: new_shift.original_employee_id || new_shift.employee_id
    )
    
    existing_shift
  end

  # 申請者のシフトが承認者のシフトに完全に含まれているかチェック
  def shift_fully_contained?(existing_shift, new_shift)
    # 時間のみを比較するため、同じ日付のTimeオブジェクトを作成
    existing_start_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end_time = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    new_start_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.start_time.strftime('%H:%M')}")
    new_end_time = Time.zone.parse("#{new_shift.shift_date} #{new_shift.end_time.strftime('%H:%M')}")
    
    # 申請者のシフトが既存シフトに完全に含まれているかチェック
    new_start_time >= existing_start_time && new_end_time <= existing_end_time
  end

  def group_message?(event)
    event['source']['type'] == 'group'
  end

  def individual_message?(event)
    event['source']['type'] == 'user'
  end

  def extract_group_id(event)
    return nil unless group_message?(event)
    event['source']['groupId']
  end

  def extract_user_id(event)
    event['source']['userId']
  end

  def find_employee_by_line_id(line_id)
    nil
  end

  def link_employee_to_line(employee_id, line_id)
    false
  end

  def unlink_employee_from_line(line_id)
    false
  end

  def determine_command_context(event)
    message_text = event['message']['text'].downcase.strip
    
    case message_text
    when 'ヘルプ', 'help'
      :help
    when '認証'
      :auth
    when 'シフト確認'
      :shift
    when '全員シフト確認'
      :all_shifts
    when '交代依頼'
      :shift_exchange
    when '追加依頼'
      :shift_addition
    when '依頼確認'
      :request_check
    when '承認'
      :approve
    when '否認'
      :reject
    else
      :unknown
    end
  end

  def generate_verification_code_for_line(line_user_id, employee_id)
    false
  end

  def valid_employee_id_format?(employee_id)
    false
  end

  def send_verification_code_via_email(employee_id, line_user_id)
    false
  end

  def complete_line_account_linking(line_user_id, employee_id, verification_code)
    false
  end

  def validate_verification_code_for_linking(employee_id, verification_code)
    false
  end

  def generate_help_message(event = nil)
    "勤怠管理システムへようこそ！\n\n【利用可能なコマンド】\n・ヘルプ: このメッセージを表示\n・認証: LINEアカウントと従業員アカウントを紐付け\n・シフト確認: 個人のシフト情報を確認（認証必要）\n・全員シフト確認: 全従業員のシフト情報を確認（認証必要）\n・交代依頼: シフト交代依頼（認証必要）\n・依頼確認: 承認待ちのシフト交代リクエスト確認（認証必要）\n・追加依頼: シフト追加依頼（オーナーのみ、認証必要）\n\n認証は個人チャットでのみ可能です。このボットと個人チャットを開始して「認証」を行ってください"
  end

  # シフト確認機能
  def get_personal_shift_info(line_user_id)
    employee = Employee.find_by(line_id: line_user_id)
    return nil unless employee

    # 今月のシフト情報を取得
    now = Date.current
    shifts = Shift.for_employee(employee.employee_id)
                  .for_month(now.year, now.month)
                  .order(:shift_date, :start_time)

    return nil if shifts.empty?

    # シフト情報をフォーマット
    shift_info = "【#{employee.display_name}さんの今月のシフト】\n\n"
    shifts.each do |shift|
      shift_info += "#{shift.shift_date.strftime('%m/%d')} (#{%w[日 月 火 水 木 金 土][shift.shift_date.wday]}) "
      shift_info += "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    end

    shift_info
  end

  def get_group_shift_info(group_id)
    # グループ内の全従業員のシフト情報を取得
    now = Date.current
    employees = Employee.all  # 認証状態に関係なく全従業員を取得
    
    return nil if employees.empty?

    group_info = "【今月の全員シフト】\n\n"
    
    employees.each do |employee|
      shifts = Shift.for_employee(employee.employee_id)
                    .for_month(now.year, now.month)
                    .order(:shift_date, :start_time)
      
      next if shifts.empty?

      group_info += "■ #{employee.display_name}\n"
      shifts.each do |shift|
        group_info += "  #{shift.shift_date.strftime('%m/%d')} (#{%w[日 月 火 水 木 金 土][shift.shift_date.wday]}) "
        group_info += "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
      end
      group_info += "\n"
    end

    group_info
  end

  def get_daily_shift_info(group_id, date)
    # 指定日の全従業員のシフト情報を取得
    employees = Employee.where.not(line_id: nil)
    
    return nil if employees.empty?

    daily_info = "【#{date.strftime('%m/%d')} (#{%w[日 月 火 水 木 金 土][date.wday]}) のシフト】\n\n"
    
    employees.each do |employee|
      shift = Shift.for_employee(employee.employee_id)
                   .where(shift_date: date)
                   .first
      
      next unless shift

      daily_info += "■ #{employee.display_name}\n"
      daily_info += "  #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n\n"
    end

    daily_info
  end

  def format_shift_info(shift_data)
    return nil unless shift_data

    formatted = "#{shift_data[:employee_name]}さん\n"
    formatted += "#{shift_data[:date].strftime('%m/%d')} (#{%w[日 月 火 水 木 金 土][shift_data[:date].wday]}) "
    formatted += "#{shift_data[:start_time].strftime('%H:%M')}-#{shift_data[:end_time].strftime('%H:%M')}"
    
    formatted
  end

  # コマンド処理メソッド
  def handle_shift_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "シフト確認には認証が必要です。\n" +
               "このボットと個人チャットを開始して「認証」を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    shift_info = get_personal_shift_info(line_user_id)
    
    if shift_info
      shift_info
    else
      "シフト情報が見つかりませんでした。"
    end
  end

  def handle_all_shifts_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "全員シフト確認には認証が必要です。\n" +
               "このボットと個人チャットを開始して「認証」を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # グループメッセージの場合はグループIDを使用、個人メッセージの場合はnilを使用
    group_id = group_message?(event) ? extract_group_id(event) : nil
    group_info = get_group_shift_info(group_id)
    
    if group_info
      group_info
    else
      "シフト情報が見つかりませんでした。"
    end
  end

  # シフト交代コマンド処理
  def handle_shift_exchange_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "シフト交代には認証が必要です。\n" +
               "このボットと個人チャットを開始して「認証」を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # グループメッセージの場合は会話状態を設定しない
    unless group_message?(event)
      set_conversation_state(line_user_id, { step: 'waiting_shift_date' })
    end
    
    # 日付入力の案内を返す
    tomorrow = (Date.current + 1).strftime('%m/%d')
    "シフト交代依頼\n\n" +
    "交代したいシフトの日付を入力してください。\n\n" +
    "入力例: #{tomorrow}\n" +
    "過去の日付は選択できません"
  end

  def handle_request_check_command(event)
    line_user_id = utility_service.extract_user_id(event)
    
    # 認証チェック
    unless utility_service.employee_already_linked?(line_user_id)
      if utility_service.group_message?(event)
        return "リクエスト確認には認証が必要です。\n" +
               "このボットと個人チャットを開始して「認証」を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # 承認待ちのリクエストを取得
    employee = utility_service.find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    
    # シフト交代リクエスト
    pending_exchange_requests = ShiftExchange.where(
      approver_id: employee.employee_id,
      status: 'pending'
    ).includes(:shift)
    
    # シフト追加リクエスト
    pending_addition_requests = ShiftAddition.where(
      target_employee_id: employee.employee_id,
      status: 'pending'
    )
    
    if pending_exchange_requests.empty? && pending_addition_requests.empty?
      return "承認待ちのリクエストはありません"
    end
    
    # Flex Message形式でリクエストを表示
    message_service.generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)
  end

  def generate_exchange_requests_text(pending_requests)
    text = ""
    pending_requests.each do |request|
      shift = request.shift
      requester = Employee.find_by(employee_id: request.requester_id)
      requester_name = requester&.display_name || "ID: #{request.requester_id}"
      
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      text += "📅 #{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
      text += "👤 申請者: #{requester_name}\n"
      text += "🆔 リクエストID: #{request.request_id}\n\n"
    end
    text
  end

  def generate_addition_requests_text(pending_requests)
    text = ""
    pending_requests.each do |request|
      requester = Employee.find_by(employee_id: request.requester_id)
      requester_name = requester&.display_name || "ID: #{request.requester_id}"
      
      day_of_week = %w[日 月 火 水 木 金 土][request.shift_date.wday]
      text += "📅 #{request.shift_date.strftime('%m/%d')} (#{day_of_week}) #{request.start_time.strftime('%H:%M')}-#{request.end_time.strftime('%H:%M')}\n"
      text += "👤 申請者: #{requester_name}\n"
      text += "🆔 リクエストID: #{request.request_id}\n\n"
    end
    text
  end

  def generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)
    bubbles = []
    
    # シフト交代リクエストのカード
    pending_exchange_requests.each do |request|
      shift = request.shift
      requester = Employee.find_by(employee_id: request.requester_id)
      requester_name = requester&.display_name || "ID: #{request.requester_id}"
      
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      
      bubbles << {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            { type: "text", text: "🔄 シフト交代承認", weight: "bold", size: "xl", color: "#1DB446" },
            { type: "separator", margin: "md" },
            {
              type: "box", layout: "vertical", margin: "md", spacing: "sm", contents: [
                {
                  type: "box", layout: "baseline", spacing: "sm", contents: [
                    { type: "text", text: "👤", size: "sm", color: "#666666" },
                    { type: "text", text: "申請者: #{requester_name}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                  ]
                },
                {
                  type: "box", layout: "baseline", spacing: "sm", contents: [
                    { type: "text", text: "📅", size: "sm", color: "#666666" },
                    { type: "text", text: "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})", wrap: true, color: "#666666", size: "sm", flex: 0 }
                  ]
                },
                {
                  type: "box", layout: "baseline", spacing: "sm", contents: [
                    { type: "text", text: "⏰", size: "sm", color: "#666666" },
                    { type: "text", text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                  ]
                }
              ]
            }
          ]
        },
        footer: {
          type: "box", layout: "vertical", spacing: "sm", contents: [
            {
              type: "button", style: "primary", height: "sm", action: {
                type: "postback",
                label: "承認",
                data: "approve_exchange_#{request.id}",
                displayText: "#{shift.shift_date.strftime('%m/%d')}のシフト交代を承認します"
              }
            },
            {
              type: "button", style: "secondary", height: "sm", action: {
                type: "postback",
                label: "拒否",
                data: "reject_exchange_#{request.id}",
                displayText: "#{shift.shift_date.strftime('%m/%d')}のシフト交代を拒否します"
              }
            }
          ]
        }
      }
    end
    
    # シフト追加リクエストのカード
    pending_addition_requests.each do |request|
      requester = Employee.find_by(employee_id: request.requester_id)
      requester_name = requester&.display_name || "ID: #{request.requester_id}"
      
      day_of_week = %w[日 月 火 水 木 金 土][request.shift_date.wday]
      
      bubbles << {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            { type: "text", text: "➕ シフト追加承認", weight: "bold", size: "xl", color: "#FF6B6B" },
            { type: "separator", margin: "md" },
            {
              type: "box", layout: "vertical", margin: "md", spacing: "sm", contents: [
                {
                  type: "box", layout: "baseline", spacing: "sm", contents: [
                    { type: "text", text: "👤", size: "sm", color: "#666666" },
                    { type: "text", text: "申請者: #{requester_name}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                  ]
                },
                {
                  type: "box", layout: "baseline", spacing: "sm", contents: [
                    { type: "text", text: "📅", size: "sm", color: "#666666" },
                    { type: "text", text: "#{request.shift_date.strftime('%m/%d')} (#{day_of_week})", wrap: true, color: "#666666", size: "sm", flex: 0 }
                  ]
                },
                {
                  type: "box", layout: "baseline", spacing: "sm", contents: [
                    { type: "text", text: "⏰", size: "sm", color: "#666666" },
                    { type: "text", text: "#{request.start_time.strftime('%H:%M')}-#{request.end_time.strftime('%H:%M')}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                  ]
                }
              ]
            }
          ]
        },
        footer: {
          type: "box", layout: "vertical", spacing: "sm", contents: [
            {
              type: "button", style: "primary", height: "sm", action: {
                type: "postback",
                label: "承認",
                data: "approve_addition_#{request.id}",
                displayText: "#{request.shift_date.strftime('%m/%d')}のシフト追加を承認します"
              }
            },
            {
              type: "button", style: "secondary", height: "sm", action: {
                type: "postback",
                label: "拒否",
                data: "reject_addition_#{request.id}",
                displayText: "#{request.shift_date.strftime('%m/%d')}のシフト追加を拒否します"
              }
            }
          ]
        }
      }
    end

    {
      type: "flex",
      altText: "承認待ちのリクエスト",
      contents: {
        type: "carousel",
        contents: bubbles
      }
    }
  end




  # 認証コマンド処理
  def handle_auth_command(event)
    # グループメッセージの場合は認証を禁止
    if group_message?(event)
      return "認証は個人チャットでのみ利用できます。\n" +
             "このボットと個人チャットを開始してから「認証」と入力してください。"
    end
    
    line_user_id = extract_user_id(event)
    
    # 既に認証済みかチェック
    if employee_already_linked?(line_user_id)
      return "既に認証済みです。シフト確認などの機能をご利用いただけます。"
    end
    
    # 会話状態を設定
    set_conversation_state(line_user_id, { step: 'waiting_employee_name' })
    
    # 認証手順の説明
    "LINEアカウントと従業員アカウントを紐付ける認証を行います。\n\n" +
    "手順:\n" +
    "1. 従業員名を入力してください\n" +
    "   ※フルネームでも部分入力でも検索できます\n" +
    "   ※例: 田中太郎、田中、太郎\n" +
    "2. 認証コードがメールで送信されます\n" +
    "3. 認証コードを入力してください\n\n" +
    "従業員名を入力してください:"
  end

  def handle_employee_name_input(line_user_id, employee_name)
    # 従業員名で検索
    matches = search_employees_by_name(employee_name)
    
    if matches.empty?
      # 明らかに従業員名でない文字列（長すぎる、特殊文字が多い等）の場合は無視
      if employee_name.length > 20 || employee_name.match?(/[^\p{Hiragana}\p{Katakana}\p{Han}\s]/)
        return nil
      end
      
      return "「#{employee_name}」に該当する従業員が見つかりませんでした。\n\n" +
             "※苗字と名前の間に半角スペースを入れてください\n" +
             "※例: 田中 太郎、佐藤 花子\n\n" +
             "正しい名前を入力してください:"
    elsif matches.length == 1
      # 1件の場合は直接認証コード生成
      employee = matches.first
      return generate_verification_code_for_employee(line_user_id, employee)
    else
      # 複数件の場合は選択肢を提示
      return handle_multiple_employee_matches(line_user_id, employee_name, matches)
    end
  end

  def search_employees_by_name(name)
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      employees = freee_service.get_employees
      normalized_name = normalize_employee_name(name)
      
      # 部分一致で検索
      employees.select do |employee|
        display_name = employee[:display_name] || employee['display_name']
        next false unless display_name
        
        normalized_display_name = normalize_employee_name(display_name)
        
        normalized_display_name.include?(normalized_name) || 
        normalized_name.include?(normalized_display_name)
      end
    rescue => e
      Rails.logger.error "従業員検索エラー: #{e.message}"
      []
    end
  end

  # 従業員名の正規化
  def normalize_employee_name(name)
    name.tr('ァ-ヶ', 'ぁ-ゟ').tr('ー', 'ー')
  end

  def handle_multiple_employee_matches(line_user_id, employee_name, matches)
    message = "「#{employee_name}」に該当する従業員が複数見つかりました。\n\n"
    message += "該当する従業員の番号を入力してください:\n\n"
    
    matches.each_with_index do |employee, index|
      display_name = employee[:display_name] || employee['display_name']
      employee_id = employee[:id] || employee['id']
      message += "#{index + 1}. #{display_name} (ID: #{employee_id})\n"
    end
    
    message += "\n番号を入力してください:"
    message
  end

  def generate_verification_code_for_employee(line_user_id, employee)
    employee_id = employee[:id] || employee['id']
    display_name = employee[:display_name] || employee['display_name']
    
    # 認証コードを生成・送信
    begin
      # 既存の認証コードを削除
      VerificationCode.where(employee_id: employee_id).delete_all
      
      # 新しい認証コードを生成
      verification_code = VerificationCode.generate_code
      
      # 認証コードを保存
      VerificationCode.create!(
        employee_id: employee_id,
        line_user_id: line_user_id,
        code: verification_code,
        expires_at: 10.minutes.from_now
      )

      # 会話状態を更新
      set_conversation_state(line_user_id, { 
        step: 'waiting_verification_code', 
        employee_id: employee_id 
      })

      # メール送信
      begin
        AuthMailer.line_authentication_code(
          employee[:email] || employee['email'], 
          display_name, 
          verification_code
        ).deliver_now
        
        "「#{display_name}」さんの認証コードをメールで送信しました。\n" +
        "メールに記載された6桁の認証コードを入力してください。\n\n" +
        "認証コード:"
      rescue => mail_error
        Rails.logger.error "メール送信エラー: #{mail_error.message}"
        "「#{display_name}」さんの認証コードを生成しましたが、メール送信に失敗しました。\n" +
        "認証コード: #{verification_code}\n\n" +
        "この認証コードを入力してください:"
      end
    rescue => e
      Rails.logger.error "認証コード生成エラー: #{e.message}"
      "認証コードの生成中にエラーが発生しました。しばらく時間をおいてから再度お試しください。"
    end
  end

  def handle_verification_code_input(line_user_id, employee_id, verification_code)
    begin
      # 認証コードを検証
      verification_record = VerificationCode.find_valid_code(employee_id, verification_code)
      
      if verification_record.nil?
        return "認証コードが正しくありません。正しい認証コードを入力してください。"
      end

      if verification_record.expired?
        return "認証コードの有効期限が切れています。再度「認証」コマンドから始めてください。"
      end

      # LINEアカウントと従業員IDを紐付け
      employee = Employee.find_by(employee_id: employee_id)
      if employee.nil?
        # 従業員レコードが存在しない場合は作成
        employee = Employee.create!(
          employee_id: employee_id,
          role: determine_role_from_freee(employee_id),
          line_id: line_user_id
        )
      else
        # 既存の従業員レコードにLINE IDを設定
        employee.update!(line_id: line_user_id)
      end

      # 認証コードを削除
      verification_record.mark_as_used!

      # 会話状態をクリア
      clear_conversation_state(line_user_id)

      "認証が完了しました！\n\n" +
      "これで以下の機能をご利用いただけます:\n" +
      "・シフト確認: 個人のシフト確認\n" +
      "・全員シフト確認: グループ全体のシフト確認\n" +
      "・交代依頼: シフト交代依頼の送信\n" +
      "・追加依頼: シフト追加依頼の送信\n" +
      "・依頼確認: 承認待ちのシフト交代リクエスト確認\n" +
      "・ヘルプ: 利用可能なコマンド一覧"
    rescue => e
      Rails.logger.error "認証コード検証エラー: #{e.message}"
      "認証中にエラーが発生しました。しばらく時間をおいてから再度お試しください。"
    end
  end

  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  def get_authentication_status(line_user_id)
    employee = Employee.find_by(line_id: line_user_id)
    return nil unless employee

    {
      linked: true,
      employee_id: employee.employee_id,
      role: employee.role,
      display_name: employee.display_name
    }
  end

  # 会話状態管理
  def get_conversation_state(line_user_id)
    state_record = ConversationState.find_active_state(line_user_id)
    return nil unless state_record
    
    state_record.state_hash
  end

  def set_conversation_state(line_user_id, state)
    begin
      # 既存の状態を削除
      ConversationState.where(line_user_id: line_user_id).delete_all
      
      # 新しい状態を保存
      state_record = ConversationState.create!(
        line_user_id: line_user_id,
        state_data: state.to_json,
        expires_at: 30.minutes.from_now
      )
      
      state_record.persisted?
    rescue => e
      Rails.logger.error "会話状態設定エラー: #{e.message}"
      false
    end
  end

  def clear_conversation_state(line_user_id)
    begin
      ConversationState.where(line_user_id: line_user_id).delete_all
      true
    rescue => e
      Rails.logger.error "会話状態クリアエラー: #{e.message}"
      false
    end
  end

  # テスト用メソッド: 会話状態管理を含むメッセージ処理
  def handle_message_with_state(line_user_id, message_text)
    # 現在の会話状態を取得
    current_state = get_conversation_state(line_user_id)
    
    if current_state
      # 会話状態に基づいて処理
      handle_stateful_message(line_user_id, message_text, current_state)
    else
      # 通常のコマンド処理
      handle_command_message(line_user_id, message_text)
    end
  end

  private

  def generate_unknown_command_message
    "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
  end

  def handle_stateful_message(line_user_id, message_text, state)
    # コマンドの場合は会話状態をクリアして通常処理
    if COMMANDS.key?(message_text)
      clear_conversation_state(line_user_id)
      return handle_command_message(line_user_id, message_text)
    end

    case state['step']
    when 'waiting_employee_name'
      handle_employee_name_input(line_user_id, message_text)
    when 'waiting_verification_code'
      handle_verification_code_input(line_user_id, state['employee_id'], message_text)
    when 'waiting_shift_date'
      handle_shift_date_input(line_user_id, message_text)
    when 'waiting_shift_time'
      handle_shift_time_input(line_user_id, message_text, state)
    when 'waiting_employee_selection'
      handle_employee_selection_input(line_user_id, message_text, state)
    when 'waiting_confirmation'
      handle_confirmation_input(line_user_id, message_text, state)
    when 'waiting_shift_selection'
      handle_shift_selection_input(line_user_id, message_text)
    when 'waiting_cancel_confirmation'
      handle_cancel_confirmation_input(line_user_id, message_text)
    when 'waiting_shift_addition_date'
      handle_shift_addition_date_input(line_user_id, message_text)
    when 'waiting_shift_addition_time'
      handle_shift_addition_time_input(line_user_id, message_text, state)
    when 'waiting_shift_addition_employee'
      handle_shift_addition_employee_input(line_user_id, message_text, state)
    when 'waiting_shift_addition_confirmation'
      handle_shift_addition_confirmation_input(line_user_id, message_text, state)
    else
      # 不明な状態の場合は状態をクリアして通常処理
      clear_conversation_state(line_user_id)
      handle_command_message(line_user_id, message_text)
    end
  end

  def handle_command_message(line_user_id, message_text)
    # 既存のコマンド処理ロジックを使用
    event = mock_event_for_user(line_user_id, message_text)
    handle_message(event)
  rescue => e
    Rails.logger.error "コマンド処理エラー: #{e.message}"
    generate_unknown_command_message
  end

  def mock_event_for_user(line_user_id, message_text)
    # LINE Bot SDKのEventオブジェクトを模擬
    event = Object.new
    event.define_singleton_method(:source) { { 'type' => 'user', 'userId' => line_user_id } }
    event.define_singleton_method(:message) { { 'text' => message_text } }
    event.define_singleton_method(:type) { 'message' }
    event.define_singleton_method(:[]) { |key| send(key) }
    event
  end

  def determine_role_from_freee(employee_id)
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      employee_info = freee_service.get_employee_info(employee_id)
      return 'employee' unless employee_info
      
      # 店長のIDをチェック
      owner_id = '3313254' # 店長 太郎のID
      employee_info['id'].to_s == owner_id ? 'owner' : 'employee'
    rescue => e
      Rails.logger.error "役割判定エラー: #{e.message}"
      'employee' # デフォルトは従業員
    end
  end

  # シフト交代フローのハンドラーメソッド
  def handle_shift_date_input(line_user_id, message_text)
    # 日付の形式をチェック
    begin
      date = Date.parse(message_text)
      if date < Date.current
        return "過去の日付のシフト交代依頼はできません\n今日以降の日付を入力してください"
      end
      
      # 申請者の指定日付のシフトを取得
      employee = Employee.find_by(line_id: line_user_id)
      unless employee
        return "従業員情報が見つかりません。"
      end
      
      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: date
      ).order(:start_time)
      
      if shifts.empty?
        tomorrow = (Date.current + 1).strftime('%m/%d')
        return "指定された日付のシフトが見つかりません。\n再度日付を入力してください。\n\n例: #{tomorrow}"
      end
      
      # シフトカードを生成して返す
      generate_shift_flex_message_for_date(shifts)
    rescue Date::Error
      tomorrow = (Date.current + 1).strftime('%m/%d')
      return "日付の形式が正しくありません。\n例: #{tomorrow}"
    end
  end

  def handle_shift_time_input(line_user_id, message_text, state)
    # 時間の形式をチェック
    if message_text.match?(/^\d{2}:\d{2}-\d{2}:\d{2}$/)
      # 依頼可能な従業員を取得
      available_employees = get_available_employees_for_exchange(state['shift_date'], message_text)
      
      if available_employees.empty?
        return "指定された時間は、全従業員が既にシフトに入っています\n別の時間を選択してください"
      end
      
      # 次のステップに進む
      set_conversation_state(line_user_id, { 
        step: 'waiting_employee_selection',
        shift_date: state['shift_date'],
        shift_time: message_text
      })
      
      # 依頼可能な従業員リストを表示
      employee_list = "👥 依頼可能な従業員一覧\n\n"
      available_employees.each_with_index do |employee, index|
        employee_list += "#{index + 1}. #{employee[:display_name]}\n"
      end
      employee_list += "\n従業員名を入力してください\n" +
                       "フルネームでも部分入力でも検索できます\n" +
                       "複数選択の場合は「,」で区切って入力"
      
      employee_list
    else
      "時間の形式が正しくありません\n" +
      "HH:MM-HH:MM形式で入力してください（例: 09:00-18:00）"
    end
  end

  def handle_employee_selection_input(line_user_id, message_text, state)
    # 従業員選択の処理（名前のみ）
    selection_result = parse_employee_selection(message_text)
    
    if selection_result[:error]
      return selection_result[:error]
    end
    
    selected_employees = selection_result[:employee_ids]
    
    if selected_employees.empty?
      return "❌ 従業員が見つかりませんでした\n\n" +
             "📝 従業員名を入力してください"
    end
    
    # 選択された従業員の重複チェック
    overlap_results = []
    selected_employees.each do |employee_id|
      overlap_result = check_employee_shift_overlap(employee_id, state['shift_date'], state['shift_time'])
      overlap_results << { employee_id: employee_id, result: overlap_result }
    end
    
    # 重複がある従業員をチェック
    overlapping_employees = overlap_results.select { |r| r[:result][:has_overlap] }
    
    if overlapping_employees.any?
      overlap_message = "以下の従業員は指定された時間にシフトが入っています:\n\n"
      overlapping_employees.each do |overlap|
        employee = Employee.find_by(employee_id: overlap[:employee_id])
        employee_name = employee&.display_name || "ID: #{overlap[:employee_id]}"
        overlap_message += "👤 #{employee_name}\n" +
                          "⏰ 重複時間: #{overlap[:result][:overlap_time]}\n\n"
      end
      overlap_message += "別の従業員を選択してください\n\n× 従業員が見つかりません"
      return overlap_message
    end
    
    # 選択された従業員IDで依頼を送信
    set_conversation_state(line_user_id, { 
      step: 'waiting_confirmation',
      shift_date: state['shift_date'],
      shift_time: state['shift_time'],
      selected_employee_ids: selected_employees
    })
    
    # 確認メッセージの生成
    confirmation_message = "✅ シフト交代依頼の確認\n\n"
    confirmation_message += "📅 日付: #{state['shift_date']}\n"
    confirmation_message += "⏰ 時間: #{state['shift_time']}\n"
    confirmation_message += "👥 交代先: "
    
    if selected_employees.length == 1
      employee = Employee.find_by(employee_id: selected_employees.first)
      employee_name = employee&.display_name || "ID: #{selected_employees.first}"
      confirmation_message += employee_name
    else
      employee_names = selected_employees.map do |employee_id|
        employee = Employee.find_by(employee_id: employee_id)
        employee&.display_name || "ID: #{employee_id}"
      end
      confirmation_message += employee_names.join(", ")
    end
    
    confirmation_message += "\n\n📤 この内容で依頼を送信しますか？\n"
    confirmation_message += "💬 「はい」または「いいえ」で回答してください"
    
    confirmation_message
  end

  # 従業員選択の解析（名前のみ）
  def parse_employee_selection(message_text)
    # カンマ区切りで分割
    selections = message_text.split(',').map(&:strip)
    employee_ids = []
    ambiguous_names = []
    not_found_names = []
    
    selections.each do |selection|
      # 名前での検索のみ
      found_employees = find_employees_by_name(selection)
      
      if found_employees.empty?
        not_found_names << selection
      elsif found_employees.length > 1
        ambiguous_names << selection
      else
        # 1つ見つかった場合は追加
        employee_ids << found_employees.first.employee_id
      end
    end
    
    # エラーメッセージの生成
    error_messages = []
    
    if ambiguous_names.any?
      error_messages << "複数の従業員が見つかりました: #{ambiguous_names.join(', ')}\nより具体的な名前を入力してください"
    end
    
    if not_found_names.any?
      error_messages << "❌ 従業員が見つかりません: #{not_found_names.join(', ')}"
    end
    
    if error_messages.any?
      return { error: error_messages.join("\n"), employee_ids: [] }
    end
    
    { error: nil, employee_ids: employee_ids.uniq }
  end

  # 名前での従業員検索
  def find_employees_by_name(name)
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      employees = freee_service.get_employees
      normalized_name = normalize_employee_name(name)
      
      # 部分一致で検索
      employees.select do |employee|
        display_name = employee[:display_name] || employee['display_name']
        next false unless display_name
        
        normalized_display_name = normalize_employee_name(display_name)
        
        normalized_display_name.include?(normalized_name) || 
        normalized_name.include?(normalized_display_name)
      end
    rescue => e
      Rails.logger.error "従業員検索エラー: #{e.message}"
      []
    end
  end

  def handle_confirmation_input(line_user_id, message_text, state)
    if message_text == 'はい'
      # シフト交代依頼を作成
      result = create_shift_exchange_request(line_user_id, state)
      
      if result[:success]
        # 会話状態をクリア
        clear_conversation_state(line_user_id)
        result[:message]
      else
        result[:message]
      end
    elsif message_text == 'いいえ'
      # 会話状態をクリア
      clear_conversation_state(line_user_id)
      "✅ シフト交代依頼をキャンセルしました"
    else
      "💬 「はい」または「いいえ」で回答してください"
    end
  end

  def handle_cancel_confirmation_input(line_user_id, message_text)
    # リクエストIDが数字かチェック
    if message_text.match?(/^\d+$/)
      request_id = message_text.to_i
      
      # キャンセル処理を実行
      result = cancel_shift_exchange_request(line_user_id, request_id)
      
      # 会話状態をクリア
      clear_conversation_state(line_user_id)
      
      result[:message]
    else
      "リクエストIDを数字で入力してください。"
    end
  end

  # 依頼可能な従業員を取得
  def get_available_employees_for_exchange(shift_date, shift_time)
    return [] if shift_date.nil? || shift_time.nil?
    
    start_time, end_time = parse_shift_time(shift_time)
    date = Date.parse(shift_date)
    
    # 全従業員を取得
    all_employees = Employee.all
    
    available_employees = []
    all_employees.each do |employee|
      # シフト重複チェック
      overlap_result = check_employee_shift_overlap(employee.employee_id, shift_date, shift_time)
      unless overlap_result[:has_overlap]
        available_employees << {
          employee_id: employee.employee_id,
          display_name: employee.display_name
        }
      end
    end
    
    available_employees
  end

  # 従業員のシフト重複チェック
  def check_employee_shift_overlap(employee_id, shift_date, shift_time)
    start_time, end_time = parse_shift_time(shift_time)
    date = Date.parse(shift_date)
    
    # 既存のシフトを取得
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
    )
    
    overlapping_shift = existing_shifts.find do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
    
    if overlapping_shift
      {
        has_overlap: true,
        overlap_time: "#{overlapping_shift.start_time.strftime('%H:%M')}-#{overlapping_shift.end_time.strftime('%H:%M')}"
      }
    else
      { has_overlap: false }
    end
  end

  # シフト時間をパース
  def parse_shift_time(shift_time)
    start_time_str, end_time_str = shift_time.split('-')
    [Time.zone.parse(start_time_str), Time.zone.parse(end_time_str)]
  end

  # 2つのシフト時間が重複しているかチェック
  def shift_overlaps?(existing_shift, new_start_time, new_end_time)
    # 既存シフトの時間をTimeオブジェクトに変換
    existing_start = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.start_time.strftime('%H:%M')}")
    existing_end = Time.zone.parse("#{existing_shift.shift_date} #{existing_shift.end_time.strftime('%H:%M')}")
    
    # 新しいシフトの時間をTimeオブジェクトに変換
    new_start = Time.zone.parse("#{existing_shift.shift_date} #{new_start_time.strftime('%H:%M')}")
    new_end = Time.zone.parse("#{existing_shift.shift_date} #{new_end_time.strftime('%H:%M')}")
    
    # 重複チェック: 新しいシフトの開始時間が既存シフトの終了時間より前で、
    # 新しいシフトの終了時間が既存シフトの開始時間より後
    new_start < existing_end && new_end > existing_start
  end

  # シフト交代依頼を作成
  def create_shift_exchange_request(line_user_id, state)
    begin
      employee = Employee.find_by(line_id: line_user_id)
      return { success: false, message: "従業員情報が見つかりません。" } unless employee
      
      # 申請者のシフトを取得
      shift = Shift.where(
        employee_id: employee.employee_id,
        shift_date: Date.parse(state['shift_date'])
      ).first
      
      return { success: false, message: "申請者のシフトが見つかりません。" } unless shift
      
      # 期限切れチェック：過去の日付のシフト交代依頼は不可
      if shift.shift_date < Date.current
        return { success: false, message: "過去の日付のシフト交代依頼はできません。" }
      end
      
      # 選択された従業員IDを取得（単一または複数）
      selected_employee_ids = state['selected_employee_ids'] || [state['selected_employee_id']]
      
      # 重複チェック：同じシフトに対して同じ承認者へのpendingリクエストが存在しないか確認
      existing_requests = ShiftExchange.where(
        requester_id: employee.employee_id,
        approver_id: selected_employee_ids,
        shift_id: shift.id,
        status: 'pending'
      )
      
      if existing_requests.any?
        existing_approver_names = existing_requests.map do |req|
          approver = Employee.find_by(employee_id: req.approver_id)
          approver&.display_name || "ID: #{req.approver_id}"
        end
        return { success: false, message: "以下の従業員には既にシフト交代依頼が存在します: #{existing_approver_names.join(', ')}" }
      end
      
      # 各承認者に対してShiftExchangeレコードを作成
      created_requests = []
      selected_employee_ids.each do |approver_id|
        exchange_request = ShiftExchange.create!(
          request_id: generate_request_id,
          requester_id: employee.employee_id,
          approver_id: approver_id,
          shift_id: shift.id,
          status: 'pending'
        )
        created_requests << exchange_request
        
        # 承認者に通知を送信
        send_shift_exchange_request_notification(exchange_request)
        
        # メール通知を送信
        send_shift_exchange_request_email_notification(exchange_request)
      end
      
      approver_names = selected_employee_ids.map do |approver_id|
        approver = Employee.find_by(employee_id: approver_id)
        approver&.display_name || "ID: #{approver_id}"
      end
      
      { success: true, message: "✅ シフト交代依頼を送信しました！\n👥 承認者: #{approver_names.join(', ')}" }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "シフト交代依頼作成バリデーションエラー: #{e.message}"
      { success: false, message: "入力データに問題があります。内容を確認して再度お試しください。" }
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "シフト交代依頼作成レコード未発見エラー: #{e.message}"
      { success: false, message: "関連するデータが見つかりません。管理者にお問い合わせください。" }
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error "シフト交代依頼作成データベースエラー: #{e.message}"
      { success: false, message: "データベースエラーが発生しました。しばらく時間をおいてから再度お試しください。" }
    rescue => e
      Rails.logger.error "シフト交代依頼作成予期しないエラー: #{e.message}"
      Rails.logger.error "エラーバックトレース: #{e.backtrace.join('\n')}"
      { success: false, message: "予期しないエラーが発生しました。管理者にお問い合わせください。" }
    end
  end

  # シフト交代依頼をキャンセル
  def cancel_shift_exchange_request(line_user_id, request_id)
    begin
      employee = Employee.find_by(line_id: line_user_id)
      return { success: false, message: "従業員情報が見つかりません。" } unless employee
      
      # リクエストを取得
      exchange_request = ShiftExchange.find_by(id: request_id)
      return { success: false, message: "シフト交代リクエストが見つかりません。" } unless exchange_request
      
      # 権限チェック（申請者のみキャンセル可能）
      unless exchange_request.requester_id == employee.employee_id
        return { success: false, message: "このリクエストをキャンセルする権限がありません。" }
      end
      
      # ステータスチェック（pendingのみキャンセル可能）
      case exchange_request.status
      when 'approved'
        return { success: false, message: "承認済みのリクエストはキャンセルできません。" }
      when 'rejected'
        return { success: false, message: "既に処理済みのリクエストはキャンセルできません。" }
      when 'cancelled'
        return { success: false, message: "既にキャンセル済みのリクエストです。" }
      end
      
      # リクエストをキャンセル
      exchange_request.cancel!
      
      { success: true, message: "✅ シフト交代依頼をキャンセルしました" }
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "シフト交代依頼キャンセルレコード未発見エラー: #{e.message}"
      { success: false, message: "キャンセル対象のリクエストが見つかりません。" }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "シフト交代依頼キャンセルバリデーションエラー: #{e.message}"
      { success: false, message: "キャンセル処理でデータの整合性エラーが発生しました。" }
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error "シフト交代依頼キャンセルデータベースエラー: #{e.message}"
      { success: false, message: "データベースエラーが発生しました。しばらく時間をおいてから再度お試しください。" }
    rescue => e
      Rails.logger.error "シフト交代依頼キャンセル予期しないエラー: #{e.message}"
      Rails.logger.error "エラーバックトレース: #{e.backtrace.join('\n')}"
      { success: false, message: "予期しないエラーが発生しました。管理者にお問い合わせください。" }
    end
  end

  # リクエストIDを生成
  def generate_request_id
    "REQ_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # シフト交代依頼のメール通知を送信
  def send_shift_exchange_request_email_notification(exchange_request)
    # テスト環境ではメール送信をスキップ
    return nil if Rails.env.test?
    
    begin
      email_service = EmailNotificationService.new
      email_service.send_shift_exchange_request(
        exchange_request.requester_id,
        [exchange_request.approver_id],
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )
    rescue => e
      Rails.logger.error "シフト交代依頼メール送信エラー: #{e.message}"
      nil
    end
  end

  # シフト交代承認のメール通知を送信
  def send_shift_exchange_approved_email_notification(exchange_request)
    # テスト環境ではメール送信をスキップ
    return nil if Rails.env.test?
    
    begin
      email_service = EmailNotificationService.new
      email_service.send_shift_exchange_approved(
        exchange_request.requester_id,
        exchange_request.approver_id,
        exchange_request.shift.shift_date,
        exchange_request.shift.start_time,
        exchange_request.shift.end_time
      )
    rescue => e
      Rails.logger.error "シフト交代承認メール送信エラー: #{e.message}"
      nil
    end
  end

  # シフト交代否認のメール通知を送信
  def send_shift_exchange_denied_email_notification(exchange_request)
    # テスト環境ではメール送信をスキップ
    return nil if Rails.env.test?
    
    begin
      email_service = EmailNotificationService.new
      email_service.send_shift_exchange_denied(
        exchange_request.requester_id
      )
    rescue => e
      Rails.logger.error "シフト交代否認メール送信エラー: #{e.message}"
      nil
    end
  end


  # 指定日付のシフト用Flex Message形式のシフトカードを生成
  def generate_shift_flex_message_for_date(shifts)
    # カルーセル形式のFlex Messageを生成
    bubbles = shifts.map do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      
      {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "シフト交代依頼",
              weight: "bold",
              size: "xl",
              color: "#1DB446"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "box",
              layout: "vertical",
              margin: "md",
              spacing: "sm",
              contents: [
                {
                  type: "box",
                  layout: "baseline",
                  spacing: "sm",
                  contents: [
                    {
                      type: "text",
                      text: "📅",
                      size: "sm",
                      color: "#666666"
                    },
                    {
                      type: "text",
                      text: "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})",
                      wrap: true,
                      color: "#666666",
                      size: "sm",
                      flex: 0
                    }
                  ]
                },
                {
                  type: "box",
                  layout: "baseline",
                  spacing: "sm",
                  contents: [
                    {
                      type: "text",
                      text: "⏰",
                      size: "sm",
                      color: "#666666"
                    },
                    {
                      type: "text",
                      text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}",
                      wrap: true,
                      color: "#666666",
                      size: "sm",
                      flex: 0
                    }
                  ]
                }
              ]
            }
          ]
        },
        footer: {
          type: "box",
          layout: "vertical",
          spacing: "sm",
          contents: [
            {
              type: "button",
              style: "primary",
              height: "sm",
              action: {
                type: "postback",
                label: "交代を依頼",
                data: "shift_#{shift.id}",
                displayText: "#{shift.shift_date.strftime('%m/%d')}のシフト交代を依頼します"
              }
            }
          ]
        }
      }
    end

    # カルーセル形式のFlex Message
    {
      type: "flex",
      altText: "シフト交代依頼 - 交代したいシフトを選択してください",
      contents: {
        type: "carousel",
        contents: bubbles
      }
    }
  end


  # シフト選択の処理
  def handle_shift_selection_input(line_user_id, message_text)
    # shift_XXX形式のメッセージを処理
    if message_text.match?(/^shift_\d+$/)
      shift_id = message_text.split('_')[1]
      shift = Shift.find_by(id: shift_id)
      
      unless shift
        return "選択されたシフトが見つかりません。もう一度選択してください。"
      end
      
      # シフト情報を会話状態に保存して従業員選択に進む
      set_conversation_state(line_user_id, { 
        step: 'waiting_employee_selection',
        shift_id: shift_id,
        shift_date: shift.shift_date.strftime('%Y-%m-%d'),
        shift_time: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}"
      })
      
      # 依頼可能な従業員を取得
      available_employees = get_available_employees_for_exchange(shift.shift_date.strftime('%Y-%m-%d'), "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}")
      
      if available_employees.empty?
        return "指定された時間は、全従業員が既にシフトに入っています\n別の時間を選択してください"
      end
      
      # 依頼可能な従業員リストを表示
      employee_list = "選択されたシフト:\n" +
                     "📅 #{shift.shift_date.strftime('%m/%d')} (#{%w[日 月 火 水 木 金 土][shift.shift_date.wday]})\n" +
                     "⏰ #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n\n" +
                     "👥 依頼可能な従業員一覧\n\n"
      available_employees.each_with_index do |employee, index|
        employee_list += "#{index + 1}. #{employee[:display_name]}\n"
      end
      employee_list += "\n従業員名を入力してください\n" +
                       "フルネームでも部分入力でも検索できます\n" +
                       "複数選択の場合は「,」で区切って入力"
      
      employee_list
    else
      "シフト選択が正しくありません。\n" +
      "「shift_XXX」形式で選択してください。"
    end
  end

  # シフト追加リクエストコマンドの処理
  def handle_shift_addition_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "シフト追加には認証が必要です。\n" +
               "このボットと個人チャットを開始して「認証」を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # オーナー権限チェック
    employee = Employee.find_by(line_id: line_user_id)
    unless employee&.owner?
      return "シフト追加はオーナーのみが利用可能です。"
    end
    
    
    # 日付入力待ちの状態を設定
    set_conversation_state(line_user_id, { 
      step: 'waiting_shift_addition_date'
    })
    
    tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
    "📅 シフト追加依頼\n\n" +
    "日付を入力してください（例：#{tomorrow}）\n" +
    "※ 過去の日付は指定できません"
  end

  # シフト追加の日付入力処理
  def handle_shift_addition_date_input(line_user_id, message_text)
    # 日付形式の検証
    date_validation_result = validate_shift_date(message_text)
    return date_validation_result[:error] if date_validation_result[:error]
    
    # 時間入力待ちの状態を設定
    set_conversation_state(line_user_id, { 
      step: 'waiting_shift_addition_time',
      shift_date: date_validation_result[:date].strftime('%Y-%m-%d')
    })
    
    "⏰ 時間を入力してください（例：09:00-18:00）"
  end

  # シフト追加の時間入力処理
  def handle_shift_addition_time_input(line_user_id, message_text, state)
    # 時間形式の検証
    time_validation_result = validate_shift_time(message_text)
    return time_validation_result[:error] if time_validation_result[:error]
    
    # 従業員選択待ちの状態を設定
    set_conversation_state(line_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: state['shift_date'],
      shift_time: message_text
    })
    
    "👥 対象従業員を選択してください\n\n" +
    "💡 入力例：\n" +
    "• 田中太郎\n" +
    "• 田中\n" +
    "• 複数人: 田中太郎,佐藤花子\n\n" +
    "※ 複数人に送信する場合は「,」で区切って入力してください"
  end

  # シフト追加の従業員選択処理
  def handle_shift_addition_employee_input(line_user_id, message_text, state)
    # 複数の従業員名を処理（カンマ区切り）
    employee_names = message_text.split(',').map(&:strip)
    
    # 各従業員名で検索
    all_employees = []
    not_found_names = []
    
    employee_names.each do |name|
      employees = find_employees_by_name(name)
      if employees.empty?
        not_found_names << name
      elsif employees.size == 1
        all_employees << employees.first
      else
        # 複数の従業員が見つかった場合
        employee_list = "「#{name}」で複数の従業員が見つかりました：\n\n"
        employees.each_with_index do |employee, index|
          employee_list += "#{index + 1}. #{employee.display_name}\n"
        end
        employee_list += "\nより具体的な名前を入力してください。"
        return employee_list
      end
    end
    
    # 見つからない従業員がいる場合
    if not_found_names.any?
      return "❌ 従業員が見つかりません: #{not_found_names.join(', ')}\n\n" +
             "フルネームでも部分入力でも検索できます。\n" +
             "例: 田中太郎、田中、太郎"
    end
    
    # 重複チェック
    overlap_service = ShiftOverlapService.new
    overlapping_employees = []
    available_employees = []
    
    all_employees.each do |employee|
      overlapping_employee = overlap_service.check_addition_overlap(
        employee.employee_id,
        Date.parse(state['shift_date']),
        Time.zone.parse(state['shift_time'].split('-')[0]),
        Time.zone.parse(state['shift_time'].split('-')[1])
      )
      
      if overlapping_employee
        overlapping_employees << employee.display_name
      else
        available_employees << employee
      end
    end
    
    # 重複がある場合の処理
    if overlapping_employees.any?
      if available_employees.empty?
        return "⚠️ 指定された従業員は全員、指定された時間にシフトが入っています：\n" +
               "#{overlapping_employees.join(', ')}\n\n" +
               "別の従業員を選択してください。"
      else
        # 一部重複がある場合
        overlap_message = "⚠️ 以下の従業員は指定された時間にシフトが入っています：\n" +
                         "#{overlapping_employees.join(', ')}\n\n" +
                         "依頼可能な従業員のみに送信しますか？\n\n"
      end
    end
    
    # 確認待ちの状態を設定
    set_conversation_state(line_user_id, { 
      step: 'waiting_shift_addition_confirmation',
      shift_date: state['shift_date'],
      shift_time: state['shift_time'],
      target_employee_ids: available_employees.map(&:employee_id)
    })
    
    # 確認メッセージの生成
    confirmation_message = "📋 シフト追加依頼の確認\n\n" +
    "📅 日付: #{Date.parse(state['shift_date']).strftime('%m/%d')} (#{%w[日 月 火 水 木 金 土][Date.parse(state['shift_date']).wday]})\n" +
    "⏰ 時間: #{state['shift_time']}\n" +
    "👥 対象: #{available_employees.map(&:display_name).join(', ')}\n\n"
    
    if overlapping_employees.any?
      confirmation_message += overlap_message
    end
    
    confirmation_message += "この内容で依頼を送信しますか？\n" +
    "「はい」または「いいえ」で回答してください。"
    
    confirmation_message
  end

  # シフト追加の確認処理
  def handle_shift_addition_confirmation_input(line_user_id, message_text, state)
    case message_text
    when 'はい'
      create_shift_addition_request(line_user_id, state)
    when 'いいえ'
      clear_conversation_state(line_user_id)
      "❌ シフト追加依頼をキャンセルしました。"
    else
      "「はい」または「いいえ」で回答してください。"
    end
  end

  # シフト追加リクエストの作成
  def create_shift_addition_request(line_user_id, state)
    begin
      employee = Employee.find_by(line_id: line_user_id)
      return "従業員情報が見つかりません。" unless employee
      
      # 時間をパース
      start_time_str, end_time_str = state['shift_time'].split('-')
      
      # 複数の従業員にリクエストを作成
      target_employee_ids = state['target_employee_ids'] || [state['target_employee_id']]
      created_requests = []
      
      target_employee_ids.each do |target_employee_id|
        request = ShiftAddition.create!(
          request_id: generate_request_id,
          requester_id: employee.employee_id,
          target_employee_id: target_employee_id,
          shift_date: Date.parse(state['shift_date']),
          start_time: Time.zone.parse(start_time_str),
          end_time: Time.zone.parse(end_time_str),
          status: 'pending'
        )
        created_requests << request
      end
      
      # 会話状態をクリア
      clear_conversation_state(line_user_id)
      
      # メール通知を送信
      send_shift_addition_notifications(created_requests)
      
      target_count = target_employee_ids.size
      if target_count == 1
        "✅ シフト追加依頼を送信しました。\n" +
        "対象従業員に通知が送信されます。"
      else
        "✅ #{target_count}名の従業員にシフト追加依頼を送信しました。\n" +
        "対象従業員に通知が送信されます。"
      end
      
    rescue => e
      Rails.logger.error "シフト追加リクエスト作成エラー: #{e.message}"
      "❌ 依頼の送信に失敗しました。\n" +
      "しばらく時間をおいてから再度お試しください。"
    end
  end

  # シフト追加リクエストのメール通知を送信
  def send_shift_addition_notifications(shift_additions)
    return if Rails.env.test? # テスト環境ではスキップ
    
    email_service = EmailNotificationService.new
    
    shift_additions.each do |shift_addition|
      email_service.send_shift_addition_request(
        shift_addition.target_employee_id,
        shift_addition.shift_date,
        shift_addition.start_time,
        shift_addition.end_time
      )
    end
  end

  # リクエストID生成
  def generate_request_id
    "ADD_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # シフト追加承認メール送信
  def send_shift_addition_approval_email(addition_request)
    begin
      email_service = EmailNotificationService.new
      # 従業員情報を取得
      target_employee = Employee.find_by(employee_id: addition_request.target_employee_id)
      
      email_service.send_shift_addition_approved(
        addition_request.requester_id,
        target_employee&.display_name || "対象従業員",
        addition_request.shift_date,
        addition_request.start_time,
        addition_request.end_time
      )
    rescue => e
      Rails.logger.error "シフト追加承認メール送信エラー: #{e.message}"
    end
  end

  # シフト追加拒否メール送信
  def send_shift_addition_rejection_email(addition_request)
    begin
      email_service = EmailNotificationService.new
      # 従業員情報を取得
      target_employee = Employee.find_by(employee_id: addition_request.target_employee_id)
      
      email_service.send_shift_addition_denied(
        addition_request.requester_id,
        target_employee&.display_name || "対象従業員"
      )
    rescue => e
      Rails.logger.error "シフト追加拒否メール送信エラー: #{e.message}"
    end
  end

  # 日付検証の共通メソッド
  def validate_shift_date(date_text)
    begin
      date = Date.parse(date_text)
      if date < Date.current
        tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
        return { error: "過去の日付は指定できません。\n日付を入力してください（例：#{tomorrow}）" }
      end
      { date: date }
    rescue ArgumentError
      tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
      { error: "日付の形式が正しくありません。\n例：#{tomorrow}" }
    end
  end

  # 時間検証の共通メソッド
  def validate_shift_time(time_text)
    # 時間形式の検証（HH:MM-HH:MM）
    unless time_text.match?(/^\d{2}:\d{2}-\d{2}:\d{2}$/)
      return { error: "時間の形式が正しくありません。\n例：09:00-18:00" }
    end
    
    begin
      start_time_str, end_time_str = time_text.split('-')
      start_time = Time.zone.parse(start_time_str)
      end_time = Time.zone.parse(end_time_str)
      
      if start_time >= end_time
        return { error: "開始時間は終了時間より早く設定してください。\n例：09:00-18:00" }
      end
      { start_time: start_time, end_time: end_time }
    rescue ArgumentError
      { error: "時間の形式が正しくありません。\n例：09:00-18:00" }
    end
  end

  # テスト用のメソッド
  public
end
