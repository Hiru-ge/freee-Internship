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

  # ===== 正常系テスト =====

  test "フォールバッククライアントのイベント解析" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    events = client.parse_events_from(@valid_body)

    assert_equal 1, events.length
    assert_equal "message", events.first.type
    assert_equal "ヘルプ", events.first.message["text"]
  end

  test "フォールバッククライアントの署名検証" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    result = client.validate_signature(@valid_body, @valid_signature)

    assert result, "Signature validation should pass in fallback client"
  end

  test "フォールバッククライアントの必須メソッド存在確認" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    assert_nothing_raised { client.validate_signature(@valid_body, @valid_signature) }
    assert_nothing_raised { client.parse_events_from(@valid_body) }
    assert_nothing_raised { client.reply_message("test_token", "test_message") }
  end

  test "モッククライアントの必須メソッド存在確認" do
    controller = WebhookController.new
    client = controller.send(:mock_client)

    assert_nothing_raised { client.validate_signature(@valid_body, @valid_signature) }
    assert_nothing_raised { client.parse_events_from(@valid_body) }
    assert_nothing_raised { client.reply_message("test_token", "test_message") }
  end

  test "フォールバッククライアントの正しいイベントオブジェクト作成" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    events = client.parse_events_from(@valid_body)
    event = events.first

    assert_not_nil event.type
    assert_not_nil event.message
    assert_not_nil event.source
    assert_not_nil event.replyToken

    assert_equal "message", event.type
    assert_equal "ヘルプ", event.message["text"]
    assert_equal "test_user_id", event.source["userId"]
    assert_equal "test_reply_token", event.replyToken
  end

  # ===== 異常系テスト =====

  test "フォールバッククライアントのJSON解析エラーの適切な処理" do
    ENV["LINE_CHANNEL_SECRET"] = "test_secret"
    ENV["LINE_CHANNEL_TOKEN"] = "test_token"

    controller = WebhookController.new
    client = controller.send(:fallback_client)

    invalid_json = "invalid json"
    events = client.parse_events_from(invalid_json)

    assert_equal [], events, "Should return empty array for invalid JSON"
  end
end
