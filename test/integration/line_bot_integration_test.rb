require "test_helper"

class LineBotIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @line_channel_secret = "test_channel_secret"
    @line_channel_token = "test_channel_token"
    
    # 環境変数の設定
    ENV['LINE_CHANNEL_SECRET'] = @line_channel_secret
    ENV['LINE_CHANNEL_TOKEN'] = @line_channel_token
  end

  def teardown
    # 環境変数のクリーンアップ
    ENV.delete('LINE_CHANNEL_SECRET')
    ENV.delete('LINE_CHANNEL_TOKEN')
  end

  test "should handle complete webhook flow" do
    # 完全なWebhookフローのテスト
    payload = {
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

    post webhook_callback_path,
         params: payload,
         headers: webhook_headers(payload)
    
    assert_response :ok
  end

  private

  def webhook_headers(payload)
    {
      'Content-Type' => 'application/json',
      'X-Line-Signature' => generate_signature(payload)
    }
  end

  def invalid_signature_headers
    {
      'Content-Type' => 'application/json',
      'X-Line-Signature' => 'invalid_signature'
    }
  end

  def generate_signature(body)
    # テスト用の署名生成（実際のLINE APIの署名生成ロジックを模擬）
    require 'openssl'
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @line_channel_secret, body)
  end
end
