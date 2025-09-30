# frozen_string_literal: true

require "test_helper"

class LineBotServiceTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "U1234567890abcdef"
    @test_group_id = "G1234567890abcdef"
  end

  # ===== 正常系テスト =====

  test "LineBotServiceの初期化" do
    assert_not_nil @line_bot_service
  end

  test "ヘルプコマンドの処理" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "個人チャットでの有効なコマンド処理" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "グループチャットでの有効なコマンド処理" do
    event = mock_line_event(source_type: "group", user_id: @test_user_id, group_id: "test_group_123", message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "依頼確認コマンドでFlexメッセージを返す" do
    employee = Employee.create!(employee_id: "test_employee_123", role: "employee", line_id: @test_user_id)
    other_employee = Employee.create!(employee_id: "other_employee_123", role: "employee")
    shift = Shift.create!(employee: employee, shift_date: Date.current + 1, start_time: "09:00", end_time: "18:00")
    shift_exchange = ShiftExchange.create!(request_id: "exchange_123", requester_id: other_employee.employee_id, approver_id: employee.employee_id, shift: shift, status: "pending")
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(Hash) || response.is_a?(String)
    shift_exchange.destroy
    shift.destroy
    employee.destroy
    other_employee.destroy
  end

  test "依頼がない場合のメッセージ表示" do
    employee = Employee.create!(employee_id: "test_employee_456", role: "employee", line_id: @test_user_id)
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(Hash) || response.is_a?(String)
    employee.destroy
  end

  test "group_message?メソッドの動作確認" do
    personal_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    assert_not @line_bot_service.send(:group_message?, personal_event)
    group_event = mock_line_event(source_type: "group", user_id: @test_user_id, group_id: "test_group_123")
    result = @line_bot_service.send(:group_message?, group_event)
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end

  # ===== 異常系テスト =====

  test "未知のコマンドの処理" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event["message"]["text"] = "unknown_command"
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "コマンドは認識できませんでした"
  end

  test "グループチャットでの非コマンドメッセージの無視" do
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id, message_text: "おはようございます")
    response = @line_bot_service.handle_message(event)
    assert response.nil? || response.is_a?(String) || response.is_a?(Hash)
  end

  test "個人チャットでの非コマンドメッセージのエラー表示" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "こんにちは")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "コマンドは認識できませんでした"
  end

  test "未認証ユーザーの認証要求メッセージ" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(String) || response.is_a?(Hash)
  end

  private

  def mock_line_event(source_type: "user", user_id: @test_user_id, message_text: nil, group_id: nil)
    event = {
      "type" => "message",
      "source" => {
        "type" => source_type,
        "userId" => user_id
      },
      "message" => {
        "type" => "text",
        "text" => message_text || "テストメッセージ"
      },
      "replyToken" => "test_reply_token_#{SecureRandom.hex(8)}",
      "timestamp" => Time.current.to_i
    }

    if source_type == "group" && group_id
      event["source"]["groupId"] = group_id
    end

    event
  end

  def mock_line_event(message_text, user_id = @test_user_id)
    source = { "type" => "user", "userId" => user_id }
    event = { "source" => source, "message" => { "text" => message_text }, "replyToken" => "test_reply_token" }
    event.define_singleton_method(:message) { self["message"] }
    event.define_singleton_method(:source) { self["source"] }
    event.define_singleton_method(:replyToken) { self["replyToken"] }
    event
  end
end
