class LineShiftAdditionService < LineBaseService
  def initialize
    super
  end
  def handle_shift_addition_command(event)
    line_user_id = extract_user_id(event)
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end
    employee = Employee.find_by(line_id: line_user_id)
    return "シフト追加はオーナーのみが利用可能です。" unless employee&.role == "owner"
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
  def handle_shift_addition_date_input(line_user_id, message_text)

    date_validation_result = validate_month_day_format(message_text)
    return date_validation_result[:error] if date_validation_result[:error]

    date = date_validation_result[:date]
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
  def handle_shift_addition_time_input(line_user_id, message_text, state)

    time_validation_result = validate_and_format_time(message_text)
    return time_validation_result[:error] if time_validation_result[:error]

    start_time = time_validation_result[:start_time]
    end_time = time_validation_result[:end_time]
    date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
    date = state["selected_date"] if state["selected_date"].is_a?(Date)
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_shift_addition_employee",
                             "step" => 3,
                             "selected_date" => state["selected_date"],
                             "start_time" => start_time,
                             "end_time" => end_time,
                             "created_at" => Time.current
                           })
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
  def handle_shift_addition_employee_input(line_user_id, message_text, state)

    date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
    date = state["selected_date"] if state["selected_date"].is_a?(Date)

    start_time = Time.parse(state["start_time"]) if state["start_time"].is_a?(String)
    start_time = state["start_time"] if state["start_time"].is_a?(Time)

    end_time = Time.parse(state["end_time"]) if state["end_time"].is_a?(String)
    end_time = state["end_time"] if state["end_time"].is_a?(Time)
    available_employees = get_available_employees_for_shift_addition(date, start_time, end_time)
    employee_selections = message_text.split(",").map(&:strip)
    selected_employees = []
    invalid_selections = []

    employee_selections.each do |selection|

      if selection.match?(/^\d+$/)
        selection_index = selection.to_i - 1
        if selection_index >= 0 && selection_index < available_employees.length
          selected_employees << available_employees[selection_index]
        else
          invalid_selections << selection
        end
      else

        all_matches = find_employees_by_name(selection)
        employees = all_matches.select do |emp|
          emp_id = emp[:id] || emp["id"]
          available_employees.any? { |available| (available[:id] || available["id"]) == emp_id }
        end

        if employees.empty?
          invalid_selections << selection
        elsif employees.one?
          selected_employees << employees.first
        else

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
    available_employees = selected_employees
    overlapping_employees = []
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
  def create_shift_addition_request(line_user_id, state)
    employee = Employee.find_by(line_id: line_user_id)
    return "従業員情報が見つかりません。" unless employee
    date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
    date = state["selected_date"] if state["selected_date"].is_a?(Date)

    start_time = Time.parse(state["start_time"]) if state["start_time"].is_a?(String)
    start_time = state["start_time"] if state["start_time"].is_a?(Time)

    end_time = Time.parse(state["end_time"]) if state["end_time"].is_a?(String)
    end_time = state["end_time"] if state["end_time"].is_a?(Time)

    available_employees = state["available_employees"]
    state["overlapping_employees"]
    request_params = {
      requester_id: employee.employee_id,
      shift_date: date.strftime("%Y-%m-%d"),
      start_time: start_time.strftime("%H:%M"),
      end_time: end_time.strftime("%H:%M"),
      target_employee_ids: available_employees.map { |emp| emp[:id] || emp["id"] }
    }

    shift_addition_service = ShiftAdditionService.new
    result = shift_addition_service.create_addition_request(request_params)
    clear_conversation_state(line_user_id)

    if result[:success]

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
  def handle_shift_addition_approval_postback(line_user_id, postback_data, action)
    request_id = extract_request_id_from_postback(postback_data, "addition")
    addition_request = ShiftAddition.find_by(request_id: request_id)

    return "シフト追加リクエストが見つかりません。" unless addition_request
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
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
  def get_available_employees_for_shift_addition(date, start_time, end_time)

    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    all_employees = freee_service.get_employees
    available_employees = []

    all_employees.each do |employee|
      employee_id = employee[:id] || employee["id"]
      existing_shift = Shift.where(
        employee_id: employee_id,
        shift_date: date
      ).where(
        "start_time < ? AND end_time > ?", end_time, start_time
      ).first

      available_employees << employee unless existing_shift
    end

    available_employees
  end
  def extract_request_id_from_postback(postback_data, type)
    case type
    when "addition"

      postback_data.split("_").last
    else
      postback_data
    end
  end
end
