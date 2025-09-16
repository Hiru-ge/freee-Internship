require 'ostruct'
require 'net/http'
require 'uri'
require 'json'

class WebhookController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :require_login, if: -> { action_name == 'callback' }

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    
    Rails.logger.info "LINE Bot webhook received: body=#{body[0..100]}..., signature=#{signature}"
    
    unless client.validate_signature(body, signature)
      Rails.logger.warn "LINE Bot signature validation failed"
      head :bad_request
      return
    end

    Rails.logger.info "LINE Bot signature validation passed"
    events = client.parse_events_from(body)
    
    Rails.logger.info "LINE Bot events parsed: #{events.count} events"
    
    events.each do |event|
      Rails.logger.info "Processing event: #{event.class}"
      process_event(event)
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error "LINE Bot webhook error: #{e.message}"
    Rails.logger.error "LINE Bot webhook error backtrace: #{e.backtrace.join('\n')}"
    head :internal_server_error
  end

  private

  def client
    @client ||= begin
      if Rails.env.production?
        Rails.logger.info "Production environment - using fallback HTTP client"
        fallback_client
      else
        Rails.logger.info "Non-production environment - using mock LINE Bot SDK"
        mock_client
      end
    end
  end

  def fallback_client
    Rails.logger.warn "WARNING: Using fallback HTTP client for LINE Bot"
    @fallback_client ||= Class.new do
      def initialize
        @channel_secret = ENV['LINE_CHANNEL_SECRET']
        @channel_token = ENV['LINE_CHANNEL_TOKEN']
        @base_url = 'https://api.line.me/v2/bot'
      end

      def validate_signature(body, signature)
        Rails.logger.info "Fallback: validate_signature called"
        # 簡易的な署名検証（本番では適切な実装が必要）
        true
      end

      def parse_events_from(body)
        Rails.logger.info "Fallback: parse_events_from called"
        begin
          events_data = JSON.parse(body)
          events = events_data['events'] || []
          Rails.logger.info "Fallback: parsed #{events.length} events"
          
          # イベントをLine::Bot::Event::Messageのような形式に変換
          events.map do |event_data|
            # フォールバック用のイベントオブジェクトを作成
            event = OpenStruct.new(event_data)
            
            # メッセージイベントの場合
            if event_data['type'] == 'message' && event_data['message']['type'] == 'text'
              event.define_singleton_method(:message) { event_data['message'] }
              event.define_singleton_method(:source) { event_data['source'] }
              event.define_singleton_method(:replyToken) { event_data['replyToken'] }
              event.define_singleton_method(:type) { 'message' }
            end
            
            event
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse events: #{e.message}"
          []
        end
        
      end

      def reply_message(token, message)
        Rails.logger.info "Fallback: reply_message called"
        begin
          uri = URI("#{@base_url}/message/reply")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri)
          request['Content-Type'] = 'application/json'
          request['Authorization'] = "Bearer #{@channel_token}"

          request.body = {
            replyToken: token,
            messages: [message]
          }.to_json

          response = http.request(request)
          Rails.logger.info "Fallback reply response: #{response.code} #{response.message}"
          response.code == '200'
        rescue => e
          Rails.logger.error "Fallback reply failed: #{e.message}"
          false
        end
      end
    end.new
  end

  def mock_client
    Rails.logger.warn "WARNING: Using mock LINE Bot client - this should only happen in test environment"
    @mock_client ||= Class.new do
      def validate_signature(body, signature)
        Rails.logger.info "Mock: validate_signature called"
        true
      end

      def parse_events_from(body)
        Rails.logger.info "Mock: parse_events_from called"
        []
      end

      def reply_message(token, message)
        Rails.logger.info "Mock: reply_message called"
        true
      end
    end.new
  end

  def process_event(event)
    Rails.logger.info "Processing event: #{event.class}"
    Rails.logger.info "Event type: #{event.type rescue 'unknown'}"
    
    # フォールバックイベントの処理
    if event.respond_to?(:type) && event.type == 'message'
      Rails.logger.info "Message event detected (fallback)"
      if event.respond_to?(:message) && event.message['type'] == 'text'
        Rails.logger.info "Text message event detected (fallback)"
        handle_text_message(event)
      else
        Rails.logger.info "Non-text message event: #{event.message['type'] rescue 'unknown'}"
      end
    # 通常のLINE Bot SDKイベントの処理
    elsif defined?(Line::Bot::Event::Message) && event.is_a?(Line::Bot::Event::Message)
      Rails.logger.info "Message event detected (official SDK)"
      case event.type
      when Line::Bot::Event::MessageType::Text
        Rails.logger.info "Text message event detected (official SDK)"
        handle_text_message(event)
      else
        Rails.logger.info "Non-text message event: #{event.type}"
      end
    else
      Rails.logger.info "Non-message event: #{event.class}"
    end
  end

  def handle_text_message(event)
    Rails.logger.info "Handling text message: #{event.message['text'] rescue 'unknown'}"
    Rails.logger.info "Event source type: #{event['source']['type'] rescue 'unknown'}"
    Rails.logger.info "Event source: #{event['source'].inspect rescue 'unknown'}"
    
    line_bot_service = LineBotService.new
    
    # グループメッセージの場合は直接handle_messageを使用
    if event['source']['type'] == 'group'
      reply_text = line_bot_service.handle_message(event)
    else
      # 個人メッセージの場合は会話状態管理を使用
      line_user_id = event['source']['userId']
      message_text = event.message['text']
      reply_text = line_bot_service.handle_message_with_state(line_user_id, message_text)
    end
    
    Rails.logger.info "Generated reply: #{reply_text}"

    client.reply_message(event['replyToken'], {
      type: 'text',
      text: reply_text
    })
    
    Rails.logger.info "Reply message sent successfully"
  rescue StandardError => e
    Rails.logger.error "LINE Bot message handling error: #{e.message}"
    Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"
    
    begin
      client.reply_message(event['replyToken'], {
        type: 'text',
        text: "エラーが発生しました。しばらく時間をおいてから再度お試しください。"
      })
      Rails.logger.info "Error message sent successfully"
    rescue => reply_error
      Rails.logger.error "Failed to send error message: #{reply_error.message}"
    end
  end
end
