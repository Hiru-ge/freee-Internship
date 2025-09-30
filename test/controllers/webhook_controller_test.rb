# frozen_string_literal: true

require "test_helper"

class WebhookControllerTest < ActionDispatch::IntegrationTest
  def setup
    @line_channel_secret = "test_channel_secret"
    @line_channel_token = "test_channel_token"

    # 環境変数の設定
    ENV["LINE_CHANNEL_SECRET"] = @line_channel_secret
    ENV["LINE_CHANNEL_TOKEN"] = @line_channel_token
  end

  def teardown
    # 環境変数のクリーンアップ
    ENV.delete("LINE_CHANNEL_SECRET")
    ENV.delete("LINE_CHANNEL_TOKEN")
  end

  # ===== 正常系テスト =====

  test "Webhookコールバックの受信" do
    post webhook_callback_path,
         params: webhook_payload,
         headers: webhook_headers

    assert_response :ok
  end

  test "テキストメッセージイベントの処理" do
    post webhook_callback_path,
         params: text_message_payload,
         headers: webhook_headers

    assert_response :ok
  end

  test "グループと個人メッセージの識別" do
    post webhook_callback_path,
         params: group_message_payload,
         headers: webhook_headers

    assert_response :ok

    post webhook_callback_path,
         params: individual_message_payload,
         headers: webhook_headers

    assert_response :ok
  end

  private

  def webhook_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "テストメッセージ"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def text_message_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "ヘルプ"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def group_message_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "グループメッセージ"
          },
          source: {
            type: "group",
            groupId: "test_group_id",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def individual_message_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "個人メッセージ"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def help_command_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "ヘルプ"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def auth_command_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "認証"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def shift_command_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "シフト"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def unknown_command_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "未知のコマンド"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token"
        }
      ]
    }.to_json
  end

  def multiple_events_payload
    {
      events: [
        {
          type: "message",
          message: {
            type: "text",
            text: "ヘルプ"
          },
          source: {
            type: "user",
            userId: "test_user_id"
          },
          replyToken: "test_reply_token_1"
        },
        {
          type: "message",
          message: {
            type: "text",
            text: "シフト"
          },
          source: {
            type: "user",
            userId: "test_user_id_2"
          },
          replyToken: "test_reply_token_2"
        }
      ]
    }.to_json
  end

  def webhook_headers
    {
      "Content-Type" => "application/json",
      "X-Line-Signature" => generate_signature(webhook_payload)
    }
  end

  def invalid_signature_headers
    {
      "Content-Type" => "application/json",
      "X-Line-Signature" => "invalid_signature"
    }
  end

  def generate_signature(body)
    # テスト用の署名生成（実際のLINE APIの署名生成ロジックを模擬）
    require "openssl"
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), @line_channel_secret, body)
  end
end
