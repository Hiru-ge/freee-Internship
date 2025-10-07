# frozen_string_literal: true

class LineBaseService < BaseService
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
    super
  end

  # 会話状態管理の共通処理
  def get_conversation_state(line_user_id)
    state_record = ConversationState.find_active_state(line_user_id)
    return nil unless state_record

    state_record.state_hash
  end

  def set_conversation_state(line_user_id, state)
    ConversationState.where(line_user_id: line_user_id).delete_all
    ConversationState.create!(
      line_user_id: line_user_id,
      state_data: state.to_json,
      expires_at: AppConstants::CONVERSATION_STATE_TIMEOUT_HOURS.hours.from_now
    )
    true
  rescue StandardError => e
    log_error("会話状態設定エラー: #{e.message}")
    false
  end

  def clear_conversation_state(line_user_id)
    ConversationState.where(line_user_id: line_user_id).delete_all
    true
  rescue StandardError => e
    log_error("会話状態クリアエラー: #{e.message}")
    false
  end

  # 従業員検索の共通処理
  def find_employees_by_name(name)
    freee_service = freee_api_service

    employees = freee_service.get_employees
    normalized_name = normalize_employee_name(name)
    employees.select do |employee|
      display_name = employee[:display_name] || employee["display_name"]
      next false unless display_name

      normalized_display_name = normalize_employee_name(display_name)

      normalized_display_name.include?(normalized_name) ||
        normalized_name.include?(normalized_display_name)
    end
  rescue StandardError => e
    log_error("従業員検索エラー: #{e.message}")
    []
  end

  def find_employee_by_line_id(line_id)
    Employee.find_by(line_id: line_id)
  end

  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  # メッセージ生成の共通処理
  def generate_error_message(error_text)
    "❌ #{error_text}"
  end

  def generate_success_message(success_text)
    "✅ #{success_text}"
  end

  def generate_warning_message(warning_text)
    "⚠️ #{warning_text}"
  end

  def generate_info_message(info_text)
    "ℹ️ #{info_text}"
  end

  # 日付バリデーション（LINE Bot用）
  def validate_month_day_format(date_string)
    if date_string.match?(/^\d{1,2}\/\d{1,2}$/)
      month, day = date_string.split("/").map(&:to_i)

      if month < 1 || month > 12
        return { valid: false, error: "月は1から12の間で入力してください。" }
      end

      if day < 1 || day > 31
        return { valid: false, error: "日は1から31の間で入力してください。" }
      end

      current_year = Date.current.year
      begin
        date = Date.new(current_year, month, day)

        if date < Date.current
          date = Date.new(current_year + 1, month, day)
        end

        { valid: true, date: date }
      rescue ArgumentError
        { valid: false, error: "無効な日付です。正しい日付を入力してください。" }
      end
    else
      { valid: false, error: "正しい日付形式で入力してください。\n例: 9/20 または 09/20" }
    end
  end

  def validate_and_format_date(date_string)
    return { valid: false, error: "日付が入力されていません。" } if date_string.blank?

    begin
      date = case date_string
             when /^\d{4}-\d{2}-\d{2}$/
               Date.parse(date_string)
             when %r{^\d{2}/\d{2}$}
               current_year = Date.current.year
               Date.parse("#{current_year}/#{date_string}")
             when %r{^\d{1,2}/\d{1,2}$}
               current_year = Date.current.year
               Date.parse("#{current_year}/#{date_string}")
             else
               Date.parse(date_string)
             end

      return { valid: false, error: "過去の日付は指定できません。" } if date < Date.current

      { valid: true, date: date }
    rescue ArgumentError
      { valid: false, error: "正しい日付形式で入力してください。\n例: 2024-01-15 または 1/15" }
    end
  end

  # 時間バリデーション（LINE Bot用）
  def validate_and_format_time(time_string)
    return { valid: false, error: "時間が入力されていません。" } if time_string.blank?

    begin
      if time_string.match?(/^\d{1,2}:\d{2}-\d{1,2}:\d{2}$/)
        start_time_str, end_time_str = time_string.split("-")
        start_time = Time.parse(start_time_str)
        end_time = Time.parse(end_time_str)

        return { valid: false, error: "終了時間は開始時間より後にしてください。" } if end_time <= start_time

        { valid: true, start_time: start_time, end_time: end_time }
      else
        { valid: false, error: "正しい時間形式で入力してください。\n例: 9:00-17:00" }
      end
    rescue ArgumentError
      { valid: false, error: "正しい時間形式で入力してください。\n例: 9:00-17:00" }
    end
  end

  # 数値バリデーション（LINE Bot用）
  def validate_numeric_input(input, min: nil, max: nil)
    return { error: "数値を入力してください。" } if input.blank?

    begin
      number = input.to_i

      return { error: "#{min}以上の数値を入力してください。" } if min && number < min

      return { error: "#{max}以下の数値を入力してください。" } if max && number > max

      { valid: true, value: number }
    rescue ArgumentError
      { error: "有効な数値を入力してください。" }
    end
  end

  def validate_number_selection(number_string, max_number)
    return { valid: false, error: "番号が入力されていません。" } if number_string.blank?

    begin
      number = number_string.to_i
      if number < 1 || number > max_number
        { valid: false, error: "1から#{max_number}の間の番号を入力してください。" }
      else
        { valid: true, value: number }
      end
    rescue ArgumentError
      { valid: false, error: "正しい番号を入力してください。" }
    end
  end

  # 確認入力バリデーション
  def validate_confirmation_input(input)
    case input.downcase
    when "はい", "yes", "y", "ok", "承認"
      { valid: true, confirmed: true }
    when "いいえ", "no", "n", "キャンセル", "否認"
      { valid: true, confirmed: false }
    else
      { error: "「はい」または「いいえ」で回答してください。" }
    end
  end

  # 認証コードバリデーション
  def validate_verification_code_string(code_string)
    return { valid: false, error: "認証コードが入力されていません。" } if code_string.blank?

    if code_string.match?(/^\d{6}$/)
      { valid: true, code: code_string }
    else
      { valid: false, error: "6桁の数字で入力してください。" }
    end
  end

  # 従業員名の正規化
  def normalize_employee_name(name)
    name.tr("ァ-ヶ", "ぁ-ゟ").gsub(/\s+/, "")
  end

  # 従業員選択の解析
  def parse_employee_selection(message_text)
    if message_text.match?(/^\d+$/)
      return { type: :id, value: message_text } if valid_employee_id_format?(message_text)
    end
    { type: :name, value: message_text }
  end

  def valid_employee_id_format?(employee_id)
    employee_id.is_a?(String) && employee_id.match?(/^\d+$/)
  end

  # シフト重複チェック（LINE Bot用）
  def has_shift_overlap?(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
    )

    existing_shifts.any? do |shift|
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
  end

  def get_available_and_overlapping_employees(employee_ids, date, start_time, end_time)
    available = []
    overlapping = []

    employee_ids.each do |employee_id|
      employee = Employee.find_by(employee_id: employee_id)
      if has_shift_overlap?(employee_id, date, start_time, end_time)
        overlapping << employee.display_name if employee
      elsif employee
        available << employee
      end
    end

    { available: available, overlapping: overlapping }
  end

  def validate_shift_overlap(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
    )

    overlapping_shifts = existing_shifts.select do |shift|
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end

    if overlapping_shifts.any?
      overlap_info = overlapping_shifts.map do |shift|
        "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}"
      end

      {
        has_overlap: true,
        overlapping_times: overlap_info,
        message: "指定時間に既存のシフトが重複しています: #{overlap_info.join(', ')}"
      }
    else
      { has_overlap: false }
    end
  end

  # 日付・時間のフォーマット
  def format_date(date)
    date.strftime("%m/%d")
  end

  def format_time(time)
    time.strftime("%H:%M")
  end

  def format_date_with_day(date)
    day_of_week = %w[日 月 火 水 木 金 土][date.wday]
    "#{format_date(date)} (#{day_of_week})"
  end

  def format_time_range(start_time, end_time)
    "#{format_time(start_time)}-#{format_time(end_time)}"
  end

  # 現在時刻関連
  def current_time
    Time.current
  end

  def current_date
    Date.current
  end

  def current_month_start
    current_date.beginning_of_month
  end

  def current_month_end
    current_date.end_of_month
  end

  def next_month_start
    current_date.next_month.beginning_of_month
  end

  def next_month_end
    current_date.next_month.end_of_month
  end

  # リクエストID生成
  def generate_request_id(prefix = "REQ")
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # 認証チェック
  def require_authentication(line_user_id)
    unless employee_already_linked?(line_user_id)
      return generate_error_message("認証が必要です。「認証」と入力して認証を行ってください。")
    end
    nil
  end

  def require_owner_permission(line_user_id)
    employee = find_employee_by_line_id(line_user_id)
    unless employee&.role == "owner"
      return generate_error_message("この機能はオーナーのみが利用可能です。")
    end
    nil
  end

  # エラーハンドリング（LINE Bot用）
  def handle_line_error(error, context = "")
    error_message = context.present? ? "#{context}: #{error.message}" : error.message
    log_error(error_message)
    generate_error_message("処理中にエラーが発生しました。しばらく時間をおいてから再度お試しください。")
  end

  # 状態管理のヘルパー
  def update_conversation_state(line_user_id, new_state_data)
    current_state = get_conversation_state(line_user_id)
    if current_state
      merged_state = current_state.merge(new_state_data)
      set_conversation_state(line_user_id, merged_state)
    else
      set_conversation_state(line_user_id, new_state_data)
    end
  end

  def get_state_value(line_user_id, key)
    state = get_conversation_state(line_user_id)
    state&.dig(key)
  end

  def set_state_value(line_user_id, key, value)
    update_conversation_state(line_user_id, { key => value })
  end

  # 従業員選択の共通処理
  def handle_employee_selection(line_user_id, message_text, available_employees)
    if message_text.match?(/^\d+$/)
      # 数値選択
      selection_index = message_text.to_i - 1
      if selection_index >= 0 && selection_index < available_employees.length
        return { success: true, employee: available_employees[selection_index] }
      else
        return { success: false, message: "正しい番号を入力してください。1から#{available_employees.length}の間で選択してください。" }
      end
    else
      # 名前検索
      all_matches = find_employees_by_name(message_text)
      employees = all_matches.select do |emp|
        emp_id = emp[:id] || emp["id"]
        available_employees.any? { |available| (available[:id] || available["id"]) == emp_id }
      end

      if employees.empty?
        return { success: false, message: "該当する従業員が見つかりません。従業員名を入力してください。" }
      elsif employees.one?
        return { success: true, employee: employees.first }
      else
        return { success: false, message: "複数の従業員が見つかりました。番号で選択してください。", employees: employees }
      end
    end
  end

  # 複数従業員選択の共通処理
  def handle_multiple_employee_selection(line_user_id, message_text, available_employees)
    employee_selections = message_text.split(",").map(&:strip)
    selected_employees = []
    invalid_selections = []

    employee_selections.each do |selection|
      result = handle_employee_selection(line_user_id, selection, available_employees)
      if result[:success]
        selected_employees << result[:employee]
      else
        invalid_selections << selection
      end
    end

    if invalid_selections.any?
      return {
        success: false,
        message: "以下の選択が無効でした: #{invalid_selections.join(', ')}\n正しい番号または従業員名を入力してください。"
      }
    end

    if selected_employees.empty?
      return { success: false, message: "有効な従業員が見つかりませんでした。" }
    end

    { success: true, employees: selected_employees }
  end

  # コマンド処理の共通メソッド
  def command_message?(message_text)
    COMMANDS.key?(message_text)
  end

  def generate_help_message(_event = nil)
    "利用可能なコマンド:\n\n" \
      "・ヘルプ - このメッセージを表示\n" \
      "・認証 - 従業員名入力による認証（個人チャットのみ）\n" \
      "・シフト確認 - 個人のシフト情報を確認\n" \
      "・全員シフト確認 - 全従業員のシフト情報を確認\n" \
      "・交代依頼 - シフト交代依頼\n" \
      "・追加依頼 - シフト追加依頼（オーナーのみ）\n" \
      "・欠勤申請 - シフトの欠勤申請\n" \
      "・依頼確認 - 承認待ちの依頼を確認\n\n" \
      "コマンドを入力してください。"
  end

  def generate_unknown_command_message
    "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
  end

  # メッセージ処理のメインメソッド
  def handle_message(event)
    return handle_postback_event(event) if event["type"] == "postback"

    message_text = event["message"]["text"]
    line_user_id = extract_user_id(event)

    state = get_conversation_state(line_user_id)
    Rails.logger.debug "LineBaseService: line_user_id = #{line_user_id}, state = #{state}, message_text = #{message_text}"
    return handle_stateful_message(line_user_id, message_text, state) if state

    command = COMMANDS[message_text]

    case command
    when :help
      generate_help_message(event)
    when :auth
      handle_auth_command(event)
    when :shift
      shift_display_service.handle_shift_command(event)
    when :all_shifts
      shift_display_service.handle_all_shifts_command(event)
    when :shift_exchange
      shift_exchange_service.handle_shift_exchange_command(event)
    when :shift_addition
      shift_addition_service.handle_shift_addition_command(event)
    when :shift_deletion
      shift_deletion_service.handle_shift_deletion_command(event)
    when :request_check
      handle_request_check_command(event)
    else
      handle_non_command_message(event)
    end
  end

  def handle_postback_event(event)
    line_user_id = extract_user_id(event)
    postback_data = event["postback"]["data"]

    return "認証が必要です。「認証」と入力して認証を行ってください。" unless employee_already_linked?(line_user_id)
    case postback_data
    when /^shift_\d+$/
      return shift_exchange_service.handle_shift_selection_input(line_user_id, postback_data, nil)
    when /^approve_\d+$/
      return shift_exchange_service.handle_approval_postback(line_user_id, postback_data, "approve")
    when /^reject_\d+$/
      return shift_exchange_service.handle_approval_postback(line_user_id, postback_data, "reject")
    when /^approve_addition_.+$/
      return shift_addition_service.handle_shift_addition_approval_postback(line_user_id, postback_data, "approve")
    when /^reject_addition_.+$/
      return shift_addition_service.handle_shift_addition_approval_postback(line_user_id, postback_data, "reject")
    when /^deletion_shift_\d+$/
      return shift_deletion_service.handle_deletion_shift_selection(line_user_id, postback_data)
    when /^approve_deletion_.+$/
      return shift_deletion_service.handle_deletion_approval_postback(line_user_id, postback_data, "approve")
    when /^reject_deletion_.+$/
      return shift_deletion_service.handle_deletion_approval_postback(line_user_id, postback_data, "reject")
    end

    "不明なPostbackイベントです。"
  end

  # サービスインスタンスの取得
  def shift_exchange_service
    @shift_exchange_service ||= LineShiftExchangeService.new
  end

  def shift_addition_service
    @shift_addition_service ||= LineShiftAdditionService.new
  end

  def shift_deletion_service
    @shift_deletion_service ||= LineShiftDeletionService.new
  end

  def shift_display_service
    @shift_display_service ||= LineShiftDisplayService.new
  end

  # ユーティリティメソッド
  def extract_user_id(event)
    event["source"]["userId"]
  end

  def group_message?(event)
    event["source"]["type"] == "group"
  end

  def individual_message?(event)
    event["source"]["type"] == "user"
  end

  # 認証関連のメソッド
  def handle_auth_command(event)
    if group_message?(event)
      return "認証は個人チャットでのみ利用できます。\n" \
             "このボットと個人チャットを開始してから「認証」と入力してください。"
    end

    line_user_id = extract_user_id(event)

    return "既に認証済みです。" if employee_already_linked?(line_user_id)

    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_employee_name",
                             "step" => 1,
                             "created_at" => Time.current
                           })

    "認証を開始します。\n" \
      "あなたの従業員名を入力してください。\n" \
      "フルネームでも部分入力でも検索できます。\n" \
      "例: 田中太郎、田中、太郎"
  end

  # 状態管理メッセージ処理
  def handle_stateful_message(line_user_id, message_text, state)
    if command_message?(message_text)
      clear_conversation_state(line_user_id)
      return nil
    end

    current_state = state["state"] || state[:step] || state["step"]

    Rails.logger.debug "LineBaseService: current_state = #{current_state}, message_text = #{message_text}, state = #{state}"

    case current_state
    when "waiting_for_employee_name"
      handle_employee_name_input(line_user_id, message_text)
    when "waiting_for_employee_selection"
      employee_matches = state["employee_matches"]
      handle_employee_selection_input(line_user_id, message_text, employee_matches)
    when "waiting_for_verification_code"
      employee_id = state["employee_id"]
      handle_verification_code_input(line_user_id, employee_id, message_text)
    when "waiting_for_shift_date", "waiting_shift_date"
      shift_exchange_service.handle_shift_date_input(line_user_id, message_text)
    when "waiting_for_shift_time", "waiting_shift_time"
      shift_exchange_service.handle_shift_time_input(line_user_id, message_text, state)
    when "waiting_for_shift_selection"
      shift_exchange_service.handle_shift_selection_input(line_user_id, message_text, state)
    when "waiting_for_employee_selection_exchange"
      shift_exchange_service.handle_employee_selection_input_exchange(line_user_id, message_text, state)
    when "waiting_for_confirmation_exchange"
      shift_exchange_service.handle_confirmation_input(line_user_id, message_text, state)
    when "waiting_for_shift_addition_date", "waiting_shift_addition_date"
      Rails.logger.debug "LineBaseService: calling shift_addition_service.handle_shift_addition_date_input"
      shift_addition_service.handle_shift_addition_date_input(line_user_id, message_text)
    when "waiting_for_shift_addition_time"
      shift_addition_service.handle_shift_addition_time_input(line_user_id, message_text, state)
    when "waiting_for_shift_addition_employee"
      shift_addition_service.handle_shift_addition_employee_input(line_user_id, message_text, state)
    when "waiting_for_shift_addition_confirmation"
      shift_addition_service.handle_shift_addition_confirmation_input(line_user_id, message_text, state)
    when "waiting_for_shift_deletion_date"
      shift_deletion_service.handle_shift_deletion_date_input(line_user_id, message_text, state)
    when "waiting_for_shift_deletion_selection"
      shift_deletion_service.handle_shift_selection(line_user_id, message_text, state)
    when "waiting_deletion_reason"
      shift_deletion_service.handle_shift_deletion_reason_input(line_user_id, message_text, state)
    else
      clear_conversation_state(line_user_id)
      "不明な状態です。最初からやり直してください。"
    end
  end

  # 認証関連の詳細メソッド
  def handle_employee_name_input(line_user_id, employee_name)
    matches = find_employees_by_name(employee_name)

    if matches.empty?
      if employee_name.length > 20 || employee_name.match?(/[^\p{Hiragana}\p{Katakana}\p{Han}a-zA-Z]/)
        return "有効な従業員名を入力してください。\n" \
               "フルネームでも部分入力でも検索できます。\n" \
               "例: 田中太郎、田中、太郎"
      end

      "「#{employee_name}」に該当する従業員が見つかりませんでした。\n" \
        "フルネームでも部分入力でも検索できます。\n" \
        "例: 田中太郎、田中、太郎"
    elsif matches.length == 1
      generate_verification_code_for_employee(line_user_id, matches.first)
    else
      handle_multiple_employee_matches(line_user_id, employee_name, matches)
    end
  end

  def handle_multiple_employee_matches(line_user_id, employee_name, matches)
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_employee_selection",
                             "step" => 2,
                             "employee_matches" => matches,
                             "created_at" => Time.current
                           })

    generate_multiple_employee_selection_message(employee_name, matches)
  end

  def handle_employee_selection_input(line_user_id, selection_text, employee_matches)
    selection_index = selection_text.to_i - 1

    if selection_index < 0 || selection_index >= employee_matches.length
      return "正しい番号を入力してください。\n" \
             "1から#{employee_matches.length}の間で選択してください。"
    end

    selected_employee = employee_matches[selection_index]
    generate_verification_code_for_employee(line_user_id, selected_employee)
  end

  def generate_verification_code_for_employee(line_user_id, employee)
    employee_id = employee[:id] || employee["id"]
    display_name = employee[:display_name] || employee["display_name"]
    begin
      result = AuthService.send_verification_code(employee_id)

      if result[:success]
        set_conversation_state(line_user_id, {
                                 "state" => "waiting_for_verification_code",
                                 "step" => 3,
                                 "employee_id" => employee_id,
                                 "employee_name" => display_name,
                                 "created_at" => Time.current
                               })

        "認証コードを送信しました。\n" \
          "メールの送信には数分かかる場合があります。\n" \
          "メールに送信された6桁の認証コードを入力してください。\n" \
          "（認証コードの有効期限は10分間です）"
      else
        "認証コードの送信に失敗しました。\n" \
          "しばらく時間をおいてから再度お試しください。"
      end
    rescue StandardError => e
      log_error("認証コード生成エラー: #{e.message}")
      "認証コードの送信に失敗しました。\n" \
        "しばらく時間をおいてから再度お試しください。"
    end
  end

  def handle_verification_code_input(line_user_id, employee_id, verification_code)
    verification_record = VerificationCode.find_valid_code(employee_id, verification_code)

    if verification_record.nil?
      return "認証コードが正しくありません。\n" \
             "正しい6桁の認証コードを入力してください。"
    end
    employee = Employee.find_by(employee_id: employee_id)
    if employee
      employee.update!(line_id: line_user_id)
    else
      Employee.create!(
        employee_id: employee_id,
        role: determine_role_from_freee(employee_id),
        line_id: line_user_id
      )
    end
    verification_record.mark_as_used!
    clear_conversation_state(line_user_id)

    "認証が完了しました！\n" \
      "これでLINE Botの機能をご利用いただけます。\n" \
      "「ヘルプ」と入力すると利用可能なコマンドを確認できます。"
  rescue StandardError => e
    log_error("認証コード検証エラー: #{e.message}")
    "認証処理中にエラーが発生しました。\n" \
      "しばらく時間をおいてから再度お試しください。"
  end

  def determine_role_from_freee(employee_id)
    employees = freee_api_service.get_employees
    employee = employees.find { |emp| (emp[:id] || emp["id"]) == employee_id }

    return "employee" unless employee
    role_info = employee[:role] || employee["role"]

    case role_info
    when "admin", "owner"
      "owner"
    else
      "employee"
    end
  rescue StandardError => e
    log_error("役職取得エラー: #{e.message}")
    "employee"
  end

  def generate_multiple_employee_selection_message(employee_name, matches)
    message = "「#{employee_name}」に該当する従業員が複数見つかりました。\n\n"
    message += "該当する従業員の番号を入力してください:\n\n"

    matches.each_with_index do |employee, index|
      display_name = employee[:display_name] || employee["display_name"]
      employee_id = employee[:id] || employee["id"]
      message += "#{index + 1}. #{display_name} (ID: #{employee_id})\n"
    end

    message += "\n番号を入力してください:"
    message
  end

  # 依頼確認コマンド
  def handle_request_check_command(event)
    line_user_id = extract_user_id(event)

    return "認証が必要です。「認証」と入力して認証を行ってください。" unless employee_already_linked?(line_user_id)

    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    pending_requests = get_pending_requests(employee.employee_id)

    if pending_requests[:exchanges].empty? && pending_requests[:additions].empty? && pending_requests[:deletions].empty?
      "承認待ちの依頼はありません。"
    else
      generate_pending_requests_flex_message(
        pending_requests[:exchanges],
        pending_requests[:additions],
        pending_requests[:deletions]
      )
    end
  end

  def get_pending_requests(employee_id)
    {
      exchanges: get_pending_exchanges(employee_id),
      additions: get_pending_additions(employee_id),
      deletions: get_pending_deletions(employee_id)
    }
  end

  def get_pending_exchanges(employee_id)
    ShiftExchange.where(
      approver_id: employee_id,
      status: "pending"
    ).includes(:shift)
  end

  def get_pending_additions(employee_id)
    ShiftAddition.where(
      target_employee_id: employee_id,
      status: "pending"
    )
  end

  def get_pending_deletions(employee_id)
    ShiftDeletion.where(
      requester_id: employee_id,
      status: "pending"
    ).includes(:shift)
  end

  def generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests, pending_deletion_requests = [])
    bubbles = []
    pending_exchange_requests.each do |request|
      shift = request.shift
      requester = Employee.find_by(employee_id: request.requester_id)
      target = Employee.find_by(employee_id: request.approver_id)

      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]

      bubbles << {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🔄 シフト交代依頼",
              weight: "bold",
              color: "#ffffff",
              size: "sm"
            }
          ],
          backgroundColor: "#1DB446"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}",
              size: "md",
              color: "#666666",
              margin: "md"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "text",
              text: "申請者: #{requester&.display_name || '不明'}",
              size: "sm",
              color: "#666666",
              margin: "md"
            },
            {
              type: "text",
              text: "対象者: #{target&.display_name || '不明'}",
              size: "sm",
              color: "#666666",
              margin: "sm"
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
                label: "承認",
                data: "approve_#{request.id}",
                displayText: "承認"
              },
              style: "primary",
              color: "#1DB446"
            },
            {
              type: "button",
              action: {
                type: "postback",
                label: "拒否",
                data: "reject_#{request.id}",
                displayText: "拒否"
              },
              style: "secondary",
              color: "#FF6B6B"
            }
          ]
        }
      }
    end
    pending_addition_requests.each do |request|
      day_of_week = %w[日 月 火 水 木 金 土][Date.parse(request.shift_date).wday]

      bubbles << {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "➕ シフト追加依頼",
              weight: "bold",
              color: "#ffffff",
              size: "sm"
            }
          ],
          backgroundColor: "#FF6B6B"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "#{Date.parse(request.shift_date).strftime('%m/%d')} (#{day_of_week})",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "#{request.start_time}-#{request.end_time}",
              size: "md",
              color: "#666666",
              margin: "md"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "text",
              text: "対象者: #{Employee.find_by(employee_id: request.target_employee_id)&.display_name || '不明'}",
              size: "sm",
              color: "#666666",
              margin: "md"
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
                label: "承認",
                data: "approve_addition_#{request.request_id}",
                displayText: "承認"
              },
              style: "primary",
              color: "#1DB446"
            },
            {
              type: "button",
              action: {
                type: "postback",
                label: "拒否",
                data: "reject_addition_#{request.request_id}",
                displayText: "拒否"
              },
              style: "secondary",
              color: "#FF6B6B"
            }
          ]
        }
      }
    end
    pending_deletion_requests.each do |request|
      shift = request.shift
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]

      bubbles << {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "❌ 欠勤申請",
              weight: "bold",
              color: "#ffffff",
              size: "sm"
            }
          ],
          backgroundColor: "#FF6B6B"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}",
              size: "md",
              color: "#666666",
              margin: "md"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "text",
              text: "申請者: #{Employee.find_by(employee_id: request.employee_id)&.display_name || '不明'}",
              size: "sm",
              color: "#666666",
              margin: "md"
            },
            {
              type: "text",
              text: "理由: #{request.reason}",
              size: "sm",
              color: "#666666",
              margin: "sm"
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
                label: "承認",
                data: "approve_deletion_#{request.request_id}",
                displayText: "承認"
              },
              style: "primary",
              color: "#1DB446"
            },
            {
              type: "button",
              action: {
                type: "postback",
                label: "拒否",
                data: "reject_deletion_#{request.request_id}",
                displayText: "拒否"
              },
              style: "secondary",
              color: "#FF6B6B"
            }
          ]
        }
      }
    end

    if bubbles.empty?
      "承認待ちの依頼はありません。"
    else
      {
        type: "flex",
        altText: "承認待ちの依頼",
        contents: {
          type: "carousel",
          contents: bubbles
        }
      }
    end
  end

  def handle_non_command_message(event)
    if group_message?(event)
      nil
    else
      generate_unknown_command_message
    end
  end

  # LINE認証チェックの統一処理
  def check_line_authentication(event)
    line_user_id = extract_user_id(event)

    unless employee_already_linked?(line_user_id)
      message = if group_message?(event)
                  "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。"
                else
                  "認証が必要です。「認証」と入力して認証を行ってください。"
                end
      return { success: false, message: message }
    end

    { success: true }
  end

  # LINE権限チェックの統一処理
  def check_line_permission(event, command_type)
    line_user_id = extract_user_id(event)
    employee = find_employee_by_line_id(line_user_id)

    return { success: false, message: "従業員情報が見つかりません。" } unless employee

    case command_type
    when "shift_addition"
      unless employee.role == "owner"
        return { success: false, message: "シフト追加はオーナーのみが利用可能です。" }
      end
    when "shift_exchange", "shift_deletion", "shift_display"
      # 全従業員が利用可能
    end

    { success: true }
  end

  # LINEコマンド処理の統一処理
  def process_line_command_with_state(command_type, event, initial_state)
    line_user_id = extract_user_id(event)

    set_conversation_state(line_user_id, {
      "state" => initial_state,
      "step" => 1,
      "created_at" => Time.current
    })

    generate_line_initial_message(command_type)
  end

  # LINE初期メッセージ生成の統一処理
  def generate_line_initial_message(command_type)
    tomorrow = (Date.current + 1).strftime("%m/%d")

    case command_type
    when "shift_exchange"
      "📋 シフト交代依頼\n\n交代したいシフトの日付を入力してください。\n\n📝 入力例: #{tomorrow}\n⚠️ 過去の日付は選択できません"
    when "shift_addition"
      "シフト追加を開始します。\n追加するシフトの日付を入力してください。\n例：#{tomorrow}\n⚠️ 過去の日付は指定できません"
    when "shift_deletion"
      "欠勤申請\n\n欠勤したい日付を入力してください。\n例: #{tomorrow}"
    end
  end
end
