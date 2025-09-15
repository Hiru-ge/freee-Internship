class LineBotService
  COMMANDS = {
    'ヘルプ' => :help,
    'help' => :help,
    '認証' => :auth,
    'シフト' => :shift,
    '勤怠' => :attendance,
    '全員シフト' => :all_shifts
  }.freeze

  def initialize
  end

  def handle_message(event)
    case determine_command_context(event)
    when :help
      generate_help_message(event)
    when :auth
      handle_auth_command(event)
    when :shift
      handle_shift_command(event)
    when :attendance
      "勤怠確認機能は準備中です。"
    when :all_shifts
      handle_all_shifts_command(event)
    else
      generate_unknown_command_message
    end
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
    when 'シフト'
      :shift
    when '勤怠'
      :attendance
    when '全員シフト'
      :all_shifts
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
    if event && group_message?(event)
      "勤怠管理システムへようこそ！\n\n【グループで利用可能なコマンド】\n- ヘルプ: このメッセージを表示\n- 全員シフト: グループ全体のシフト情報を確認\n\n【個人チャットで利用可能なコマンド】\n- 認証: LINEアカウントと従業員アカウントを紐付け\n- シフト: 個人のシフト情報を確認\n- 勤怠: 勤怠状況を確認（準備中）\n\n※個人の機能を利用するには、このボットと個人チャットを開始して「認証」を行ってください。"
    else
      "勤怠管理システムへようこそ！\n\n【利用可能なコマンド】\n- ヘルプ: このメッセージを表示\n- 認証: LINEアカウントと従業員アカウントを紐付け\n- シフト: 個人のシフト情報を確認\n- 勤怠: 勤怠状況を確認（準備中）\n\n※グループでは「全員シフト」コマンドも利用できます。"
    end
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
    if group_message?(event)
      group_id = extract_group_id(event)
      group_info = get_group_shift_info(group_id)
      
      if group_info
        group_info
      else
        "グループ内のシフト情報が見つかりませんでした。"
      end
    else
      "全員シフト確認はグループ内でのみ利用できます。"
    end
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
    "   ※苗字と名前の間に半角スペースを入れてください\n" +
    "   ※例: 田中 太郎、佐藤 花子\n" +
    "2. 認証コードがメールで送信されます\n" +
    "3. 認証コードを入力してください\n\n" +
    "従業員名を入力してください:"
  end

  def handle_employee_name_input(line_user_id, employee_name)
    # 従業員名で検索
    matches = search_employees_by_name(employee_name)
    
    if matches.empty?
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
      
      # 全従業員を取得
      all_employees = freee_service.get_employees
      
      # 名前で部分一致検索（大文字小文字を区別しない）
      matches = all_employees.select do |employee|
        display_name = employee[:display_name] || employee['display_name']
        display_name&.downcase&.include?(name.downcase)
      end
      
      matches
    rescue => e
      Rails.logger.error "従業員検索エラー: #{e.message}"
      []
    end
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
      "• シフト: 個人のシフト確認\n" +
      "• 全員シフト: グループ全体のシフト確認\n" +
      "• ヘルプ: 利用可能なコマンド一覧"
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
    case state['step']
    when 'waiting_employee_name'
      handle_employee_name_input(line_user_id, message_text)
    when 'waiting_verification_code'
      handle_verification_code_input(line_user_id, state['employee_id'], message_text)
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
end
