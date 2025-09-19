# frozen_string_literal: true

class LineBotService
  COMMANDS = {
    "ヘルプ" => :help,
    "認証" => :auth,
    "シフト確認" => :shift,
    "全員シフト確認" => :all_shifts,
    "交代依頼" => :shift_exchange,
    "追加依頼" => :shift_addition,
    "欠勤申請" => :shift_deletion,
    "依頼確認" => :request_check
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

  def deletion_service
    @deletion_service ||= LineShiftDeletionService.new
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
    return handle_postback_event(event) if event["type"] == "postback"

    message_text = event["message"]["text"]
    line_user_id = utility_service.extract_user_id(event)

    # 会話状態をチェック
    state = conversation_service.get_conversation_state(line_user_id)
    Rails.logger.debug "LineBotService: line_user_id = #{line_user_id}, state = #{state}, message_text = #{message_text}"
    return conversation_service.handle_stateful_message(line_user_id, message_text, state) if state

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
    when :shift_deletion
      deletion_service.handle_shift_deletion_command(event)
    when :request_check
      handle_request_check_command(event)
    else
      # コマンド以外のメッセージの処理
      handle_non_command_message(event)
    end
  end

  # Postbackイベントの処理
  def handle_postback_event(event)
    line_user_id = utility_service.extract_user_id(event)
    postback_data = event["postback"]["data"]

    # 認証チェック
    return "認証が必要です。「認証」と入力して認証を行ってください。" unless utility_service.employee_already_linked?(line_user_id)

    # シフト選択のPostback処理
    case postback_data
    when /^shift_\d+$/
      return exchange_service.handle_shift_selection_input(line_user_id, postback_data, nil)
    when /^approve_\d+$/
      return exchange_service.handle_approval_postback(line_user_id, postback_data, "approve")
    when /^reject_\d+$/
      return exchange_service.handle_approval_postback(line_user_id, postback_data, "reject")
    when /^approve_addition_.+$/
      return addition_service.handle_shift_addition_approval_postback(line_user_id, postback_data, "approve")
    when /^reject_addition_.+$/
      return addition_service.handle_shift_addition_approval_postback(line_user_id, postback_data, "reject")
    when /^deletion_shift_\d+$/
      return deletion_service.handle_deletion_shift_selection(line_user_id, postback_data)
    when /^approve_deletion_.+$/
      return deletion_service.handle_deletion_approval_postback(line_user_id, postback_data, "approve")
    when /^reject_deletion_.+$/
      return deletion_service.handle_deletion_approval_postback(line_user_id, postback_data, "reject")
    end

    "不明なPostbackイベントです。"
  end

  # 依頼確認コマンドの処理
  def handle_request_check_command(event)
    line_user_id = utility_service.extract_user_id(event)

    # 認証チェック
    return "認証が必要です。「認証」と入力して認証を行ってください。" unless utility_service.employee_already_linked?(line_user_id)

    employee = utility_service.find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 承認待ちのシフト交代リクエストを取得
    pending_exchanges = ShiftExchange.where(
      approver_id: employee.employee_id,
      status: "pending"
    ).includes(:shift)

    # 承認待ちのシフト追加リクエストを取得
    pending_additions = ShiftAddition.where(
      target_employee_id: employee.employee_id,
      status: "pending"
    )

    # 承認待ちのシフト削除リクエストを取得（シフトの担当者が承認者）
    pending_deletions = ShiftDeletion.joins(:shift).where(
      shifts: { employee_id: employee.employee_id },
      status: "pending"
    ).includes(:shift)

    # Flex Messageを生成して返す
    message_service.generate_pending_requests_flex_message(pending_exchanges, pending_additions, pending_deletions)
  end

  # テスト用メソッド: 会話状態管理を含むメッセージ処理
  def handle_message_with_state(line_user_id, message_text)
    # 現在の会話状態を取得
    current_state = conversation_service.get_conversation_state(line_user_id)

    if current_state
      # 会話状態に基づいて処理
      conversation_service.handle_stateful_message(line_user_id, message_text, current_state)
    else
      # 通常のコマンド処理
      handle_command_message(line_user_id, message_text)
    end
  end

  private

  def handle_command_message(line_user_id, message_text)
    # 既存のコマンド処理ロジックを使用
    event = mock_event_for_user(line_user_id, message_text)
    handle_message(event)
  rescue StandardError => e
    Rails.logger.error "コマンド処理エラー: #{e.message}"
    generate_unknown_command_message
  end

  def mock_event_for_user(line_user_id, message_text)
    # LINE Bot SDKのEventオブジェクトを模擬
    event = Object.new
    event.define_singleton_method(:source) { { "type" => "user", "userId" => line_user_id } }
    event.define_singleton_method(:message) { { "text" => message_text } }
    event.define_singleton_method(:type) { "message" }
    event.define_singleton_method(:[]) { |key| send(key) }
    event
  end

  # コマンド以外のメッセージの処理
  def handle_non_command_message(event)
    # グループチャットかどうかを判定
    if group_message?(event)
      # グループチャットでは何も返さない（会話の妨げを避ける）
      nil
    else
      # 個人チャットでは「コマンドとして認識できませんでした」を返す
      generate_unknown_command_message
    end
  end

  # グループメッセージかどうかを判定
  def group_message?(event)
    event["source"]["type"] == "group"
  end

  def generate_unknown_command_message
    "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
  end
end
