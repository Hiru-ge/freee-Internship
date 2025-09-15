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
    message_text = event.message['text']
    command = COMMANDS[message_text]
    
    case command
    when :help
      generate_help_message
    when :auth
      "認証機能は準備中です。"
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
    nil
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

  def generate_help_message
    "勤怠管理システムへようこそ！\n\n利用可能なコマンド:\n- ヘルプ: このメッセージを表示\n- 認証: 認証コードを生成\n- シフト: シフト情報を確認\n- 勤怠: 勤怠状況を確認"
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
    employees = Employee.where.not(line_id: nil)
    
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
    shift_info = get_personal_shift_info(line_user_id)
    
    if shift_info
      shift_info
    else
      "シフト情報が見つかりませんでした。\n認証が完了していない場合は、まず「認証」コマンドでアカウントを紐付けてください。"
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

  private

  def generate_unknown_command_message
    "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
  end
end
