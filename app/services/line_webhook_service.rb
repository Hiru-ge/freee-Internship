# frozen_string_literal: true

class LineWebhookService < LineBaseService
  def initialize
    super
  end

  def process_webhook_events(events)
    events.each do |event|
      process_single_webhook_event(event)
    end
    success_response("Events processed", status: :ok)
  rescue StandardError => e
    handle_service_error(e, "Webhook events processing")
  end

  private

  def process_single_webhook_event(event)
    case event_type(event)
    when "message"
      handle_webhook_message(event)
    when "postback"
      handle_webhook_postback(event)
    else
      log_unknown_event(event)
    end
  end

  def event_type(event)
    if event.respond_to?(:type)
      event.type
    elsif event.is_a?(Hash)
      event["type"]
    else
      "unknown"
    end
  end

  def handle_webhook_message(event)
    # LineBaseServiceに委譲
    reply_text = line_base_service.handle_message(event)

    # レスポンス送信処理
    send_line_reply(event, reply_text)
  end

  def handle_webhook_postback(event)
    # LineBaseServiceに委譲
    reply_text = line_base_service.handle_message(event)

    # レスポンス送信処理
    send_line_reply(event, reply_text)
  end

  def send_line_reply(event, reply_text)
    return if reply_text.nil?

    client = initialize_line_client

    if reply_text.is_a?(Hash) && reply_text[:type] == "flex"
      client.reply_message(event.replyToken, reply_text)
    else
      client.reply_message(event.replyToken, {
        type: "text",
        text: reply_text
      })
    end
  rescue StandardError => e
    handle_line_reply_error(event, e)
  end

  def initialize_line_client
    @line_client ||= if Rails.env.production?
                       create_fallback_client
                     else
                       create_mock_client
                     end
  end

  def create_fallback_client
    Rails.logger.warn "WARNING: Using fallback HTTP client for LINE Bot"
    Class.new do
      def initialize
        @channel_secret = ENV.fetch("LINE_CHANNEL_SECRET", nil)
        @channel_token = ENV.fetch("LINE_CHANNEL_TOKEN", nil)
        @base_url = "https://api.line.me/v2/bot"
      end

      def validate_signature(_body, _signature)
        Rails.logger.info "Fallback: validate_signature called"
        true
      end

      def parse_events_from(body)
        Rails.logger.info "Fallback: parse_events_from called"
        begin
          events_data = JSON.parse(body)
          events = events_data["events"] || []
          Rails.logger.info "Fallback: parsed #{events.length} events"

          events.map do |event_data|
            event = OpenStruct.new(event_data)

            if event_data["type"] == "message" && event_data["message"]["type"] == "text"
              event.define_singleton_method(:message) { event_data["message"] }
              event.define_singleton_method(:source) { event_data["source"] }
              event.define_singleton_method(:replyToken) { event_data["replyToken"] }
              event.define_singleton_method(:type) { "message" }
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

  def create_mock_client
    Rails.logger.warn "WARNING: Using mock LINE Bot client - this should only happen in test environment"
    Class.new do
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

  def handle_line_reply_error(event, error)
    Rails.logger.error "LINE reply error: #{error.message}"

    begin
      client = initialize_line_client
      client.reply_message(event.replyToken, {
        type: "text",
        text: "申し訳ございませんが、処理中にエラーが発生しました。"
      })
    rescue StandardError => reply_error
      Rails.logger.error "Failed to send error message: #{reply_error.message}"
    end
  end

  def log_unknown_event(event)
    Rails.logger.info "Unknown event type: #{event.class}"
  end

  def line_base_service
    @line_base_service ||= LineBaseService.new
  end
end
