# frozen_string_literal: true

require "test_helper"

class WebhookControllerFallbackTest < ActionDispatch::IntegrationTest
  def setup
    @webhook_url = "/webhook/callback"
    @valid_signature = "test_signature"
    @valid_body = {
      "destination" => "U1234567890",
      "events" => [
        {
          "type" => "message",
          "message" => {
            "type" => "text",
            "text" => "ヘルプ"
          },
          "source" => {
            "type" => "user",
            "userId" => "test_user_id"
          },
          "replyToken" => "test_reply_token"
        }
      ]
    }.to_json
  end

  test "fallback client should parse events correctly" do
    # 環境変数を設定
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    # フォールバッククライアントを直接作成してテスト
    client = controller.send(:fallback_client)

    # フォールバッククライアントのparse_events_fromメソッドをテスト
    events = client.parse_events_from(@valid_body)

    assert_equal 1, events.length
    assert_equal "message", events.first.type
    assert_equal "ヘルプ", events.first.message["text"]
  end

  test "fallback client should validate signature" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    # フォールバッククライアントのvalidate_signatureメソッドをテスト
    result = client.validate_signature(@valid_body, @valid_signature)

    assert result, "Signature validation should pass in fallback client"
  end

  test "fallback client should have required methods" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    # フォールバッククライアントのメソッドが正常に動作することを確認
    assert_nothing_raised { client.validate_signature(@valid_body, @valid_signature) }
    assert_nothing_raised { client.parse_events_from(@valid_body) }
    assert_nothing_raised { client.reply_message("test_token", "test_message") }
  end

  test "mock client should have required methods" do
    controller = WebhookController.new
    client = controller.send(:mock_client)

    # モッククライアントのメソッドが正常に動作することを確認
    assert_nothing_raised { client.validate_signature(@valid_body, @valid_signature) }
    assert_nothing_raised { client.parse_events_from(@valid_body) }
    assert_nothing_raised { client.reply_message("test_token", "test_message") }
  end

  test "fallback client should handle JSON parsing errors gracefully" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    # 無効なJSONをテスト
    invalid_json = "invalid json"
    events = client.parse_events_from(invalid_json)

    assert_equal [], events, "Should return empty array for invalid JSON"
  end

  test "fallback client should create proper event objects" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    events = client.parse_events_from(@valid_body)
    event = events.first

    # イベントオブジェクトが正しい値を返すことを確認
    assert_not_nil event.type
    assert_not_nil event.message
    assert_not_nil event.source
    assert_not_nil event.replyToken

    # 値が正しく設定されていることを確認
    assert_equal "message", event.type
    assert_equal "ヘルプ", event.message["text"]
    assert_equal "test_user_id", event.source["userId"]
    assert_equal "test_reply_token", event.replyToken
  end
end
