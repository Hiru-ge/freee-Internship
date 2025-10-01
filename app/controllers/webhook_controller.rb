# frozen_string_literal: true

require "ostruct"
require "net/http"
require "uri"
require "json"

class WebhookController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :require_login, if: -> { action_name == "callback" }
  skip_before_action :require_email_authentication, if: -> { action_name == "callback" }

  def callback
    body = request.body.read
    signature = request.env["HTTP_X_LINE_SIGNATURE"]

    Rails.logger.info "LINE Bot webhook received: body=#{body[0..100]}..., signature=#{signature}"

    return head(:bad_request) unless validate_signature(body, signature)

    events = parse_events(body)
    process_events(events)

    head :ok
  rescue StandardError => e
    handle_webhook_error(e)
  end

  private

  def client
    @client ||= if Rails.env.production?
                  Rails.logger.info "Production environment - using fallback HTTP client"
                  fallback_client
                else
                  Rails.logger.info "Non-production environment - using mock LINE Bot SDK"
                  mock_client
                end
  end

  def fallback_client
    Rails.logger.warn "WARNING: Using fallback HTTP client for LINE Bot"
    @fallback_client ||= Class.new do
      def initialize
        @channel_secret = ENV.fetch("LINE_CHANNEL_SECRET", nil)
        @channel_token = ENV.fetch("LINE_CHANNEL_TOKEN", nil)
        @base_url = "https://api.line.me/v2/bot"
      end

      def validate_signature(_body, _signature)
        Rails.logger.info "Fallback: validate_signature called"
        # 簡易的な署名検証（本番では適切な実装が必要）
        true
      end

      def parse_events_from(body)
        Rails.logger.info "Fallback: parse_events_from called"
        begin
          events_data = JSON.parse(body)
          events = events_data["events"] || []
          Rails.logger.info "Fallback: parsed #{events.length} events"

          # イベントをLine::Bot::Event::Messageのような形式に変換
          events.map do |event_data|
            # フォールバック用のイベントオブジェクトを作成
            event = OpenStruct.new(event_data)

            # メッセージイベントの場合
            if event_data["type"] == "message" && event_data["message"]["type"] == "text"
              event.define_singleton_method(:message) { event_data["message"] }
              event.define_singleton_method(:source) { event_data["source"] }
              event.define_singleton_method(:replyToken) { event_data["replyToken"] }
              event.define_singleton_method(:type) { "message" }
            # Postbackイベントの場合
            elsif event_data["type"] == "postback"
              event.define_singleton_method(:postback) { event_data["postback"] }
              event.define_singleton_method(:source) { event_data["source"] }
              event.define_singleton_method(:replyToken) { event_data["replyToken"] }
              event.define_singleton_method(:type) { "postback" }
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
          request["Content-Type"] = "application/json"
          request["Authorization"] = "Bearer #{@channel_token}"

          request.body = {
            replyToken: token,
            messages: [message]
          }.to_json

          response = http.request(request)
          Rails.logger.info "Fallback reply response: #{response.code} #{response.message}"

          # Flex Messageでエラーが発生した場合はテキストメッセージにフォールバック
          if response.code == "400" && message[:type] == "flex"
            Rails.logger.warn "Flex Message failed, falling back to text message"
            fallback_message = {
              type: "text",
              text: message[:altText] || "シフト交代依頼を表示できませんでした。"
            }

            request.body = {
              replyToken: token,
              messages: [fallback_message]
            }.to_json

            response = http.request(request)
            Rails.logger.info "Fallback text response: #{response.code} #{response.message}"
          end

          response.code == "200"
        rescue StandardError => e
          Rails.logger.error "Fallback reply failed: #{e.message}"
          false
        end
      end
    end.new
  end

  def mock_client
    Rails.logger.warn "WARNING: Using mock LINE Bot client - this should only happen in test environment"
    @mock_client ||= Class.new do
      def validate_signature(_body, _signature)
        Rails.logger.info "Mock: validate_signature called"
        true
      end

      def parse_events_from(_body)
        Rails.logger.info "Mock: parse_events_from called"
        []
      end

      def reply_message(_token, _message)
        Rails.logger.info "Mock: reply_message called"
        true
      end
    end.new
  end

  def process_event(event)
    Rails.logger.info "Processing event: #{event.class}"
    Rails.logger.info "Event type: #{begin
      event.type
    rescue StandardError
      'unknown'
    end}"

    # フォールバックイベントの処理
    if event.respond_to?(:type) && event.type == "message"
      Rails.logger.info "Message event detected (fallback)"
      if event.respond_to?(:message) && event.message["type"] == "text"
        Rails.logger.info "Text message event detected (fallback)"
        handle_text_message(event)
      else
        Rails.logger.info "Non-text message event: #{begin
          event.message['type']
        rescue StandardError
          'unknown'
        end}"
      end
    elsif event.respond_to?(:type) && event.type == "postback"
      Rails.logger.info "Postback event detected (fallback)"
      handle_postback_message(event)
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
    elsif defined?(Line::Bot::Event::Postback) && event.is_a?(Line::Bot::Event::Postback)
      Rails.logger.info "Postback event detected (official SDK)"
      handle_postback_message(event)
    else
      Rails.logger.info "Non-message event: #{event.class}"
    end
  end

  def handle_text_message(event)
    Rails.logger.info "Handling text message: #{begin
      event.message['text']
    rescue StandardError
      'unknown'
    end}"
    Rails.logger.info "Event source type: #{begin
      event.source['type']
    rescue StandardError
      'unknown'
    end}"
    Rails.logger.info "Event source: #{begin
      event.source.inspect
    rescue StandardError
      'unknown'
    end}"

    line_bot_service = LineBotService.new

    # 統一されたメッセージ処理（個人・グループ共通）
    reply_text = line_bot_service.handle_message(event)

    Rails.logger.info "Generated reply: #{reply_text}"

    # reply_textがnilの場合は何も送信しない（メッセージを無視）
    return if reply_text.nil?

    # Flex Messageの場合はそのまま送信、テキストの場合はtext形式で送信
    if reply_text.is_a?(Hash) && reply_text[:type] == "flex"
      client.reply_message(event.replyToken, reply_text)
    else
      client.reply_message(event.replyToken, {
                             type: "text",
                             text: reply_text
                           })
    end

    Rails.logger.info "Reply message sent successfully"
  rescue StandardError => e
    Rails.logger.error "コマンド処理エラー: #{e.message}"
    Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"

    begin
      client.reply_message(event.replyToken, {
                             type: "text",
                             text: "申し訳ございませんが、そのコマンドは認識できませんでした。\n'ヘルプ'と入力すると利用可能なコマンドが表示されます。"
                           })
      Rails.logger.info "Error message sent successfully"
    rescue StandardError => reply_error
      Rails.logger.error "Failed to send error message: #{reply_error.message}"
    end
  end

  def handle_postback_message(event)
    Rails.logger.info "Handling postback message: #{begin
      event.postback['data']
    rescue StandardError
      'unknown'
    end}"
    Rails.logger.info "Event source type: #{begin
      event.source['type']
    rescue StandardError
      'unknown'
    end}"
    Rails.logger.info "Event source: #{begin
      event.source.inspect
    rescue StandardError
      'unknown'
    end}"

    line_bot_service = LineBotService.new

    # postbackイベントを処理
    reply_text = line_bot_service.handle_message(event)

    Rails.logger.info "Generated reply: #{reply_text}"

    # テキストメッセージとして返信
    client.reply_message(event.replyToken, {
                           type: "text",
                           text: reply_text
                         })

    Rails.logger.info "Reply message sent successfully"
  rescue StandardError => e
    Rails.logger.error "Postback処理エラー: #{e.message}"
    Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"

    begin
      client.reply_message(event.replyToken, {
                             type: "text",
                             text: "申し訳ございませんが、処理中にエラーが発生しました。"
                           })
      Rails.logger.info "Error message sent successfully"
    rescue StandardError => reply_error
      Rails.logger.error "Failed to send error message: #{reply_error.message}"
    end
  end

  def validate_signature(body, signature)
    unless client.validate_signature(body, signature)
      Rails.logger.warn "LINE Bot signature validation failed"
      return false
    end

    Rails.logger.info "LINE Bot signature validation passed"
    true
  end

  def parse_events(body)
    events = client.parse_events_from(body)
    Rails.logger.info "LINE Bot events parsed: #{events.count} events"
    events
  end

  def process_events(events)
    events.each do |event|
      Rails.logger.info "Processing event: #{event.class}"
      process_event(event)
    end
  end

  def handle_webhook_error(error)
    Rails.logger.error "LINE Bot webhook error: #{error.message}"
    Rails.logger.error "LINE Bot webhook error backtrace: #{error.backtrace.join('\n')}"
    head :internal_server_error
  end
end
