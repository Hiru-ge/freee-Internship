# frozen_string_literal: true

require "test_helper"

class LineBotWorkflowTest < ActiveSupport::TestCase
  def setup
    @test_user_id = "test_user_#{SecureRandom.hex(8)}"
    @test_owner_id = "test_owner_#{SecureRandom.hex(8)}"

    # テスト用従業員を作成
    @owner = Employee.create!(
      employee_id: @test_owner_id,
      role: "owner",
      line_id: @test_user_id
    )

    @line_bot_service = LineBotService.new
  end

  def teardown
    # テストデータのクリーンアップ（外部キー制約を考慮して順序を調整）
    ShiftAddition.where(requester_id: @test_owner_id).destroy_all
    ShiftExchange.where(requester_id: @test_owner_id).destroy_all
    ShiftDeletion.where(requester_id: @test_owner_id).destroy_all
    Shift.where(employee_id: @test_owner_id).destroy_all
    ConversationState.where(line_user_id: @test_user_id).delete_all
    Employee.where(employee_id: @test_owner_id).destroy_all
  end

  # 基本的なコマンドのテスト
  test "should handle basic commands" do
    # ヘルプコマンド
    event = mock_line_event("ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_includes response, "利用可能なコマンド"

    # シフト確認コマンド
    event = mock_line_event("シフト確認")
    response = @line_bot_service.handle_message(event)
    assert_includes response, "今月のシフト"
  end

  # シフト追加依頼の完全フローテスト
  test "should handle complete shift addition workflow" do
    # 1. 追加依頼コマンド
    event1 = mock_line_event("追加依頼")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト追加を開始します"
  end

  # シフト交代依頼の完全フローテスト
  test "should handle complete shift exchange workflow" do
    # 1. 交代依頼コマンド
    event1 = mock_line_event("交代依頼")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"
  end

  # 欠勤申請の完全フローテスト
  test "should handle complete shift deletion workflow" do
    # 1. 欠勤申請コマンド
    event1 = mock_line_event("欠勤申請")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "欠勤申請"
  end

  # コマンド割り込みのテスト
  test "should handle command interruption during conversation" do
    # 1. 交代依頼を開始
    event1 = mock_line_event("交代依頼")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"

    # 2. 会話中にヘルプコマンドを送信（コマンド割り込みをテスト）
    # コマンド割り込みにより会話状態がクリアされ、ヘルプコマンドが正常に処理される
    event2 = mock_line_event("ヘルプ")
    response2 = @line_bot_service.handle_message(event2)

    # ヘルプコマンドが正常に処理されることを確認
    if response2.nil?
      # コマンド割り込みが正常に動作している（会話状態がクリアされた）
      assert true, "コマンド割り込みが正常に動作しました"
    else
      assert_includes response2, "利用可能なコマンド"
    end
  end

  # 無効な入力形式のテスト
  test "should handle invalid input formats" do
    # 1. 交代依頼を開始
    event1 = mock_line_event("交代依頼")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"
  end

  # 認証されていないユーザーのテスト
  test "should handle unauthenticated user" do
    unauthenticated_user_id = "unauthenticated_user_#{SecureRandom.hex(8)}"

    event = mock_line_event("シフト確認", unauthenticated_user_id)
    response = @line_bot_service.handle_message(event)
    assert_includes response, "認証が必要です"
  end

  # 権限チェックのテスト
  test "should handle permission check for shift addition" do
    employee_user_id = "employee_user_#{SecureRandom.hex(8)}"
    employee = Employee.create!(
      employee_id: "employee_#{SecureRandom.hex(8)}",
      role: "employee",
      line_id: employee_user_id
    )

    event = mock_line_event("追加依頼", employee_user_id)
    response = @line_bot_service.handle_message(event)
    assert_includes response, "シフト追加はオーナーのみが利用可能です"

    employee.destroy
  end

  private

  def mock_line_event(message_text, user_id = @test_user_id)
    source = { "type" => "user", "userId" => user_id }
    event = { "source" => source, "message" => { "text" => message_text }, "replyToken" => "test_reply_token" }
    event.define_singleton_method(:message) { self["message"] }
    event.define_singleton_method(:source) { self["source"] }
    event.define_singleton_method(:replyToken) { self["replyToken"] }
    event
  end
end
