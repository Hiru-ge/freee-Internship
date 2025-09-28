# frozen_string_literal: true

class LineShiftManagementService
  def initialize
    @utility_service = LineUtilityService.new
    @message_service = LineMessageService.new
  end

  # シフトコマンドの処理
  def handle_shift_command(event)
    line_user_id = extract_user_id(event)

    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"

    end

    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 共通サービスを使用してシフトデータを取得
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_employee_shifts(employee.employee_id)

    if result[:success]
      shift_display_service.format_employee_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end

  # 全員シフトコマンドの処理
  def handle_all_shifts_command(event)
    line_user_id = extract_user_id(event)

    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"

    end

    # 共通サービスを使用して全従業員のシフトデータを取得
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_all_employee_shifts

    if result[:success]
      shift_display_service.format_all_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end

  # シフト交代コマンドの処理
  def handle_shift_exchange_command(event)
    line_user_id = extract_user_id(event)

    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"

    end

    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # シフト交代フロー開始
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_shift_date",
                             "step" => 1,
                             "created_at" => Time.current
                           })

    tomorrow = (Date.current + 1).strftime("%m/%d")
    "📋 シフト交代依頼\n\n交代したいシフトの日付を入力してください。\n\n📝 入力例: #{tomorrow}\n⚠️ 過去の日付は選択できません"
  end

  # 承認Postbackの処理
  def handle_approval_postback(line_user_id, postback_data, action)
    request_id = postback_data.split("_")[1]

    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 共通サービスを使用して承認・拒否処理を実行
    shift_exchange_service = ShiftExchangeService.new

    if action == "approve"
      result = shift_exchange_service.approve_exchange_request(request_id, employee.employee_id)
      if result[:success]
        "✅ シフト交代リクエストを承認しました。\n#{result[:shift_date]}"
      else
        result[:message]
      end
    elsif action == "reject"
      result = shift_exchange_service.reject_exchange_request(request_id, employee.employee_id)
      if result[:success]
        "❌ シフト交代リクエストを拒否しました。"
      else
        result[:message]
      end
    else
      "不明なアクションです。"
    end
  end

  # シフト交代日付入力の処理
  def handle_shift_date_input(line_user_id, message_text)
    # 日付形式の検証

    date = Date.parse(message_text)

    # 過去の日付は不可
    return "過去の日付のシフト交代依頼はできません。\n今日以降の日付を入力してください。" if date < Date.current

    # 指定された日付のシフトを取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    shifts = Shift.where(
      employee_id: employee.employee_id,
      shift_date: date
    ).order(:start_time)

    return "指定された日付のシフトが見つかりません。\n再度日付を入力してください。" if shifts.empty?

    # シフト選択のFlex Messageを生成
    generate_shift_exchange_flex_message(shifts)
  rescue ArgumentError
    tomorrow = (Date.current + 1).strftime("%m/%d")
    "日付の形式が正しくありません。\n例: #{tomorrow}"
  end

  # シフト選択入力の処理
  def handle_shift_selection_input(line_user_id, message_text, _state)
    # シフトIDの検証
    return "シフトを選択してください。" unless message_text.match?(/^shift_\d+$/)

    shift_id = message_text.split("_")[1]
    shift = Shift.find_by(id: shift_id)

    return "シフトが見つかりません。" unless shift

    # 依頼可能な従業員を取得
    available_employees = get_available_employees_for_shift(shift)

    # 状態を更新
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_employee_selection_exchange",
                             "shift_id" => shift_id,
                             "step" => 2
                           })

    if available_employees.empty?
      "申し訳ございませんが、この時間帯に交代可能な従業員がいません。\n別のシフトを選択してください。"
    else
      employee_list = available_employees.map.with_index(1) do |emp, index|
        display_name = emp[:display_name] || emp["display_name"]
        "#{index}. #{display_name}"
      end.join("\n")

      "交代先の従業員を選択してください。\n\n依頼可能な従業員:\n#{employee_list}\n\n番号で選択するか、従業員名を入力してください。\nフルネームでも部分入力でも検索できます。"
    end
  end

  # 従業員選択入力の処理（シフト交代用）
  def handle_employee_selection_input_exchange(line_user_id, message_text, state)
    shift_id = state["shift_id"]
    shift = Shift.find_by(id: shift_id)
    return "シフトが見つかりません。" unless shift

    # 依頼可能な従業員を取得
    available_employees = get_available_employees_for_shift(shift)

    # 番号選択の場合は直接処理
    if message_text.match?(/^\d+$/)
      selection_index = message_text.to_i - 1
      if selection_index >= 0 && selection_index < available_employees.length
        target_employee = available_employees[selection_index]

        # 確認の状態に移行
        set_conversation_state(line_user_id, {
                                 "state" => "waiting_for_confirmation_exchange",
                                 "shift_id" => shift_id,
                                 "target_employee_id" => target_employee[:id] || target_employee["id"],
                                 "step" => 3
                               })

        "シフト交代の確認\n\n" \
          "日付: #{shift.shift_date.strftime('%m/%d')}\n" \
          "時間: #{shift.start_time.strftime('%H:%M')} - #{shift.end_time.strftime('%H:%M')}\n" \
          "交代先: #{target_employee[:display_name] || target_employee['display_name']}\n\n" \
          "「はい」で確定、「いいえ」でキャンセル"
      else
        "正しい番号を入力してください。\n1から#{available_employees.length}の間で選択してください。"
      end
      return
    end

    # 従業員名で検索（依頼可能な従業員の中から）
    utility_service = LineUtilityService.new
    all_matches = utility_service.find_employees_by_name(message_text)

    # 依頼可能な従業員の中から絞り込み
    employees = all_matches.select do |emp|
      emp_id = emp[:id] || emp["id"]
      available_employees.any? { |available| (available[:id] || available["id"]) == emp_id }
    end

    if employees.empty?
      "該当する従業員が見つかりません。\n従業員名を入力してください。\nフルネームでも部分入力でも検索できます。"
    elsif employees.one?
      target_employee = employees.first

      # 確認の状態に移行
      set_conversation_state(line_user_id, {
                               "state" => "waiting_for_confirmation_exchange",
                               "shift_id" => shift_id,
                               "target_employee_id" => target_employee[:id] || target_employee["id"],
                               "step" => 3
                             })

      "シフト交代の確認\n\n" \
        "日付: #{shift.shift_date.strftime('%m/%d')}\n" \
        "時間: #{shift.start_time.strftime('%H:%M')} - #{shift.end_time.strftime('%H:%M')}\n" \
        "交代先: #{target_employee[:display_name] || target_employee['display_name']}\n\n" \
        "「はい」で確定、「いいえ」でキャンセル"
    else
      # 複数の従業員が見つかった場合
      employee_list = employees.map.with_index(1) do |emp, index|
        display_name = emp[:display_name] || emp["display_name"]
        "#{index}. #{display_name}"
      end.join("\n")

      set_conversation_state(line_user_id, {
                               "state" => "waiting_for_employee_selection_exchange",
                               "shift_id" => shift_id,
                               "employee_matches" => employees.map { |emp| emp[:id] || emp["id"] },
                               "step" => 2
                             })

      "複数の従業員が見つかりました。\n番号で選択してください。\n\n#{employee_list}"
    end
  end

  # 確認入力の処理（シフト交代用）
  def handle_confirmation_input(line_user_id, message_text, state)
    if message_text == "はい"
      # シフト交代リクエストを作成
      shift_id = state["shift_id"]
      target_employee_id = state["target_employee_id"]

      result = create_shift_exchange_request(line_user_id, shift_id, target_employee_id)

      # 状態をクリア
      clear_conversation_state(line_user_id)

      result
    elsif message_text == "いいえ"
      # 状態をクリア
      clear_conversation_state(line_user_id)

      "シフト交代をキャンセルしました。"
    else
      "「はい」または「いいえ」で回答してください。"
    end
  end

  # シフト交代リクエストの作成
  def create_shift_exchange_request(line_user_id, shift_id, target_employee_id)
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # シフト情報を取得
    shift = Shift.find_by(id: shift_id)
    return "シフトが見つかりません。" unless shift

    # 共通サービスを使用してシフト交代リクエストを作成
    request_params = {
      applicant_id: employee.employee_id,
      shift_date: shift.shift_date.strftime("%Y-%m-%d"),
      start_time: shift.start_time.strftime("%H:%M"),
      end_time: shift.end_time.strftime("%H:%M"),
      approver_ids: [target_employee_id]
    }

    shift_exchange_service = ShiftExchangeService.new
    result = shift_exchange_service.create_exchange_request(request_params)

    if result[:success]
      "シフト交代リクエストを送信しました。\n承認をお待ちください。"
    else
      result[:message]
    end
  end

  # シフト追加コマンドの処理
  def handle_shift_addition_command(event)
    line_user_id = extract_user_id(event)

    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"

    end

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
    validation_service = LineValidationService.new
    date_validation_result = validation_service.validate_month_day_format(message_text)
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

  # 欠勤申請コマンドの処理
  def handle_shift_deletion_command(event)
    line_user_id = extract_user_id(event)

    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end

    # 会話状態を設定（日付入力待ち）
    set_conversation_state(line_user_id, {
      step: "waiting_for_shift_deletion_date",
      state: "waiting_for_shift_deletion_date"
    })

    "欠勤申請\n\n" \
      "欠勤したい日付を入力してください。\n" \
      "例: 09/20"
  end

  # 日付入力の処理
  def handle_shift_deletion_date_input(line_user_id, message_text, state)
    # 日付形式の検証
    validation_service = LineValidationService.new
    date_validation_result = validation_service.validate_month_day_format(message_text)
    return date_validation_result[:error] if date_validation_result[:error]

    selected_date = date_validation_result[:date]

    # 過去の日付チェック
    if selected_date < Date.current
      return "過去の日付は選択できません。未来の日付を入力してください。"
    end

    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 指定された日付のシフトを取得
    shifts_on_date = Shift.where(
      employee_id: employee.employee_id,
      shift_date: selected_date
    ).order(:start_time)

    if shifts_on_date.empty?
      return "指定された日付（#{selected_date.strftime('%m/%d')}）にシフトが見つかりません。\n別の日付を入力してください。"
    end

    # 会話状態を更新（シフト選択待ち）
    set_conversation_state(line_user_id, {
      step: "waiting_for_shift_deletion_selection",
      state: "waiting_for_shift_deletion_selection",
      selected_date: selected_date
    })

    # シフト選択のFlex Messageを生成
    @message_service.generate_shift_deletion_flex_message(shifts_on_date)
  end

  # シフト選択の処理
  def handle_shift_selection(line_user_id, message_text, state)
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 日付が指定されている場合はその日付のシフトのみを取得
    if state["selected_date"]
      selected_date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
      selected_date = state["selected_date"] if state["selected_date"].is_a?(Date)

      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: selected_date
      ).order(:start_time)
    else
      # 未来のシフトを取得（従来の動作）
      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: Date.current..Float::INFINITY
      ).order(:shift_date, :start_time)
    end

    if shifts.empty?
      if state["selected_date"]
        selected_date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
        selected_date = state["selected_date"] if state["selected_date"].is_a?(Date)
        return "指定された日付（#{selected_date.strftime('%m/%d')}）にシフトが見つかりません。"
      else
        return "欠勤申請可能なシフトが見つかりません。"
      end
    end

    # シフト選択のFlex Messageを生成
    @message_service.generate_shift_deletion_flex_message(shifts)
  end

  # シフト選択のPostback処理
  def handle_deletion_shift_selection(line_user_id, postback_data)
    # シフトIDの検証
    return "シフトを選択してください。" unless postback_data.match?(/^deletion_shift_\d+$/)

    shift_id = postback_data.split("_")[2]
    shift = Shift.find_by(id: shift_id)

    return "シフトが見つかりません。" unless shift

    # 会話状態を更新（理由入力待ち）
    set_conversation_state(line_user_id, {
      step: "waiting_deletion_reason",
      state: "waiting_deletion_reason",
      shift_id: shift_id
    })

    "欠勤理由を入力してください。\n例: 体調不良、急用、家族の用事など"
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
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # ShiftDeletionServiceを使用して申請を作成
    deletion_service = ShiftDeletionService.new
    result = deletion_service.create_deletion_request(shift_id, employee.employee_id, reason)

    if result[:success]
      # 会話状態をクリア
      clear_conversation_state(line_user_id)
      # 成功メッセージを返す
      result[:message]
    else
      # エラーメッセージを返す
      result[:message]
    end
  end

  # 欠勤申請の承認・拒否処理
  def handle_deletion_approval_postback(line_user_id, postback_data, action)
    request_id = extract_request_id_from_postback(postback_data)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    return "欠勤申請が見つかりません。" unless shift_deletion

    # 権限チェック（オーナーのみ承認可能）
    employee = find_employee_by_line_id(line_user_id)
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

  # ===== 共通メソッド =====

  # 会話状態の設定
  def set_conversation_state(line_user_id, state)
    @utility_service.set_conversation_state(line_user_id, state)
  end

  # 会話状態のクリア
  def clear_conversation_state(line_user_id)
    @utility_service.clear_conversation_state(line_user_id)
  end

  private

  # シフト交代Flex Messageの生成
  def generate_shift_exchange_flex_message(shifts)
    {
      type: "flex",
      altText: "📋 シフト交代依頼",
      contents: {
        type: "carousel",
        contents: shifts.map do |shift|
          {
            type: "bubble",
            header: {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "text",
                  text: "📋 シフト交代依頼",
                  weight: "bold",
                  color: "#1DB446",
                  size: "sm"
                }
              ]
            },
            body: {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "text",
                  text: "シフト交代依頼",
                  weight: "bold",
                  size: "lg"
                },
                {
                  type: "text",
                  text: shift.shift_date.strftime("%Y年%m月%d日"),
                  size: "md",
                  color: "#666666"
                },
                {
                  type: "box",
                  layout: "vertical",
                  contents: [
                    {
                      type: "text",
                      text: "時間",
                      size: "sm",
                      color: "#999999"
                    },
                    {
                      type: "box",
                      layout: "horizontal",
                      contents: [
                        {
                          type: "text",
                          text: "時間",
                          size: "sm",
                          color: "#999999"
                        },
                        {
                          type: "text",
                          text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}",
                          size: "sm",
                          color: "#999999"
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
              contents: [
                {
                  type: "button",
                  action: {
                    type: "postback",
                    label: "交代を依頼",
                    data: "shift_#{shift.id}"
                  },
                  style: "primary"
                }
              ]
            }
          }
        end
      }
    }
  end

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

  # 指定されたシフトの時間帯に依頼可能な従業員を取得
  def get_available_employees_for_shift(shift)
    # freee APIから全従業員を取得
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    all_employees = freee_service.get_employees

    # 指定された日付・時間帯にシフトがある従業員のIDを取得
    busy_employee_ids = Shift.where(
      shift_date: shift.shift_date,
      start_time: shift.start_time..shift.end_time
    ).pluck(:employee_id)

    # 依頼可能な従業員をフィルタリング（自分自身と既にシフトがある従業員を除外）
    available_employees = all_employees.reject do |emp|
      emp_id = emp[:id] || emp["id"]
      emp_id == shift.employee_id || busy_employee_ids.include?(emp_id)
    end

    available_employees
  rescue StandardError => e
    Rails.logger.error "依頼可能従業員取得エラー: #{e.message}"
    []
  end

  def validate_shift_time(time_string)
    validation_service = LineValidationService.new
    result = validation_service.validate_and_format_time(time_string)
    if result[:valid]
      { start_time: result[:start_time], end_time: result[:end_time] }
    else
      { error: result[:error] }
    end
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

  def extract_request_id_from_postback(postback_data, type = nil)
    if type
      # approve_addition_XXX または reject_addition_XXX から XXX を抽出
      postback_data.gsub(/^(approve|reject)_#{type}_/, "")
    else
      # approve_deletion_REQUEST_ID または reject_deletion_REQUEST_ID から REQUEST_ID を抽出
      postback_data.sub(/^approve_deletion_/, "").sub(/^reject_deletion_/, "")
    end
  end
end
