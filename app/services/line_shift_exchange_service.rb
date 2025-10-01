# frozen_string_literal: true

class LineShiftExchangeService
  def initialize
    @line_bot_service = LineBotService.new
  end

  # シフト交代コマンドの処理
  def handle_shift_exchange_command(event)
    line_user_id = @line_bot_service.extract_user_id(event)

    # 認証チェック
    unless @line_bot_service.employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if @line_bot_service.group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end

    # 従業員情報を取得
    employee = @line_bot_service.find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # シフト交代フロー開始
    @line_bot_service.set_conversation_state(line_user_id, {
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
    employee = @line_bot_service.find_employee_by_line_id(line_user_id)
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
    employee = @line_bot_service.find_employee_by_line_id(line_user_id)
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
    @line_bot_service.set_conversation_state(line_user_id, {
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
        @line_bot_service.set_conversation_state(line_user_id, {
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
    all_matches = @line_bot_service.find_employees_by_name(message_text)

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
      @line_bot_service.set_conversation_state(line_user_id, {
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

      @line_bot_service.set_conversation_state(line_user_id, {
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
      @line_bot_service.clear_conversation_state(line_user_id)

      result
    elsif message_text == "いいえ"
      # 状態をクリア
      @line_bot_service.clear_conversation_state(line_user_id)

      "シフト交代をキャンセルしました。"
    else
      "「はい」または「いいえ」で回答してください。"
    end
  end

  # シフト交代リクエストの作成
  def create_shift_exchange_request(line_user_id, shift_id, target_employee_id)
    employee = @line_bot_service.find_employee_by_line_id(line_user_id)
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

  private

  # 依頼可能な従業員を取得
  def get_available_employees_for_shift(shift)
    # 指定された日付・時間帯にシフトがない従業員を取得
    freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )

    all_employees = freee_service.get_employees
    available_employees = []

    all_employees.each do |employee|
      employee_id = employee[:id] || employee["id"]
      next if employee_id == shift.employee_id # 自分自身は除外

      # 指定された日付・時間帯にシフトがないかチェック
      existing_shift = Shift.where(
        employee_id: employee_id,
        shift_date: shift.shift_date
      ).where(
        "start_time < ? AND end_time > ?", shift.end_time, shift.start_time
      ).first

      available_employees << employee unless existing_shift
    end

    available_employees
  end

  # シフト交代用Flex Messageの生成
  def generate_shift_exchange_flex_message(shifts)
    # カルーセル形式のFlex Messageを生成
    bubbles = shifts.map do |shift|
      shift_data = {
        date: shift.shift_date,
        start_time: shift.start_time,
        end_time: shift.end_time,
        employee_name: shift.employee.display_name
      }

      actions = [
        build_button(
          "このシフトを選択",
          "shift_#{shift.id}",
          "primary",
          "#1DB446"
        )
      ]

      build_shift_card(shift_data, actions)
    end

    {
      type: "flex",
      altText: "シフト選択",
      contents: build_carousel(bubbles)
    }
  end

  # シフトカードの構築
  def build_shift_card(shift_data, actions)
    day_of_week = %w[日 月 火 水 木 金 土][shift_data[:date].wday]

    {
      type: "bubble",
      header: {
        type: "box",
        layout: "vertical",
        contents: [
          {
            type: "text",
            text: "📋 シフト交代",
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
            text: "#{shift_data[:date].strftime('%m/%d')} (#{day_of_week})",
            weight: "bold",
            size: "lg"
          },
          {
            type: "text",
            text: "#{shift_data[:start_time].strftime('%H:%M')}-#{shift_data[:end_time].strftime('%H:%M')}",
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
            text: "現在の担当: #{shift_data[:employee_name]}",
            size: "sm",
            color: "#666666",
            margin: "md"
          }
        ]
      },
      footer: {
        type: "box",
        layout: "vertical",
        contents: actions.map do |action|
          {
            type: "button",
            action: {
              type: "postback",
              label: action[:label],
              data: action[:data],
              displayText: action[:label]
            },
            style: action[:style],
            color: action[:color]
          }
        end
      }
    }
  end

  # ボタンの構築
  def build_button(label, data, style, color)
    {
      label: label,
      data: data,
      style: style,
      color: color
    }
  end

  # カルーセルの構築
  def build_carousel(bubbles)
    {
      type: "carousel",
      contents: bubbles
    }
  end
end
