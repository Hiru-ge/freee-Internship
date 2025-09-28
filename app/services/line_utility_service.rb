# frozen_string_literal: true

class LineUtilityService
  def initialize; end

  # ===== イベント処理 =====

  # ユーザーIDの抽出
  def extract_user_id(event)
    event["source"]["userId"]
  end

  # グループIDの抽出
  def extract_group_id(event)
    return nil unless group_message?(event)

    event["source"]["groupId"]
  end

  # グループメッセージかどうかの判定
  def group_message?(event)
    event["source"]["type"] == "group"
  end

  # 個人メッセージかどうかの判定
  def individual_message?(event)
    event["source"]["type"] == "user"
  end

  # ===== 認証・従業員管理 =====

  # 従業員が既にリンクされているかチェック
  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  # LINE IDから従業員を検索
  def find_employee_by_line_id(line_id)
    Employee.find_by(line_id: line_id)
  end

  # 認証状態の取得
  def get_authentication_status(line_user_id)
    employee = Employee.find_by(line_id: line_user_id)
    return nil unless employee

    {
      linked: true,
      employee_id: employee.employee_id,
      display_name: employee.display_name,
      role: employee.role
    }
  end

  # freeeから従業員の役職を取得
  def determine_role_from_freee(employee_id)
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    employees = freee_service.get_employees
    employee = employees.find { |emp| (emp[:id] || emp["id"]) == employee_id }

    return "employee" unless employee

    # freeeの役職情報から判定
    role_info = employee[:role] || employee["role"]

    case role_info
    when "admin", "owner"
      "owner"
    else
      "employee"
    end
  rescue StandardError => e
    Rails.logger.error "役職取得エラー: #{e.message}"
    "employee" # デフォルトは従業員
  end

  # ===== 認証処理 =====

  # 認証コマンドの処理
  def handle_auth_command(event)
    # グループメッセージの場合は認証を禁止
    if group_message?(event)
      return "認証は個人チャットでのみ利用できます。\n" \
             "このボットと個人チャットを開始してから「認証」と入力してください。"
    end

    line_user_id = extract_user_id(event)

    # 既に認証済みかチェック
    return "既に認証済みです。" if employee_already_linked?(line_user_id)

    # 認証フロー開始
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

  # 従業員名入力の処理
  def handle_employee_name_input(line_user_id, employee_name)
    # 従業員名で検索
    matches = search_employees_by_name(employee_name)

    if matches.empty?
      # 明らかに従業員名でない文字列（長すぎる、特殊文字が多い等）の場合は無視
      if employee_name.length > 20 || employee_name.match?(/[^\p{Hiragana}\p{Katakana}\p{Han}a-zA-Z]/)
        return "有効な従業員名を入力してください。\n" \
               "フルネームでも部分入力でも検索できます。\n" \
               "例: 田中太郎、田中、太郎"
      end

      "「#{employee_name}」に該当する従業員が見つかりませんでした。\n" \
        "フルネームでも部分入力でも検索できます。\n" \
        "例: 田中太郎、田中、太郎"
    elsif matches.length == 1
      # 1件の場合は直接認証コード生成
      generate_verification_code_for_employee(line_user_id, matches.first)
    else
      # 複数件の場合は選択肢を提示
      handle_multiple_employee_matches(line_user_id, employee_name, matches)
    end
  end

  # 従業員名で検索
  def search_employees_by_name(name)
    find_employees_by_name(name)
  end

  # 複数従業員マッチ時の処理
  def handle_multiple_employee_matches(line_user_id, employee_name, matches)
    # 状態を更新
    set_conversation_state(line_user_id, {
                             "state" => "waiting_for_employee_selection",
                             "step" => 2,
                             "employee_matches" => matches,
                             "created_at" => Time.current
                           })

    generate_multiple_employee_selection_message(employee_name, matches)
  end

  # 従業員選択処理
  def handle_employee_selection_input(line_user_id, selection_text, employee_matches)
    # 選択された番号を解析
    selection_index = selection_text.to_i - 1

    if selection_index < 0 || selection_index >= employee_matches.length
      return "正しい番号を入力してください。\n" \
             "1から#{employee_matches.length}の間で選択してください。"
    end

    selected_employee = employee_matches[selection_index]
    generate_verification_code_for_employee(line_user_id, selected_employee)
  end

  # 認証コード生成
  def generate_verification_code_for_employee(line_user_id, employee)
    employee_id = employee[:id] || employee["id"]
    display_name = employee[:display_name] || employee["display_name"]

    # 認証コードを生成・送信
    begin
      result = AuthService.send_verification_code(employee_id)

      if result[:success]
        # 状態を更新
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
      Rails.logger.error "認証コード生成エラー: #{e.message}"
      "認証コードの送信に失敗しました。\n" \
        "しばらく時間をおいてから再度お試しください。"
    end
  end

  # 認証コード入力の処理
  def handle_verification_code_input(line_user_id, employee_id, verification_code)
    # 認証コードを検証
    verification_record = VerificationCode.find_valid_code(employee_id, verification_code)

    if verification_record.nil?
      return "認証コードが正しくありません。\n" \
             "正しい6桁の認証コードを入力してください。"
    end

    # 認証成功 - LINEアカウントと従業員を紐付け
    employee = Employee.find_by(employee_id: employee_id)
    if employee
      employee.update!(line_id: line_user_id)
    else
      # 従業員レコードが存在しない場合は作成
      Employee.create!(
        employee_id: employee_id,
        role: determine_role_from_freee(employee_id),
        line_id: line_user_id
      )
    end

    # 認証コードを削除
    verification_record.mark_as_used!

    # 会話状態をクリア
    clear_conversation_state(line_user_id)

    "認証が完了しました！\n" \
      "これでLINE Botの機能をご利用いただけます。\n" \
      "「ヘルプ」と入力すると利用可能なコマンドを確認できます。"
  rescue StandardError => e
    Rails.logger.error "認証コード検証エラー: #{e.message}"
    "認証処理中にエラーが発生しました。\n" \
      "しばらく時間をおいてから再度お試しください。"
  end

  # ===== 会話状態管理 =====

  # 会話状態の取得
  def get_conversation_state(line_user_id)
    state_record = ConversationState.find_active_state(line_user_id)
    return nil unless state_record

    state_record.state_hash
  end

  # 会話状態の設定
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

  # 会話状態のクリア
  def clear_conversation_state(line_user_id)
    ConversationState.where(line_user_id: line_user_id).delete_all
    true
  rescue StandardError => e
    Rails.logger.error "会話状態クリアエラー: #{e.message}"
    false
  end

  # 状態付きメッセージの処理
  def handle_stateful_message(line_user_id, message_text, state)
    # コマンドが送信された場合は会話状態をクリアして通常のコマンド処理に戻す
    if command_message?(message_text)
      clear_conversation_state(line_user_id)
      return nil # 通常のコマンド処理に委譲
    end

    current_state = state["state"] || state[:step] || state["step"]

    Rails.logger.debug "LineUtilityService: current_state = #{current_state}, message_text = #{message_text}, state = #{state}"

    case current_state
    when "waiting_for_employee_name"
      # 認証: 従業員名入力待ち
      handle_employee_name_input(line_user_id, message_text)
    when "waiting_for_employee_selection"
      # 認証: 従業員選択待ち
      employee_matches = state["employee_matches"]
      handle_employee_selection_input(line_user_id, message_text, employee_matches)
    when "waiting_for_verification_code"
      # 認証: 認証コード入力待ち
      employee_id = state["employee_id"]
      handle_verification_code_input(line_user_id, employee_id, message_text)
    when "waiting_for_shift_date", "waiting_shift_date"
      # シフト交代: 日付入力待ち
      shift_management_service = LineShiftManagementService.new
      result = shift_management_service.handle_shift_date_input(line_user_id, message_text)
      Rails.logger.debug "LineUtilityService: shift_management_service.handle_shift_date_input returned: #{result}"
      result
    when "waiting_for_shift_time", "waiting_shift_time"
      # シフト交代: 時間入力待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_time_input(line_user_id, message_text, state)
    when "waiting_for_shift_selection"
      # シフト交代: シフト選択待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_selection_input(line_user_id, message_text, state)
    when "waiting_for_employee_selection_exchange"
      # シフト交代: 従業員選択待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_employee_selection_input_exchange(line_user_id, message_text, state)
    when "waiting_for_confirmation_exchange"
      # シフト交代: 確認待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_confirmation_input(line_user_id, message_text, state)
    when "waiting_for_shift_addition_date", "waiting_shift_addition_date"
      # シフト追加: 日付入力待ち
      Rails.logger.debug "LineUtilityService: calling shift_management_service.handle_shift_addition_date_input"
      shift_management_service = LineShiftManagementService.new
      result = shift_management_service.handle_shift_addition_date_input(line_user_id, message_text)
      Rails.logger.debug "LineUtilityService: shift_management_service.handle_shift_addition_date_input returned: #{result}"
      result
    when "waiting_for_shift_addition_time"
      # シフト追加: 時間入力待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_addition_time_input(line_user_id, message_text, state)
    when "waiting_for_shift_addition_employee"
      # シフト追加: 対象従業員選択待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_addition_employee_input(line_user_id, message_text, state)
    when "waiting_for_shift_addition_confirmation"
      # シフト追加: 確認待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_addition_confirmation_input(line_user_id, message_text, state)
    when "waiting_for_shift_deletion_date"
      # 欠勤申請: 日付入力待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_deletion_date_input(line_user_id, message_text, state)
    when "waiting_for_shift_deletion_selection"
      # 欠勤申請: シフト選択待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_selection(line_user_id, message_text, state)
    when "waiting_deletion_reason"
      # 欠勤申請: 理由入力待ち
      shift_management_service = LineShiftManagementService.new
      shift_management_service.handle_shift_deletion_reason_input(line_user_id, message_text, state)
    else
      # 不明な状態の場合は状態をクリア
      clear_conversation_state(line_user_id)
      "不明な状態です。最初からやり直してください。"
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
      # 会話状態がない場合はnilを返す（通常のコマンド処理に委譲）
      nil
    end
  end

  # ===== 従業員検索・管理 =====

  # 従業員名の正規化
  def normalize_employee_name(name)
    # カタカナ→ひらがな変換、スペース除去
    name.tr("ァ-ヶ", "ぁ-ゟ").gsub(/\s+/, "")
  end

  # 従業員名の部分一致検索
  def find_employees_by_name(name)
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    employees = freee_service.get_employees
    normalized_name = normalize_employee_name(name)

    # 部分一致で検索
    employees.select do |employee|
      display_name = employee[:display_name] || employee["display_name"]
      next false unless display_name

      normalized_display_name = normalize_employee_name(display_name)

      normalized_display_name.include?(normalized_name) ||
        normalized_name.include?(normalized_display_name)
    end
  rescue StandardError => e
    Rails.logger.error "従業員検索エラー: #{e.message}"
    []
  end

  # 従業員IDの有効性チェック
  def valid_employee_id_format?(employee_id)
    employee_id.is_a?(String) && employee_id.match?(/^\d+$/)
  end

  # 従業員選択の解析
  def parse_employee_selection(message_text)
    # 数値の場合は従業員IDとして扱う
    if message_text.match?(/^\d+$/)
      return { type: :id, value: message_text } if valid_employee_id_format?(message_text)
    end

    # 文字列の場合は従業員名として扱う
    { type: :name, value: message_text }
  end

  # ===== シフト管理 =====

  # シフト重複チェック
  def has_shift_overlap?(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
    )

    existing_shifts.any? do |shift|
      # 時間の重複チェック
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
  end

  # 依頼可能な従業員と重複している従業員を取得
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

  # ===== ユーティリティ =====

  # リクエストIDの生成
  def generate_request_id(prefix = "REQ")
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # 日付フォーマット
  def format_date(date)
    date.strftime("%m/%d")
  end

  # 時間フォーマット
  def format_time(time)
    time.strftime("%H:%M")
  end

  # 日付と曜日のフォーマット
  def format_date_with_day(date)
    day_of_week = %w[日 月 火 水 木 金 土][date.wday]
    "#{format_date(date)} (#{day_of_week})"
  end

  # 時間範囲のフォーマット
  def format_time_range(start_time, end_time)
    "#{format_time(start_time)}-#{format_time(end_time)}"
  end

  # 現在の日時を取得
  def current_time
    Time.current
  end

  # 現在の日付を取得
  def current_date
    Date.current
  end

  # 今月の開始日を取得
  def current_month_start
    current_date.beginning_of_month
  end

  # 今月の終了日を取得
  def current_month_end
    current_date.end_of_month
  end

  # 来月の開始日を取得
  def next_month_start
    current_date.next_month.beginning_of_month
  end

  # 来月の終了日を取得
  def next_month_end
    current_date.next_month.end_of_month
  end

  # ===== メッセージ生成 =====

  # 複数従業員マッチ時のメッセージ生成
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

  # エラーメッセージの生成
  def generate_error_message(error_text)
    "❌ #{error_text}"
  end

  # 成功メッセージの生成
  def generate_success_message(success_text)
    "✅ #{success_text}"
  end

  # 警告メッセージの生成
  def generate_warning_message(warning_text)
    "⚠️ #{warning_text}"
  end

  # 情報メッセージの生成
  def generate_info_message(info_text)
    "ℹ️ #{info_text}"
  end

  # ===== ログ出力 =====

  def log_info(message)
    Rails.logger.info "[LineUtilityService] #{message}"
  end

  def log_error(message)
    Rails.logger.error "[LineUtilityService] #{message}"
  end

  def log_warn(message)
    Rails.logger.warn "[LineUtilityService] #{message}"
  end

  def log_debug(message)
    Rails.logger.debug "[LineUtilityService] #{message}"
  end

  private

  def command_message?(message_text)
    LineBotService::COMMANDS.key?(message_text)
  end
end
