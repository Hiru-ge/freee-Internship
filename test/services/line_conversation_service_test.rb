# frozen_string_literal: true

require "test_helper"

class LineConversationServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineConversationService.new
    @line_user_id = "test_line_id"
    @employee = employees(:employee1)
  end

  test "should set and get conversation state" do
    state = { "step" => "waiting_shift_selection" }

    # 状態を設定
    result = @service.set_conversation_state(@line_user_id, state)
    assert result, "状態の設定に失敗しました"

    # 状態を取得
    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_not_nil retrieved_state, "状態の取得に失敗しました"
    assert_equal "waiting_shift_selection", retrieved_state["step"]

    # クリーンアップ
    @service.clear_conversation_state(@line_user_id)
  end

  test "should clear conversation state" do
    state = { "step" => "waiting_shift_selection" }

    # 状態を設定
    @service.set_conversation_state(@line_user_id, state)

    # 状態をクリア
    result = @service.clear_conversation_state(@line_user_id)
    assert result

    # 状態がクリアされていることを確認
    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_nil retrieved_state
  end

  test "should handle stateful message for shift deletion selection" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 状態を設定
    state = { "step" => "waiting_shift_selection" }
    @service.set_conversation_state(@line_user_id, state)

    # 状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "shift_selection", state)

    # 結果が返されることを確認（Flex Messageまたはエラーメッセージ）
    assert_not_nil result

    # クリーンアップ
    future_shift.destroy
    @service.clear_conversation_state(@line_user_id)
  end

  test "should handle stateful message for deletion reason input" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 状態を設定
    state = { "step" => "waiting_deletion_reason", "shift_id" => future_shift.id }
    @service.set_conversation_state(@line_user_id, state)

    # 状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "体調不良のため", state)

    # 申請が作成されることを確認
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:message)

    # クリーンアップ
    future_shift.destroy
    @service.clear_conversation_state(@line_user_id)
  end

  test "should handle stateful message for empty deletion reason" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 状態を設定
    state = { "step" => "waiting_deletion_reason", "shift_id" => future_shift.id }
    @service.set_conversation_state(@line_user_id, state)

    # 空の理由で状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "", state)

    # エラーメッセージが返されることを確認
    assert_includes result, "理由を入力してください"

    # クリーンアップ
    future_shift.destroy
    @service.clear_conversation_state(@line_user_id)
  end

  test "should handle unknown state" do
    # 不明な状態を設定
    state = { "step" => "unknown_state" }
    @service.set_conversation_state(@line_user_id, state)

    # 状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "test_message", state)

    # エラーメッセージが返されることを確認
    assert_includes result, "不明な状態です"

    # 状態がクリアされていることを確認
    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_nil retrieved_state
  end

  test "should handle message with state for existing conversation" do
    # 状態を設定
    state = { "step" => "waiting_shift_selection" }
    result = @service.set_conversation_state(@line_user_id, state)
    assert result, "状態の設定に失敗しました"

    # LineShiftDeletionServiceをモック
    deletion_service = Object.new
    def deletion_service.handle_shift_selection(line_user_id, message_text, state)
      "シフト選択処理が実行されました"
    end
    @service.instance_variable_set(:@deletion_service, deletion_service)

    # 状態付きメッセージを処理
    result = @service.handle_message_with_state(@line_user_id, "shift_selection")

    # 結果が返されることを確認
    assert_not_nil result, "状態付きメッセージの処理に失敗しました"
    assert_includes result, "シフト選択処理が実行されました"

    # クリーンアップ
    @service.clear_conversation_state(@line_user_id)
  end

  test "should return nil for message without state" do
    # 状態を設定しない

    # 状態付きメッセージを処理
    result = @service.handle_message_with_state(@line_user_id, "test_message")

    # nilが返されることを確認
    assert_nil result
  end

  test "should handle authentication stateful messages" do
    # 認証状態を設定
    state = { "step" => "waiting_for_employee_name" }
    @service.set_conversation_state(@line_user_id, state)

    # 状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "田中太郎", state)

    # 結果が返されることを確認
    assert_not_nil result

    # クリーンアップ
    @service.clear_conversation_state(@line_user_id)
  end

  test "should handle shift exchange stateful messages" do
    # シフト交代状態を設定
    state = { "step" => "waiting_shift_date" }
    @service.set_conversation_state(@line_user_id, state)

    # 状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "2024-01-20", state)

    # 結果が返されることを確認
    assert_not_nil result

    # クリーンアップ
    @service.clear_conversation_state(@line_user_id)
  end

  test "should handle shift addition stateful messages" do
    # シフト追加状態を設定
    state = { "step" => "waiting_shift_addition_date" }
    @service.set_conversation_state(@line_user_id, state)

    # 状態付きメッセージを処理
    result = @service.handle_stateful_message(@line_user_id, "2024-01-20", state)

    # 結果が返されることを確認
    assert_not_nil result

    # クリーンアップ
    @service.clear_conversation_state(@line_user_id)
  end

  test "should handle error during state setting" do
    # 無効なline_user_idを設定（エラーを発生させる）
    invalid_user_id = nil

    # 状態設定でエラーが発生することを確認
    result = @service.set_conversation_state(invalid_user_id, { "step" => "test" })
    assert_not result
  end

  test "should handle error during state clearing" do
    # 状態を設定
    state = { step: "waiting_shift_selection" }
    @service.set_conversation_state(@line_user_id, state)

    # 状態クリアでエラーが発生しないことを確認
    result = @service.clear_conversation_state(@line_user_id)
    assert result
  end
end
