class WebhookController < ApplicationController
  protect_from_forgery with: :null_session

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    
    unless client.validate_signature(body, signature)
      head :bad_request
      return
    end

    events = client.parse_events_from(body)
    
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          handle_text_message(event)
        end
      end
    end

    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def handle_text_message(event)
    message_text = event.message['text']
    user_id = event['source']['userId']
    
    # 基本的なメッセージ処理
    case message_text
    when 'ヘルプ', 'help'
      reply_text = "勤怠管理システムへようこそ！\n\n利用可能なコマンド:\n- ヘルプ: このメッセージを表示\n- 認証: 認証コードを生成\n- シフト: シフト情報を確認\n- 勤怠: 勤怠状況を確認"
    when '認証'
      reply_text = "認証機能は準備中です。"
    when 'シフト'
      reply_text = "シフト確認機能は準備中です。"
    when '勤怠'
      reply_text = "勤怠確認機能は準備中です。"
    else
      reply_text = "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
    end

    client.reply_message(event['replyToken'], {
      type: 'text',
      text: reply_text
    })
  end
end
