# frozen_string_literal: true

module LineBotTestHelper
  def setup_line_bot_environment
    @line_channel_secret = "test_channel_secret"
    @line_channel_token = "test_channel_token"

    ENV["LINE_CHANNEL_SECRET"] = @line_channel_secret
    ENV["LINE_CHANNEL_TOKEN"] = @line_channel_token
  end

  def teardown_line_bot_environment
    ENV.delete("LINE_CHANNEL_SECRET")
    ENV.delete("LINE_CHANNEL_TOKEN")
  end

  def generate_line_signature(body)
    require "openssl"
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), @line_channel_secret, body)
  end

  def create_text_message_event(text:, user_id: "test_user_id", group_id: nil)
    source = { type: "user", userId: user_id }
    source[:groupId] = group_id if group_id

    {
      type: "message",
      message: { type: "text", text: text },
      source: source,
      replyToken: "test_reply_token"
    }
  end

  def create_webhook_payload(events:)
    { events: events }.to_json
  end

  def create_webhook_headers(payload)
    {
      "Content-Type" => "application/json",
      "X-Line-Signature" => generate_line_signature(payload)
    }
  end

  def assert_webhook_response(_response, expected_status: :ok)
    assert_response expected_status
  end

  def assert_group_message_identified(event)
    assert_equal "group", event["source"]["type"]
    assert_not_nil event["source"]["groupId"]
  end

  def assert_individual_message_identified(event)
    assert_equal "user", event["source"]["type"]
    assert_nil event["source"]["groupId"]
  end

  def assert_help_message_generated(message)
    assert_includes message, "勤怠管理システムへようこそ"
    assert_includes message, "ヘルプ"
    assert_includes message, "認証"
    assert_includes message, "シフト確認"
  end
end
