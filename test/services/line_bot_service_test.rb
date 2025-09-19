# frozen_string_literal: true

require "test_helper"

class LineBotServiceTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "U1234567890abcdef"
    @test_group_id = "G1234567890abcdef"
  end

  test "should initialize LineBotService" do
    assert_not_nil @line_bot_service
  end

  test "should handle help command" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "should handle unknown command" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event["message"]["text"] = "unknown_command"
    response = @line_bot_service.handle_message(event)
    assert_not_nil response, "未知のコマンドにはエラーメッセージが返されるべき"
    assert_includes response, "コマンドは認識できませんでした"
  end

  test "should ignore non-command messages in group chat" do
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id, message_text: "おはようございます")
    response = @line_bot_service.handle_message(event)
    assert_nil response, "グループチャットでコマンド以外のメッセージは無視されるべき"
  end

  test "should return error message for non-command in individual chat" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "こんにちは")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response, "個人チャットでコマンド以外のメッセージにはエラーメッセージが返されるべき"
    assert_includes response, "コマンドは認識できませんでした"
  end

  test "should handle valid command in personal chat" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "should handle valid command in group chat" do
    event = mock_line_event(source_type: "group", user_id: @test_user_id, group_id: "test_group_123", message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "should handle group_message? method correctly" do
    personal_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    assert_not @line_bot_service.send(:group_message?, personal_event), "個人チャットはgroup_message?でfalseが返されるべき"
    group_event = mock_line_event(source_type: "group", user_id: @test_user_id, group_id: "test_group_123")
    assert @line_bot_service.send(:group_message?, group_event), "グループチャットはgroup_message?でtrueが返されるべき"
  end

  test "should return flex message for request check command" do
    employee = Employee.create!(employee_id: "test_employee_123", role: "employee", line_id: @test_user_id)
    other_employee = Employee.create!(employee_id: "other_employee_123", role: "employee")
    shift = Shift.create!(employee: employee, shift_date: Date.current + 1, start_time: "09:00", end_time: "18:00")
    shift_exchange = ShiftExchange.create!(request_id: "exchange_123", requester_id: other_employee.employee_id, approver_id: employee.employee_id, shift: shift, status: "pending")
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(Hash)
    assert_equal "flex", response[:type]
    assert_equal "承認待ちの依頼", response[:altText]
    assert response[:contents].is_a?(Hash)
    assert response[:contents][:contents].is_a?(Array)
    shift_exchange.destroy
    shift.destroy
    employee.destroy
    other_employee.destroy
  end

  test "should return no pending requests message when no requests exist" do
    employee = Employee.create!(employee_id: "test_employee_456", role: "employee", line_id: @test_user_id)
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    # Flex Messageが返される場合とテキストメッセージが返される場合がある
    if response.is_a?(Hash)
      assert_equal "text", response[:type]
      assert_includes response[:text], "承認待ちの依頼はありません"
    else
      assert_includes response, "承認待ちの依頼はありません"
    end
    employee.destroy
  end

  test "should return authentication required message for unauthenticated user" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert_includes response, "認証が必要です"
    assert_includes response, "認証"
  end

  private

  def mock_line_event(source_type:, user_id:, group_id: nil, message_text: "テストメッセージ")
    source = { "type" => source_type, "userId" => user_id }
    source["groupId"] = group_id if group_id
    event = { "source" => source, "message" => { "text" => message_text }, "replyToken" => "test_reply_token" }
    event.define_singleton_method(:message) { self["message"] }
    event.define_singleton_method(:source) { self["source"] }
    event.define_singleton_method(:replyToken) { self["replyToken"] }
    event
  end
end
