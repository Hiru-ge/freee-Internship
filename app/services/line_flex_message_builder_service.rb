# frozen_string_literal: true

class LineFlexMessageBuilderService
  # シフトカードの生成
  def self.build_shift_card(shift_data, actions = [])
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
      footer: actions.any? ? {
        type: "box",
        layout: "vertical",
        contents: actions
      } : nil
    }
  end

  # 従業員リストの生成
  def self.build_employee_list(employees, context = {})
    bubbles = employees.map do |employee|
      {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: employee[:display_name] || employee['display_name'],
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
        footer: context[:actions] ? {
          type: "box",
          layout: "vertical",
          contents: context[:actions]
        } : nil
      }
    end

    {
      type: "carousel",
      contents: bubbles
    }
  end

  # 確認カードの生成
  def self.build_confirmation_card(title, message, actions)
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

  # 承認待ちリクエストカードの生成
  def self.build_pending_request_card(request_data, request_type)
    case request_type
    when :shift_exchange
      build_shift_exchange_request_card(request_data)
    when :shift_addition
      build_shift_addition_request_card(request_data)
    else
      build_generic_request_card(request_data)
    end
  end

  # シフト交代リクエストカードの生成
  def self.build_shift_exchange_request_card(request_data)
    {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          {
            type: "text",
            text: "シフト交代依頼",
            weight: "bold",
            size: "lg",
            color: "#1DB446"
          },
          {
            type: "text",
            text: "日付: #{request_data[:date].strftime('%m/%d')}",
            size: "md",
            color: "#666666",
            margin: "md"
          },
          {
            type: "text",
            text: "時間: #{request_data[:start_time].strftime('%H:%M')}-#{request_data[:end_time].strftime('%H:%M')}",
            size: "md",
            color: "#666666",
            margin: "sm"
          },
          {
            type: "text",
            text: "申請者: #{request_data[:applicant_name]}",
            size: "md",
            color: "#666666",
            margin: "sm"
          },
          {
            type: "text",
            text: "依頼先: #{request_data[:target_employee_name]}",
            size: "md",
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
              data: "approve_exchange_#{request_data[:id]}"
            },
            style: "primary",
            color: "#1DB446"
          },
          {
            type: "button",
            action: {
              type: "postback",
              label: "拒否",
              data: "reject_exchange_#{request_data[:id]}"
            },
            style: "secondary",
            color: "#FF6B6B"
          }
        ]
      }
    }
  end

  # シフト追加リクエストカードの生成
  def self.build_shift_addition_request_card(request_data)
    {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          {
            type: "text",
            text: "シフト追加依頼",
            weight: "bold",
            size: "lg",
            color: "#1DB446"
          },
          {
            type: "text",
            text: "日付: #{request_data[:date].strftime('%m/%d')}",
            size: "md",
            color: "#666666",
            margin: "md"
          },
          {
            type: "text",
            text: "時間: #{request_data[:start_time].strftime('%H:%M')}-#{request_data[:end_time].strftime('%H:%M')}",
            size: "md",
            color: "#666666",
            margin: "sm"
          },
          {
            type: "text",
            text: "申請者: #{request_data[:applicant_name]}",
            size: "md",
            color: "#666666",
            margin: "sm"
          },
          {
            type: "text",
            text: "対象従業員: #{request_data[:target_employee_name]}",
            size: "md",
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
              data: "approve_addition_#{request_data[:id]}"
            },
            style: "primary",
            color: "#1DB446"
          },
          {
            type: "button",
            action: {
              type: "postback",
              label: "拒否",
              data: "reject_addition_#{request_data[:id]}"
            },
            style: "secondary",
            color: "#FF6B6B"
          }
        ]
      }
    }
  end

  # 汎用リクエストカードの生成
  def self.build_generic_request_card(request_data)
    {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          {
            type: "text",
            text: "リクエスト",
            weight: "bold",
            size: "lg",
            color: "#1DB446"
          },
          {
            type: "text",
            text: request_data[:message] || "詳細情報なし",
            size: "md",
            color: "#666666",
            margin: "md",
            wrap: true
          }
        ]
      }
    }
  end

  # ボタンの生成
  def self.build_button(label, action_data, style = "primary", color = "#1DB446")
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
  def self.build_button_group(buttons)
    {
      type: "box",
      layout: "vertical",
      contents: buttons
    }
  end

  # カルーセル形式のFlex Messageの生成
  def self.build_carousel(bubbles)
    {
      type: "carousel",
      contents: bubbles
    }
  end

  # テキストボックスの生成
  def self.build_text_box(text, options = {})
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
  def self.build_box(layout, contents, options = {})
    {
      type: "box",
      layout: layout,
      contents: contents,
      margin: options[:margin] || "none",
      padding: options[:padding] || "none"
    }
  end
end
