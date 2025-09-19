# frozen_string_literal: true

class LineMessageService
  def initialize; end

  # ヘルプメッセージの生成
  def generate_help_message(_event = nil)
    LineMessageGeneratorService.generate_help_message
  end

  # シフトFlex Messageの生成
  def generate_shift_flex_message_for_date(shifts)
    # カルーセル形式のFlex Messageを生成
    bubbles = shifts.map do |shift|
      shift_data = {
        date: shift.shift_date,
        start_time: shift.start_time,
        end_time: shift.end_time,
        employee_name: shift.employee.display_name
      }

      actions = [
        LineFlexMessageBuilderService.build_button(
          "このシフトを選択",
          "shift_#{shift.id}",
          "primary",
          "#1DB446"
        )
      ]

      LineFlexMessageBuilderService.build_shift_card(shift_data, actions)
    end

    {
      type: "flex",
      altText: "シフト選択",
      contents: LineFlexMessageBuilderService.build_carousel(bubbles)
    }
  end

  # 承認待ちリクエストFlex Messageの生成
  def generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests, pending_deletion_requests = [])
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

    # シフト削除リクエストのカード
    pending_deletion_requests.each do |request|
      shift = request.shift
      requester = Employee.find_by(employee_id: request.requester_id)

      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]

      bubbles << {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🗑️ シフト削除依頼",
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
              text: "依頼者: #{requester&.display_name || '不明'}",
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
                    data: "approve_deletion_#{request.request_id}"
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
                    data: "reject_deletion_#{request.request_id}"
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
        text: "承認待ちの依頼はありません。"
      }
    end

    {
      type: "flex",
      altText: "承認待ちの依頼",
      contents: {
        type: "carousel",
        contents: bubbles
      }
    }
  end

  # シフト追加レスポンスの生成
  def generate_shift_addition_response(addition_request, status)
    date_str = addition_request.shift_date.strftime("%m/%d")
    day_of_week = %w[日 月 火 水 木 金 土][addition_request.shift_date.wday]
    time_str = "#{addition_request.start_time.strftime('%H:%M')}-#{addition_request.end_time.strftime('%H:%M')}"

    if status == "approved"
      "✅ シフト追加が承認されました！\n\n" \
        "📅 日付: #{date_str} (#{day_of_week})\n" \
        "⏰ 時間: #{time_str}\n" \
        "👤 対象者: #{Employee.find_by(employee_id: addition_request.target_employee_id)&.display_name || '不明'}"
    else
      "❌ シフト追加が否認されました。\n\n" \
        "📅 日付: #{date_str} (#{day_of_week})\n" \
        "⏰ 時間: #{time_str}\n" \
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

  # 欠勤申請用シフト選択Flex Messageの生成
  def generate_shift_deletion_flex_message(shifts)
    bubbles = shifts.map do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]

      {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🚫 欠勤申請",
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
              color: "#FF6B6B",
              action: {
                type: "postback",
                label: "このシフトを欠勤申請",
                data: "deletion_shift_#{shift.id}",
                displayText: "#{shift.shift_date.strftime('%m/%d')}のシフトを欠勤申請します"
              }
            }
          ]
        }
      }
    end

    {
      type: "flex",
      altText: "欠勤申請 - シフトを選択してください",
      contents: {
        type: "carousel",
        contents: bubbles
      }
    }
  end

  private

  # ユーティリティメソッド
  def group_message?(event)
    event["source"]["type"] == "group"
  end
end
