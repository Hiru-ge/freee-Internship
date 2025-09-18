class LineConversationService
  def initialize
    # サービスクラスの初期化は遅延ロードする
  end

  # 会話状態の取得
  def get_conversation_state(line_user_id)
    state_record = ConversationState.find_active_state(line_user_id)
    return nil unless state_record

    state_record.state_hash
  end

  # 会話状態の設定
  def set_conversation_state(line_user_id, state)
    begin
      # 既存の状態を削除
      ConversationState.where(line_user_id: line_user_id).delete_all
      
      # 新しい状態を保存
      ConversationState.create!(
        line_user_id: line_user_id,
        state_hash: state
      )
      true
    rescue => e
      Rails.logger.error "会話状態設定エラー: #{e.message}"
      false
    end
  end

  # 会話状態のクリア
  def clear_conversation_state(line_user_id)
    begin
      ConversationState.where(line_user_id: line_user_id).delete_all
      true
    rescue => e
      Rails.logger.error "会話状態クリアエラー: #{e.message}"
      false
    end
  end

  # 状態付きメッセージの処理
  def handle_stateful_message(line_user_id, message_text, state)
    current_state = state['state'] || state[:step] || state['step']
    
    case current_state
    when 'waiting_for_employee_name'
      # 認証: 従業員名入力待ち
      return auth_service.handle_employee_name_input(line_user_id, message_text)
    when 'waiting_for_employee_selection'
      # 認証: 従業員選択待ち
      employee_matches = state['employee_matches']
      return auth_service.handle_multiple_employee_matches(line_user_id, message_text, employee_matches)
    when 'waiting_for_verification_code'
      # 認証: 認証コード入力待ち
      employee_id = state['employee_id']
      return auth_service.handle_verification_code_input(line_user_id, employee_id, message_text)
    when 'waiting_for_shift_date'
      # シフト交代: 日付入力待ち
      return exchange_service.handle_shift_date_input(line_user_id, message_text)
    when 'waiting_shift_date'
      # シフト交代: 日付入力待ち（テスト用の旧形式）
      return exchange_service.handle_shift_date_input(line_user_id, message_text)
    when 'waiting_for_shift_selection'
      # シフト交代: シフト選択待ち
      return exchange_service.handle_shift_selection_input(line_user_id, message_text, state)
    when 'waiting_for_employee_selection_exchange'
      # シフト交代: 従業員選択待ち
      return exchange_service.handle_employee_selection_input_exchange(line_user_id, message_text, state)
    when 'waiting_for_confirmation_exchange'
      # シフト交代: 確認待ち
      return exchange_service.handle_confirmation_input(line_user_id, message_text, state)
    when 'waiting_for_shift_addition_date'
      # シフト追加: 日付入力待ち
      return addition_service.handle_shift_addition_date_input(line_user_id, message_text)
    when 'waiting_for_shift_addition_time'
      # シフト追加: 時間入力待ち
      return addition_service.handle_shift_addition_time_input(line_user_id, message_text, state)
    when 'waiting_for_shift_addition_employee'
      # シフト追加: 対象従業員選択待ち
      return addition_service.handle_shift_addition_employee_input(line_user_id, message_text, state)
    when 'waiting_for_shift_addition_confirmation'
      # シフト追加: 確認待ち
      return addition_service.handle_shift_addition_confirmation_input(line_user_id, message_text, state)
    else
      # 不明な状態の場合は状態をクリア
      clear_conversation_state(line_user_id)
      return "不明な状態です。最初からやり直してください。"
    end
  end

  # 状態付きメッセージの処理（旧メソッドとの互換性）
  def handle_message_with_state(line_user_id, message_text)
    # 現在の会話状態を取得
    current_state = get_conversation_state(line_user_id)
    
    if current_state
      # 会話状態に基づいて処理
      handle_stateful_message(line_user_id, message_text, current_state)
    else
      # 会話状態がない場合はnilを返す
      nil
    end
  end

  private

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

  def validation_service
    @validation_service ||= LineValidationService.new
  end
end
