require 'line/bot'
require 'ostruct'

class WebhookController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :require_login, if: -> { action_name == 'callback' }

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    
    unless client.validate_signature(body, signature)
      Rails.logger.warn "LINE Bot signature validation failed"
      head :bad_request
      return
    end

    events = client.parse_events_from(body)
    
    events.each do |event|
      process_event(event)
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error "LINE Bot webhook error: #{e.message}"
    head :internal_server_error
  end

  private

  def client
    @client ||= begin
      if defined?(Line::Bot::Client)
        Line::Bot::Client.new do |config|
          config.channel_secret = ENV['LINE_CHANNEL_SECRET']
          config.channel_token = ENV['LINE_CHANNEL_TOKEN']
        end
      else
        # テスト環境用のモック
        mock_client
      end
    end
  end

  def mock_client
    @mock_client ||= Class.new do
      def validate_signature(body, signature)
        true
      end

      def parse_events_from(body)
        []
      end

      def reply_message(token, message)
        true
      end
    end.new
  end

  def process_event(event)
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        handle_text_message(event)
      end
    end
  end

  def handle_text_message(event)
    line_bot_service = LineBotService.new
    reply_text = line_bot_service.handle_message(event)
    
    client.reply_message(event['replyToken'], {
      type: 'text',
      text: reply_text
    })
  rescue StandardError => e
    Rails.logger.error "LINE Bot message handling error: #{e.message}"
    client.reply_message(event['replyToken'], {
      type: 'text',
      text: "エラーが発生しました。しばらく時間をおいてから再度お試しください。"
    })
  end
end
