# frozen_string_literal: true

class LineShiftAdditionService
  def initialize; end

  # シフト追加コマンドの処理
  def handle_shift_addition_command(event)
    line_user_id = extract_user_id(event)

    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"

    end

    # グループメッセージかチェック

    # オーナー権限チェック
    employee = Employee.find_by(line_id: line_user_id)
    return "シフト追加はオーナーのみが利用可能です。" unless employee&.role == "owner"

    # シフト追加フロー開始
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_shift_addition_date",
                             "step" => 1,
                             "created_at" => Time.current
                           })

    tomorrow = (Date.current + 1).strftime("%m/%d")
    "シフト追加を開始します。\n" \
      "追加するシフトの日付を入力してください。\n" \
      "例：#{tomorrow}\n" \
      "⚠️ 過去の日付は指定できません"
  end

  # シフト追加日付入力の処理
  def handle_shift_addition_date_input(line_user_id, message_text)
    # 日付形式の検証（月・日形式）
    date_validation_result = LineDateValidationService.validate_month_day_format(message_text)
    return date_validation_result[:error] if date_validation_result[:error]

    date = date_validation_result[:date]

    # シフト追加時間入力の状態に移行
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_shift_addition_time",
                             "step" => 2,
                             "selected_date" => date,
                             "created_at" => Time.current
                           })

    "📅 日付: #{date.strftime('%m/%d')}\n\n" \
      "シフトの時間を入力してください。\n" \
      "例: 9:00-17:00"
  end

  # シフト追加時間入力の処理
  def handle_shift_addition_time_input(line_user_id, message_text, state)
    # 時間形式の検証
    time_validation_result = validate_shift_time(message_text)
    return time_validation_result[:error] if time_validation_result[:error]

    start_time = time_validation_result[:start_time]
    end_time = time_validation_result[:end_time]

    # 日付を取得
    date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
    date = state["selected_date"] if state["selected_date"].is_a?(Date)

    # シフト追加対象従業員選択の状態に移行
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_shift_addition_employee",
                             "step" => 3,
                             "selected_date" => state["selected_date"],
                             "start_time" => start_time,
                             "end_time" => end_time,
                             "created_at" => Time.current
                           })

    # 依頼可能な従業員を取得
    available_employees = get_available_employees_for_shift_addition(date, start_time, end_time)

    if available_employees.empty?
      "⏰ 時間: #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n\n" \
        "申し訳ございませんが、この時間帯にシフト追加可能な従業員がいません。\n" \
        "別の時間帯を選択してください。"
    else
      employee_list = available_employees.map.with_index(1) do |emp, index|
        display_name = emp[:display_name] || emp["display_name"]
        "#{index}. #{display_name}"
      end.join("\n")

      "⏰ 時間: #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n\n" \
        "対象となる従業員を選択してください。\n\n" \
        "依頼可能な従業員:\n#{employee_list}\n\n" \
        "番号で選択するか、従業員名を入力してください。\n" \
        "複数の場合はカンマで区切って入力してください。\n" \
        "例: 1,2 または 田中太郎, 佐藤花子"
    end
  end

  # シフト追加対象従業員入力の処理
  def handle_shift_addition_employee_input(line_user_id, message_text, state)
    # 文字列として保存された日付・時間を適切な型に変換
    date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
    date = state["selected_date"] if state["selected_date"].is_a?(Date)

    start_time = Time.parse(state["start_time"]) if state["start_time"].is_a?(String)
    start_time = state["start_time"] if state["start_time"].is_a?(Time)

    end_time = Time.parse(state["end_time"]) if state["end_time"].is_a?(String)
    end_time = state["end_time"] if state["end_time"].is_a?(Time)

    # 依頼可能な従業員を取得
    available_employees = get_available_employees_for_shift_addition(date, start_time, end_time)

    # 複数の従業員名を処理（カンマ区切り）
    employee_selections = message_text.split(",").map(&:strip)

    # 従業員検索
    selected_employees = []
    invalid_selections = []

    employee_selections.each do |selection|
      # 番号選択の場合は直接処理
      if selection.match?(/^\d+$/)
        selection_index = selection.to_i - 1
        if selection_index >= 0 && selection_index < available_employees.length
          selected_employees << available_employees[selection_index]
        else
          invalid_selections << selection
        end
      else
        # 従業員名で検索（依頼可能な従業員の中から）
        utility_service = LineUtilityService.new
        all_matches = utility_service.find_employees_by_name(selection)

        # 依頼可能な従業員の中から絞り込み
        employees = all_matches.select do |emp|
          emp_id = emp[:id] || emp["id"]
          available_employees.any? { |available| (available[:id] || available["id"]) == emp_id }
        end

        if employees.empty?
          invalid_selections << selection
        elsif employees.one?
          selected_employees << employees.first
        else
          # 複数の従業員が見つかった場合は、最初の1つを選択
          selected_employees << employees.first
        end
      end
    end

    if invalid_selections.any?
      return "以下の選択が無効でした:\n" +
             invalid_selections.join(", ") + "\n\n" \
             "正しい番号または従業員名を入力してください。\n" \
             "例: 1,2 または 田中太郎, 佐藤花子"
    end

    return "有効な従業員が見つかりませんでした。" if selected_employees.empty?

    # 既に依頼可能な従業員のみを選択しているので、重複チェックは不要
    available_employees = selected_employees
    overlapping_employees = []

    # 確認の状態に移行
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_shift_addition_confirmation",
                             "step" => 4,
                             "selected_date" => date,
                             "start_time" => start_time,
                             "end_time" => end_time,
                             "available_employees" => available_employees,
                             "overlapping_employees" => overlapping_employees,
                             "created_at" => Time.current
                           })

    # 確認メッセージを生成
    message = "📋 シフト追加の確認\n\n"
    message += "日付: #{date.strftime('%m/%d')}\n"
    message += "時間: #{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}\n"
    message += "対象従業員: #{available_employees.map { |emp| emp[:display_name] || emp["display_name"] }.join(', ')}\n\n"

    if overlapping_employees.any?
      message += "⚠️ 以下の従業員は時間が重複しているため除外されます:\n"
      message += "#{overlapping_employees.join(', ')}\n\n"
    end

    message += "この内容でシフト追加依頼を送信しますか？\n"
    message += "「はい」または「いいえ」で回答してください。"

    message
  end

  # シフト追加確認入力の処理
  def handle_shift_addition_confirmation_input(line_user_id, message_text, state)
    case message_text
    when "はい"
      create_shift_addition_request(line_user_id, state)
    when "いいえ"
      clear_conversation_state(line_user_id)
      "シフト追加依頼をキャンセルしました。"
    else
      "「はい」または「いいえ」で回答してください。"
    end
  end

  # シフト追加依頼の作成
  def create_shift_addition_request(line_user_id, state)
    employee = Employee.find_by(line_id: line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 文字列として保存された日付・時間を適切な型に変換
    date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
    date = state["selected_date"] if state["selected_date"].is_a?(Date)

    start_time = Time.parse(state["start_time"]) if state["start_time"].is_a?(String)
    start_time = state["start_time"] if state["start_time"].is_a?(Time)

    end_time = Time.parse(state["end_time"]) if state["end_time"].is_a?(String)
    end_time = state["end_time"] if state["end_time"].is_a?(Time)

    available_employees = state["available_employees"]
    state["overlapping_employees"]

    # 共通サービスを使用してシフト追加リクエストを作成
    request_params = {
      requester_id: employee.employee_id,
      shift_date: date.strftime("%Y-%m-%d"),
      start_time: start_time.strftime("%H:%M"),
      end_time: end_time.strftime("%H:%M"),
      target_employee_ids: available_employees.map { |emp| emp[:id] || emp["id"] }
    }

    shift_addition_service = ShiftAdditionService.new
    result = shift_addition_service.create_addition_request(request_params)

    # 会話状態をクリア
    clear_conversation_state(line_user_id)

    if result[:success]
      # 結果メッセージを生成
      message = "✅ シフト追加依頼を送信しました！\n\n"

      if result[:created_requests]&.any?
        created_names = result[:created_requests].map do |request|
          target_employee = Employee.find_by(employee_id: request.target_employee_id)
          target_employee&.display_name || "従業員ID: #{request.target_employee_id}"
        end
        message += "📤 送信先: #{created_names.join(', ')}\n"
      end

      message += "⚠️ 時間重複で除外: #{result[:overlapping_employees].join(', ')}\n" if result[:overlapping_employees]&.any?

      message += "\n送信先の方の承認をお待ちください。"

      message
    else
      result[:message]
    end
  rescue StandardError => e
    Rails.logger.error "シフト追加依頼作成エラー: #{e.message}"
    "❌ シフト追加依頼の作成に失敗しました。"
  end

  # シフト追加承認・否認のPostback処理
  def handle_shift_addition_approval_postback(line_user_id, postback_data, action)
    request_id = extract_request_id_from_postback(postback_data, "addition")
    addition_request = ShiftAddition.find_by(request_id: request_id)

    return "シフト追加リクエストが見つかりません。" unless addition_request

    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 共通サービスを使用して承認・拒否処理を実行
    shift_addition_service = ShiftAdditionService.new

    if action == "approve"
      result = shift_addition_service.approve_addition_request(request_id, employee.employee_id)
      if result[:success]
        "✅ シフト追加を承認しました。"
      else
        result[:message]
      end
    else
      result = shift_addition_service.reject_addition_request(request_id, employee.employee_id)
      if result[:success]
        "❌ シフト追加を拒否しました。"
      else
        result[:message]
      end
    end
  end

  private

  # ユーティリティメソッド
  def extract_user_id(event)
    event["source"]["userId"]
  end

  def group_message?(event)
    event["source"]["type"] == "group"
  end

  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  def find_employee_by_line_id(line_id)
    Employee.find_by(line_id: line_id)
  end

  def get_conversation_state(line_user_id)
    state_record = ConversationState.find_active_state(line_user_id)
    return nil unless state_record

    JSON.parse(state_record.state_data)
  end

  def set_conversation_state(line_user_id, state)
    # 既存の状態を削除
    ConversationState.where(line_user_id: line_user_id).delete_all

    # 新しい状態を保存（24時間後に期限切れ）
    ConversationState.create!(
      line_user_id: line_user_id,
      state_data: state.to_json,
      expires_at: 24.hours.from_now
    )
    true
  rescue StandardError => e
    Rails.logger.error "会話状態設定エラー: #{e.message}"
    false
  end

  def clear_conversation_state(line_user_id)
    ConversationState.where(line_user_id: line_user_id).delete_all
    true
  rescue StandardError => e
    Rails.logger.error "会話状態クリアエラー: #{e.message}"
    false
  end


  def validate_shift_time(time_string)
    result = LineValidationManagerService.validate_and_format_time(time_string)
    if result[:valid]
      { start_time: result[:start_time], end_time: result[:end_time] }
    else
      { error: result[:error] }
    end
  end

  def find_employee_by_name(name)
    matches = LineUtilityService.new.find_employees_by_name(name)

    if matches.empty?
      { found: false }
    elsif matches.length > 1
      # 複数の従業員が見つかった場合は、最初の1つを選択
      { found: true, employee: matches.first }
    else
      { found: true, employee: matches.first }
    end
  rescue StandardError => e
    Rails.logger.error "従業員検索エラー: #{e.message}"
    { found: false }
  end

  def has_shift_overlap?(employee_id, date, start_time, end_time)
    return false if start_time.nil? || end_time.nil? || date.nil?

    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
    )

    existing_shifts.any? do |shift|
      # 時間の重複チェック
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
  rescue StandardError => e
    Rails.logger.error "シフト重複チェックエラー: #{e.message}"
    false
  end

  # 指定された日付・時間帯にシフト追加可能な従業員を取得
  def get_available_employees_for_shift_addition(date, start_time, end_time)
    # freee APIから全従業員を取得
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    all_employees = freee_service.get_employees

    # 指定された日付・時間帯にシフトがある従業員のIDを取得
    busy_employee_ids = Shift.where(
      shift_date: date,
      start_time: start_time..end_time
    ).pluck(:employee_id)

    # シフト追加可能な従業員をフィルタリング（既にシフトがある従業員を除外）
    available_employees = all_employees.reject do |emp|
      emp_id = emp[:id] || emp["id"]
      busy_employee_ids.include?(emp_id)
    end

    available_employees
  rescue StandardError => e
    Rails.logger.error "シフト追加可能従業員取得エラー: #{e.message}"
    []
  end

  def extract_request_id_from_postback(postback_data, type)
    # approve_addition_XXX または reject_addition_XXX から XXX を抽出
    postback_data.gsub(/^(approve|reject)_#{type}_/, "")
  end

  # 通知メソッド（統合通知サービスを使用）
  def send_shift_addition_notification(addition_request)
    notification_service = UnifiedNotificationService.new
    notification_service.send_line_only(:shift_addition_request, addition_request)
  end

  def send_shift_addition_approval_notification(addition_request)
    notification_service = UnifiedNotificationService.new
    notification_service.send_line_only(:shift_addition_approval, addition_request)
  end

  def send_shift_addition_rejection_notification(addition_request)
    notification_service = UnifiedNotificationService.new
    notification_service.send_line_only(:shift_addition_rejection, addition_request)
  end
end
