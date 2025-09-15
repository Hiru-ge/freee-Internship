class LineBotService
  COMMANDS = {
    'ヘルプ' => :help,
    'help' => :help,
    '認証' => :auth,
    'シフト' => :shift,
    '勤怠' => :attendance
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
      "シフト確認機能は準備中です。"
    when :attendance
      "勤怠確認機能は準備中です。"
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

  def generate_help_message
    "勤怠管理システムへようこそ！\n\n利用可能なコマンド:\n- ヘルプ: このメッセージを表示\n- 認証: 認証コードを生成\n- シフト: シフト情報を確認\n- 勤怠: 勤怠状況を確認"
  end

  private

  def generate_unknown_command_message
    "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
  end
end
