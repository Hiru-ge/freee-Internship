# frozen_string_literal: true

require "test_helper"

class LineShiftExchangeServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineShiftExchangeService.new
    @line_user_id = "test_user_123"
    @employee = employees(:employee1)
    @employee.update!(line_id: @line_user_id)
  end

  # ===== 正常系テスト =====

  test "LineShiftExchangeServiceの正常な初期化" do
    assert_not_nil @service
  end

  test "シフト交代コマンドの処理" do
    event = mock_event(@line_user_id, "交代依頼")
    result = @service.handle_shift_exchange_command(event)

    assert_not_nil result
    assert result.include?("シフト交代依頼")
  end

  test "シフト日付入力の処理" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    result = @service.handle_shift_date_input(@line_user_id, tomorrow)

    assert_not_nil result
  end

  test "シフト日付入力の成功パターン" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    result = @service.handle_shift_date_input(@line_user_id, tomorrow)

    assert_not_nil result
    assert result.is_a?(String)
  end

  test "シフト選択の処理" do
    state = {}
    result = @service.handle_shift_selection_input(@line_user_id, "test", state)

    assert_not_nil result
  end

  test "シフト選択のPostback処理" do
    result = @service.handle_shift_selection_input(@line_user_id, "shift_1", {})

    assert_not_nil result
  end

  test "承認Postbackの処理" do
    result = @service.handle_approval_postback(@line_user_id, "approve_1", "approve")

    assert_not_nil result
  end

  test "拒否Postbackの処理" do
    result = @service.handle_approval_postback(@line_user_id, "reject_1", "reject")

    assert_not_nil result
  end

  test "従業員選択入力の処理（番号選択）" do
    state = { "shift_id" => "1" }
    result = @service.handle_employee_selection_input_exchange(@line_user_id, "1", state)

    assert_not_nil result
  end

  test "従業員選択入力の処理（名前検索）" do
    state = { "shift_id" => "1" }
    result = @service.handle_employee_selection_input_exchange(@line_user_id, "テスト従業員", state)

    assert_not_nil result
  end

  test "確認入力の処理（はい）" do
    state = { "shift_id" => "1", "target_employee_id" => "1" }
    result = @service.handle_confirmation_input(@line_user_id, "はい", state)

    assert_not_nil result
  end

  test "確認入力の処理（いいえ）" do
    state = { "shift_id" => "1", "target_employee_id" => "1" }
    result = @service.handle_confirmation_input(@line_user_id, "いいえ", state)

    assert_not_nil result
    assert result.include?("キャンセルしました")
  end

  # ===== 異常系テスト =====

  test "未認証ユーザーの処理" do
    @employee.update!(line_id: nil)
    event = mock_event(@line_user_id, "交代依頼")
    result = @service.handle_shift_exchange_command(event)

    assert_not_nil result
    assert result.include?("認証が必要です")
  end

  test "シフト日付入力の処理（過去の日付）" do
    yesterday = (Date.current - 1).strftime("%m/%d")
    result = @service.handle_shift_date_input(@line_user_id, yesterday)

    assert_not_nil result
    assert result.include?("過去の日付")
  end

  test "シフト日付入力の処理（失敗パターン）" do
    result = @service.handle_shift_date_input(@line_user_id, "invalid_date")

    assert_not_nil result
    assert result.include?("日付の形式が正しくありません")
  end

  test "確認入力の処理（失敗パターン）" do
    state = { "shift_id" => "1", "target_employee_id" => "1" }
    result = @service.handle_confirmation_input(@line_user_id, "maybe", state)

    assert_not_nil result
    assert result.include?("「はい」または「いいえ」")
  end

  test "シフト選択入力の処理（失敗パターン）" do
    result = @service.handle_shift_selection_input(@line_user_id, "invalid_selection", {})

    assert_not_nil result
    assert result.include?("シフトを選択してください")
  end

  private

  def mock_event(line_user_id, message_text)
    event = Object.new
    event.define_singleton_method(:source) { { "type" => "user", "userId" => line_user_id } }
    event.define_singleton_method(:message) { { "text" => message_text } }
    event.define_singleton_method(:type) { "message" }
    event.define_singleton_method(:[]) { |key| send(key) }
    event
  end
end
