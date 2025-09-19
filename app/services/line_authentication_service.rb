# frozen_string_literal: true

class LineAuthenticationService
  def initialize; end

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
    LineUtilityService.new.find_employees_by_name(name)
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

    LineMessageGeneratorService.generate_multiple_employee_selection_message(employee_name, matches)
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
        role: utility_service.determine_role_from_freee(employee_id),
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

  private

  def utility_service
    @utility_service ||= LineUtilityService.new
  end

  # ユーティリティメソッド（LineBotServiceから移行予定）
  def extract_user_id(event)
    event["source"]["userId"]
  end

  def group_message?(event)
    event["source"]["type"] == "group"
  end

  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
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
end
