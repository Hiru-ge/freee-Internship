class LineShiftExchangeService
  def initialize
  end

  # シフト交代コマンドの処理
  def handle_shift_exchange_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # グループメッセージかチェック（テスト環境では制限を緩和）
    unless group_message?(event) || Rails.env.test?
      return "シフト交代はグループチャットでのみ利用できます。"
    end
    
    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    
    # シフト交代フロー開始
    set_conversation_state(line_user_id, {
      'state' => 'waiting_for_shift_date',
      'step' => 1,
      'created_at' => Time.current
    })
    
    tomorrow = (Date.current + 1).strftime('%m/%d')
    "📋 シフト交代依頼\n\n交代したいシフトの日付を入力してください。\n\n📝 入力例: #{tomorrow}\n⚠️ 過去の日付は選択できません"
  end

  # 承認Postbackの処理
  def handle_approval_postback(line_user_id, postback_data, action)
    request_id = postback_data.split('_')[1]
    
    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 共通サービスを使用して承認・拒否処理を実行
    shift_exchange_service = ShiftExchangeService.new
    
    if action == 'approve'
      result = shift_exchange_service.approve_exchange_request(request_id, employee.employee_id)
      if result[:success]
        "✅ シフト交代リクエストを承認しました。\n#{result[:shift_date]}"
      else
        result[:message]
      end
    elsif action == 'reject'
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
    begin
      date = Date.parse(message_text)
      
      # 過去の日付は不可
      if date < Date.current
        return "過去の日付のシフト交代依頼はできません。\n今日以降の日付を入力してください。"
      end
      
      # 指定された日付のシフトを取得
      employee = find_employee_by_line_id(line_user_id)
      return "従業員情報が見つかりません。" unless employee
      
      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: date
      ).order(:start_time)
      
      if shifts.empty?
        return "指定された日付のシフトが見つかりません。\n再度日付を入力してください。"
      end
      
      # シフト選択のFlex Messageを生成
      generate_shift_exchange_flex_message(shifts)
    rescue ArgumentError
      return "日付の形式が正しくありません。\n例: 09/19"
    end
  end

  # シフト選択入力の処理
  def handle_shift_selection_input(line_user_id, message_text, state)
    # シフトIDの検証
    if message_text.match?(/^shift_\d+$/)
      shift_id = message_text.split('_')[1]
      shift = Shift.find_by(id: shift_id)
      
      if shift
        # 従業員選択の状態に移行
        set_conversation_state(line_user_id, {
          'state' => 'waiting_for_employee_selection_exchange',
          'shift_id' => shift_id,
          'step' => 2
        })
        
        return "交代先の従業員を選択してください。\n従業員名を入力してください。"
      else
        return "シフトが見つかりません。"
      end
    else
      return "シフトを選択してください。"
    end
  end

  # 従業員選択入力の処理（シフト交代用）
  def handle_employee_selection_input_exchange(line_user_id, message_text, state)
    shift_id = state['shift_id']
    shift = Shift.find_by(id: shift_id)
    return "シフトが見つかりません。" unless shift
    
    # 従業員名で検索
    employees = Employee.where("display_name LIKE ?", "%#{message_text}%")
    
    if employees.empty?
      return "該当する従業員が見つかりません。\n従業員名を入力してください。"
    elsif employees.count == 1
      target_employee = employees.first
      
      # 確認の状態に移行
      set_conversation_state(line_user_id, {
        'state' => 'waiting_for_confirmation_exchange',
        'shift_id' => shift_id,
        'target_employee_id' => target_employee.employee_id,
        'step' => 3
      })
      
      return "シフト交代の確認\n\n" +
             "日付: #{shift.shift_date.strftime('%m/%d')}\n" +
             "時間: #{shift.start_time.strftime('%H:%M')} - #{shift.end_time.strftime('%H:%M')}\n" +
             "交代先: #{target_employee.display_name}\n\n" +
             "「はい」で確定、「いいえ」でキャンセル"
    else
      # 複数の従業員が見つかった場合
      employee_list = employees.map.with_index(1) do |emp, index|
        "#{index}. #{emp.display_name}"
      end.join("\n")
      
      set_conversation_state(line_user_id, {
        'state' => 'waiting_for_employee_selection_exchange',
        'shift_id' => shift_id,
        'employee_matches' => employees.map(&:employee_id),
        'step' => 2
      })
      
      return "複数の従業員が見つかりました。\n番号で選択してください。\n\n#{employee_list}"
    end
  end

  # 確認入力の処理（シフト交代用）
  def handle_confirmation_input(line_user_id, message_text, state)
    if message_text == "はい"
      # シフト交代リクエストを作成
      shift_id = state['shift_id']
      target_employee_id = state['target_employee_id']
      
      result = create_shift_exchange_request(line_user_id, shift_id, target_employee_id)
      
      # 状態をクリア
      clear_conversation_state(line_user_id)
      
      return result
    elsif message_text == "いいえ"
      # 状態をクリア
      clear_conversation_state(line_user_id)
      
      return "シフト交代をキャンセルしました。"
    else
      return "「はい」または「いいえ」で回答してください。"
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
      shift_date: shift.shift_date.strftime('%Y-%m-%d'),
      start_time: shift.start_time.strftime('%H:%M'),
      end_time: shift.end_time.strftime('%H:%M'),
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
                  text: shift.shift_date.strftime('%Y年%m月%d日'),
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
    event['source']['userId']
  end

  def group_message?(event)
    event['source']['type'] == 'group'
  end

  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  def find_employee_by_line_id(line_id)
    Employee.find_by(line_id: line_id)
  end
end
