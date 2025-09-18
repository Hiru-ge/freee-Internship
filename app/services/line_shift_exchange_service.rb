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
    # IDまたはrequest_idで検索
    exchange_request = ShiftExchange.find_by(id: request_id) || ShiftExchange.find_by(request_id: request_id)
    
    unless exchange_request
      return "シフト交代リクエストが見つかりません。"
    end
    
    if action == 'approve'
      # シフト交代を実行
      exchange_request.update!(status: 'approved', responded_at: Time.current)
      
      # シフトの所有者を変更
      shift = Shift.find(exchange_request.shift_id)
      shift.update!(employee_id: exchange_request.approver_id)
      
      return "✅ シフト交代リクエストを承認しました。\n#{shift.shift_date.strftime('%m/%d')}"
    elsif action == 'reject'
      # リクエストを拒否
      exchange_request.update!(status: 'rejected', responded_at: Time.current)
      
      return "❌ シフト交代リクエストを拒否しました。"
    end
    
    "不明なアクションです。"
  end

  # シフト交代状況確認コマンドの処理
  def handle_exchange_status_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    
    # 申請者のシフト交代リクエストを取得
    sent_requests = ShiftExchange.where(requester_id: employee.employee_id)
    
    if sent_requests.empty?
      return "シフト交代リクエストはありません。"
    end
    
    message = "📊 シフト交代状況\n\n"
    
    # 承認待ちの件数を計算
    pending_count = sent_requests.where(status: 'pending').count
    approved_count = sent_requests.where(status: 'approved').count
    rejected_count = sent_requests.where(status: 'rejected').count
    cancelled_count = sent_requests.where(status: 'cancelled').count
    
    if pending_count > 0
      message += "⏳ 承認待ち (#{pending_count}件)\n"
    end
    if approved_count > 0
      message += "✅ 承認済み (#{approved_count}件)\n"
    end
    if rejected_count > 0
      message += "❌ 拒否済み (#{rejected_count}件)\n"
    end
    if cancelled_count > 0
      message += "🚫 キャンセル済み (#{cancelled_count}件)\n"
    end
    
    message += "\n"
    
    sent_requests.each do |request|
      shift = Shift.find(request.shift_id)
      approver = Employee.find_by(employee_id: request.approver_id)
      
      status_text = case request.status
      when 'pending' then "⏳ 承認待ち"
      when 'approved' then "✅ 承認済み"
      when 'rejected' then "❌ 拒否"
      when 'cancelled' then "🚫 キャンセル"
      else request.status
      end
      
      message += "日付: #{shift.shift_date.strftime('%m/%d')}\n"
      message += "時間: #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
      message += "対象: #{approver&.employee_id || '不明'}\n"
      message += "状況: #{status_text}\n\n"
    end
    
    message
  end

  # 依頼キャンセルコマンドの処理
  def handle_cancel_request_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end
    
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    
    # 承認待ちのリクエストを取得
    pending_requests = ShiftExchange.where(
      requester_id: employee.employee_id,
      status: 'pending'
    )
    
    if pending_requests.empty?
      return "キャンセル可能なリクエストはありません。"
    end
    
    # 最初のリクエストをキャンセル
    request = pending_requests.first
    request.update!(status: 'cancelled', responded_at: Time.current)
    
    "シフト交代リクエストをキャンセルしました。"
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

    # 既に同じシフトに対して同じ申請者から同じ承認者へのリクエストが存在しないかチェック
    existing_request = ShiftExchange.find_by(
      requester_id: employee.employee_id,
      shift_id: shift_id,
      approver_id: target_employee_id,
      status: ['pending', 'approved']
    )
    return "既に同じシフト交代リクエストが申請されています。" if existing_request

    # シフト交代リクエストを作成
    exchange_request = ShiftExchange.create!(
      requester_id: employee.employee_id,
      approver_id: target_employee_id,
      shift_id: shift_id,
      status: 'pending',
      request_id: "req_#{SecureRandom.hex(8)}"
    )

    # 通知を送信
    send_shift_exchange_notification(exchange_request)

    "シフト交代リクエストを送信しました。\n承認をお待ちください。"
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

  # シフト交代通知の送信
  def send_shift_exchange_notification(exchange_request)
    # 通知処理は後で実装
    Rails.logger.info "シフト交代リクエスト通知: #{exchange_request.request_id}"
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
