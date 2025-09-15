require "test_helper"

class LineBotServiceTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_id"
    @test_group_id = "test_group_id"
  end

  test "should identify group message source" do
    # グループメッセージの識別テスト
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    
    assert @line_bot_service.group_message?(event)
    assert_not @line_bot_service.individual_message?(event)
  end

  test "should identify individual message source" do
    # 個人メッセージの識別テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    
    assert_not @line_bot_service.group_message?(event)
    assert @line_bot_service.individual_message?(event)
  end

  test "should generate help message" do
    # ヘルプメッセージの生成テスト
    message = @line_bot_service.generate_help_message
    
    assert_includes message, "勤怠管理システムへようこそ"
    assert_includes message, "ヘルプ"
    assert_includes message, "認証"
    assert_includes message, "シフト"
    assert_includes message, "勤怠"
  end

  test "should handle help command" do
    # ヘルプコマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'ヘルプ'
    
    response = @line_bot_service.handle_message(event)
    
    assert_includes response, "勤怠管理システムへようこそ"
  end

  test "should handle unknown command" do
    # 未知のコマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'unknown_command'
    
    response = @line_bot_service.handle_message(event)
    
    assert_includes response, "申し訳ございませんが"
  end

  private

  def mock_line_event(source_type:, user_id:, group_id: nil)
    source = { 'type' => source_type, 'userId' => user_id }
    source['groupId'] = group_id if group_id
    
    event = {
      'source' => source,
      'message' => { 'text' => 'テストメッセージ' },
      'replyToken' => 'test_reply_token'
    }
    
    # LINE Bot SDKのイベントオブジェクトのように動作するように拡張
    event.define_singleton_method(:message) { self['message'] }
    event.define_singleton_method(:source) { self['source'] }
    event.define_singleton_method(:replyToken) { self['replyToken'] }
    
    event
  end
end
