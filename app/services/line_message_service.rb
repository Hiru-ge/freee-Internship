# frozen_string_literal: true

class LineMessageService
  def initialize; end

  # ヘルプメッセージの生成
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

  # 従業員が見つからない場合のメッセージ生成
  def generate_employee_not_found_message(employee_name)
    "「#{employee_name}」に該当する従業員が見つかりませんでした。\n\nフルネームでも部分入力でも検索できます。\n再度従業員名を入力してください:"
  end

  # エラーメッセージ生成
  def generate_error_message_by_type(error_type, _context = {})
    case error_type
    when :invalid_date
      "正しい日付形式で入力してください。\n例: 2024-01-15"
    when :invalid_time
      "正しい時間形式で入力してください。\n例: 9:00-17:00"
    when :invalid_employee_name
      "従業員名を正しく入力してください。\nフルネームでも部分入力でも検索できます。"
    when :invalid_number
      "正しい番号を入力してください。"
    when :shift_not_found
      "指定されたシフトが見つかりませんでした。"
    when :permission_denied
      "この操作を実行する権限がありません。"
    when :system_error
      "システムエラーが発生しました。しばらく時間をおいて再度お試しください。"
    else
      "エラーが発生しました。入力内容を確認してください。"
    end
  end

  # 成功メッセージ生成
  def generate_success_message_by_type(action_type, _context = {})
    case action_type
    when :authentication_completed
      "認証が完了しました！\n\n以下の機能が利用可能になりました:\n・シフト確認\n・全員シフト確認\n・交代依頼\n・追加依頼\n・欠勤申請\n・依頼確認"
    when :shift_exchange_request_created
      "シフト交代依頼を作成しました。\n承認をお待ちください。"
    when :shift_addition_request_created
      "シフト追加依頼を作成しました。\n承認をお待ちください。"
    when :request_approved
      "依頼が承認されました。"
    when :request_rejected
      "依頼が拒否されました。"
    else
      "操作が完了しました。"
    end
  end

  # 確認メッセージ生成
  def generate_confirmation_message(action_type, context = {})
    case action_type
    when :shift_exchange
      "以下の内容でシフト交代依頼を作成しますか？\n\n" \
      "日付: #{context[:date]}\n" \
      "時間: #{context[:time]}\n" \
      "依頼先: #{context[:target_employee]}\n\n" \
      "「はい」または「いいえ」で回答してください。"
    when :shift_addition
      "以下の内容でシフト追加依頼を作成しますか？\n\n" \
      "日付: #{context[:date]}\n" \
      "時間: #{context[:time]}\n" \
      "従業員: #{context[:employee]}\n\n" \
      "「はい」または「いいえ」で回答してください。"
    else
      "この操作を実行しますか？\n「はい」または「いいえ」で回答してください。"
    end
  end

  # 認証開始メッセージ生成
  def generate_auth_start_message
    "認証を開始します。\n\n従業員名を入力してください。\nフルネームでも部分入力でも検索できます。"
  end

  # 認証コード入力メッセージ生成
  def generate_auth_code_input_message(employee_name)
    "「#{employee_name}」で認証を開始します。\n\n認証コードを入力してください:"
  end

  # 認証失敗メッセージ生成
  def generate_auth_failed_message
    "認証に失敗しました。\n\n従業員名を再度入力してください。\nフルネームでも部分入力でも検索できます。"
  end

  # シフトカードの生成
  def build_shift_card(shift_data, actions = [])
    day_of_week = %w[日 月 火 水 木 金 土][shift_data[:date].wday]

    {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          {
            type: "text",
            text: "#{shift_data[:date].strftime('%m/%d')} (#{day_of_week})",
            weight: "bold",
            size: "lg",
            color: "#1DB446"
          },
          {
            type: "text",
            text: "#{shift_data[:start_time].strftime('%H:%M')}-#{shift_data[:end_time].strftime('%H:%M')}",
            size: "md",
            color: "#666666",
            margin: "md"
          },
          {
            type: "text",
            text: "#{shift_data[:employee_name]}さん",
            size: "sm",
            color: "#999999",
            margin: "sm"
          }
        ]
      },
      footer: if actions.any?
                {
                  type: "box",
                  layout: "vertical",
                  contents: actions
                }
              end
    }
  end

  # 従業員リストの生成
  def build_employee_list(employees, context = {})
    bubbles = employees.map do |employee|
      {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: employee[:display_name] || employee["display_name"],
              weight: "bold",
              size: "lg",
              color: "#1DB446"
            },
            {
              type: "text",
              text: "ID: #{employee[:id] || employee['id']}",
              size: "sm",
              color: "#666666",
              margin: "sm"
            }
          ]
        },
        footer: if context[:actions]
                  {
                    type: "box",
                    layout: "vertical",
                    contents: context[:actions]
                  }
                end
      }
    end

    {
      type: "carousel",
      contents: bubbles
    }
  end

  # 確認カードの生成
  def build_confirmation_card(title, message, actions)
    {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          {
            type: "text",
            text: title,
            weight: "bold",
            size: "lg",
            color: "#1DB446"
          },
          {
            type: "text",
            text: message,
            size: "md",
            color: "#666666",
            margin: "md",
            wrap: true
          }
        ]
      },
      footer: {
        type: "box",
        layout: "vertical",
        contents: actions
      }
    }
  end

  # ボタンの生成
  def build_button(label, action_data, style = "primary", color = "#1DB446")
    {
      type: "button",
      action: {
        type: "postback",
        label: label,
        data: action_data
      },
      style: style,
      color: color
    }
  end

  # 複数ボタンの生成
  def build_button_group(buttons)
    {
      type: "box",
      layout: "vertical",
      contents: buttons
    }
  end

  # カルーセル形式のFlex Messageの生成
  def build_carousel(bubbles)
    {
      type: "carousel",
      contents: bubbles
    }
  end

  # テキストボックスの生成
  def build_text_box(text, options = {})
    {
      type: "text",
      text: text,
      weight: options[:weight] || "normal",
      size: options[:size] || "md",
      color: options[:color] || "#000000",
      margin: options[:margin] || "none",
      wrap: options[:wrap] || false
    }
  end

  # ボックスレイアウトの生成
  def build_box(layout, contents, options = {})
    {
      type: "box",
      layout: layout,
      contents: contents,
      margin: options[:margin] || "none",
      padding: options[:padding] || "none"
    }
  end

  private

  # ユーティリティメソッド
  def group_message?(event)
    event["source"]["type"] == "group"
  end
end
