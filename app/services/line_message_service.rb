class LineMessageService
  def initialize
  end

  # ヘルプメッセージの生成
  def generate_help_message(event = nil)
    "勤怠管理システムへようこそ！\n\n【利用可能なコマンド】\n・ヘルプ: このメッセージを表示\n・認証: LINEアカウントと従業員アカウントを紐付け\n・シフト確認: 個人のシフト情報を確認（認証必要）\n・全員シフト確認: 全従業員のシフト情報を確認（認証必要）\n・交代依頼: シフト交代依頼（認証必要）\n・依頼確認: 承認待ちのシフト交代リクエスト確認（認証必要）\n・追加依頼: シフト追加依頼（オーナーのみ、認証必要）\n\n認証は個人チャットでのみ可能です。このボットと個人チャットを開始して「認証」を行ってください"
  end

  # シフトFlex Messageの生成
  def generate_shift_flex_message_for_date(shifts)
    # カルーセル形式のFlex Messageを生成
    bubbles = shifts.map do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      
      {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})",
              weight: "bold",
              size: "lg",
              color: "#1DB446"
            },
            {
              type: "text",
              text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}",
              size: "md",
              color: "#666666",
              margin: "md"
            },
            {
              type: "text",
              text: "#{shift.employee.display_name}さん",
              size: "sm",
              color: "#999999",
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
              style: "primary",
              height: "sm",
              action: {
                type: "postback",
                label: "このシフトを選択",
                data: "shift_#{shift.id}"
              }
            }
          ]
        }
      }
    end
    
    {
      type: "flex",
      altText: "シフト選択",
      contents: {
        type: "carousel",
        contents: bubbles
      }
    }
  end

  # 承認待ちリクエストFlex Messageの生成
  def generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)
    bubbles = []
    
    # シフト交代リクエストのカード
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
              text: "依頼者: #{requester&.display_name || '不明'}",
              size: "sm",
              color: "#666666",
              margin: "md"
            },
            {
              type: "text",
              text: "交代先: #{target&.display_name || '不明'}",
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
              type: "box",
              layout: "horizontal",
              contents: [
                {
                  type: "button",
                  style: "primary",
                  height: "sm",
                  color: "#1DB446",
                  action: {
                    type: "postback",
                    label: "承認",
                    data: "approve_#{request.id}"
                  }
                },
                {
                  type: "button",
                  style: "secondary",
                  height: "sm",
                  color: "#FF6B6B",
                  action: {
                    type: "postback",
                    label: "否認",
                    data: "reject_#{request.id}"
                  }
                }
              ]
            }
          ]
        }
      }
    end
    
    # シフト追加リクエストのカード
    pending_addition_requests.each do |request|
      requester = Employee.find_by(employee_id: request.requester_id)
      target = Employee.find_by(employee_id: request.target_employee_id)
      
      day_of_week = %w[日 月 火 水 木 金 土][request.shift_date.wday]
      
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
              text: "#{request.shift_date.strftime('%m/%d')} (#{day_of_week})",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "#{request.start_time.strftime('%H:%M')}-#{request.end_time.strftime('%H:%M')}",
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
              text: "依頼者: #{requester&.display_name || '不明'}",
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
              type: "box",
              layout: "horizontal",
              contents: [
                {
                  type: "button",
                  style: "primary",
                  height: "sm",
                  color: "#1DB446",
                  action: {
                    type: "postback",
                    label: "承認",
                    data: "approve_addition_#{request.request_id}"
                  }
                },
                {
                  type: "button",
                  style: "secondary",
                  height: "sm",
                  color: "#FF6B6B",
                  action: {
                    type: "postback",
                    label: "否認",
                    data: "reject_addition_#{request.request_id}"
                  }
                }
              ]
            }
          ]
        }
      }
    end
    
    if bubbles.empty?
      return {
        type: "text",
        text: "承認待ちのリクエストはありません。"
      }
    end
    
    {
      type: "flex",
      altText: "承認待ちのリクエスト",
      contents: {
        type: "carousel",
        contents: bubbles
      }
    }
  end

  # シフト追加レスポンスの生成
  def generate_shift_addition_response(addition_request, status)
    date_str = addition_request.shift_date.strftime('%m/%d')
    day_of_week = %w[日 月 火 水 木 金 土][addition_request.shift_date.wday]
    time_str = "#{addition_request.start_time.strftime('%H:%M')}-#{addition_request.end_time.strftime('%H:%M')}"
    
    if status == 'approved'
      "✅ シフト追加が承認されました！\n\n" +
      "📅 日付: #{date_str} (#{day_of_week})\n" +
      "⏰ 時間: #{time_str}\n" +
      "👤 対象者: #{Employee.find_by(employee_id: addition_request.target_employee_id)&.display_name || '不明'}"
    else
      "❌ シフト追加が否認されました。\n\n" +
      "📅 日付: #{date_str} (#{day_of_week})\n" +
      "⏰ 時間: #{time_str}\n" +
      "👤 対象者: #{Employee.find_by(employee_id: addition_request.target_employee_id)&.display_name || '不明'}"
    end
  end

  # テキストメッセージの生成
  def generate_text_message(text)
    {
      type: "text",
      text: text
    }
  end

  # エラーメッセージの生成
  def generate_error_message(error_text)
    {
      type: "text",
      text: "❌ #{error_text}"
    }
  end

  # 成功メッセージの生成
  def generate_success_message(success_text)
    {
      type: "text",
      text: "✅ #{success_text}"
    }
  end

  private

  # ユーティリティメソッド
  def group_message?(event)
    event['source']['type'] == 'group'
  end
end
