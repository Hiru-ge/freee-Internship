# frozen_string_literal: true

class LineShiftDeletionService
  def initialize
    @utility_service = LineUtilityService.new
    @conversation_service = LineConversationService.new
    @message_service = LineMessageService.new
  end

  # 欠勤申請コマンドの処理
  def handle_shift_deletion_command(event)
    line_user_id = @utility_service.extract_user_id(event)

    # 認証チェック
    unless @utility_service.employee_already_linked?(line_user_id)
      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end

    # 会話状態を設定
    @conversation_service.set_conversation_state(line_user_id, { step: "waiting_shift_selection" })

    "欠勤申請\n\n" \
      "欠勤したいシフトを選択してください。\n" \
      "過去のシフトは選択できません。"
  end

  # シフト選択の処理
  def handle_shift_selection(line_user_id, message_text, state)
    employee = @utility_service.find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 未来のシフトを取得
    future_shifts = Shift.where(
      employee_id: employee.employee_id,
      shift_date: Date.current..Float::INFINITY
    ).order(:shift_date, :start_time)

    if future_shifts.empty?
      return "欠勤申請可能なシフトが見つかりません。"
    end

    # シフト選択のFlex Messageを生成
    @message_service.generate_shift_deletion_flex_message(future_shifts)
  end

  # 欠勤理由入力の処理
  def handle_shift_deletion_reason_input(line_user_id, reason, state)
    if reason.blank?
      return "欠勤理由を入力してください。"
    end

    shift_id = state["shift_id"]
    create_shift_deletion_request(line_user_id, shift_id, reason)
  end

  # 欠勤申請の作成
  def create_shift_deletion_request(line_user_id, shift_id, reason)
    employee = @utility_service.find_employee_by_line_id(line_user_id)
    return { success: false, message: "従業員情報が見つかりません。" } unless employee

    # ShiftDeletionServiceを使用して申請を作成
    deletion_service = ShiftDeletionService.new
    result = deletion_service.create_deletion_request(shift_id, employee.employee_id, reason)

    if result[:success]
      # 会話状態をクリア
      @conversation_service.clear_conversation_state(line_user_id)
    end

    result
  end

  # 欠勤申請の承認・拒否処理
  def handle_deletion_approval_postback(line_user_id, postback_data, action)
    request_id = extract_request_id_from_postback(postback_data)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    return "欠勤申請が見つかりません。" unless shift_deletion

    # 権限チェック（オーナーのみ承認可能）
    employee = @utility_service.find_employee_by_line_id(line_user_id)
    return "この申請を処理する権限がありません。" unless employee&.owner?

    deletion_service = ShiftDeletionService.new

    case action
    when "approve"
      result = deletion_service.approve_deletion_request(request_id, employee.employee_id)
    when "reject"
      result = deletion_service.reject_deletion_request(request_id, employee.employee_id)
    else
      return "不明なアクションです。"
    end

    result[:message]
  end

  private

  def extract_request_id_from_postback(postback_data)
    # approve_deletion_REQUEST_ID または reject_deletion_REQUEST_ID から REQUEST_ID を抽出
    postback_data.sub(/^approve_deletion_/, "").sub(/^reject_deletion_/, "")
  end
end
