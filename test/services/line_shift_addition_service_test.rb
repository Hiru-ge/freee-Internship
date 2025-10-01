# frozen_string_literal: true

require "test_helper"

class LineShiftAdditionServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineShiftAdditionService.new
    @line_user_id = "test_user_123"
    @employee = employees(:employee1)
    @employee.update!(line_id: @line_user_id)
  end

  # ===== 正常系テスト =====

  test "LineShiftAdditionServiceの正常な初期化" do
    assert_not_nil @service
  end

  test "オーナー権限でのシフト追加コマンドの処理" do
    @employee.update!(role: "owner")
    event = mock_event(@line_user_id, "追加依頼")
    result = @service.handle_shift_addition_command(event)

    assert_not_nil result
    assert result.include?("シフト追加を開始します")
  end

  test "シフト追加日付入力の処理" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    result = @service.handle_shift_addition_date_input(@line_user_id, tomorrow)

    assert_not_nil result
    assert result.include?("シフトの時間を入力してください")
  end

  test "シフト追加時間入力の処理" do
    state = { "selected_date" => (Date.current + 1).strftime("%m/%d") }
    result = @service.handle_shift_addition_time_input(@line_user_id, "9:00-17:00", state)

    assert_not_nil result
  end

  test "シフト追加対象従業員入力の処理" do
    state = {
      "selected_date" => (Date.current + 1).strftime("%m/%d"),
      "start_time" => "09:00",
      "end_time" => "17:00"
    }
    result = @service.handle_shift_addition_employee_input(@line_user_id, "1", state)

    assert_not_nil result
  end

  test "シフト追加確認入力の処理（はい）" do
    state = {
      "selected_date" => (Date.current + 1).strftime("%m/%d"),
      "start_time" => "09:00",
      "end_time" => "17:00",
      "available_employees" => []
    }
    result = @service.handle_shift_addition_confirmation_input(@line_user_id, "はい", state)

    assert_not_nil result
  end

  test "シフト追加確認入力の処理（いいえ）" do
    state = {
      "selected_date" => (Date.current + 1).strftime("%m/%d"),
      "start_time" => "09:00",
      "end_time" => "17:00",
      "available_employees" => []
    }
    result = @service.handle_shift_addition_confirmation_input(@line_user_id, "いいえ", state)

    assert_not_nil result
    assert result.include?("キャンセルしました")
  end

  test "シフト追加承認Postbackの処理" do
    result = @service.handle_shift_addition_approval_postback(@line_user_id, "approve_addition_1", "approve")

    assert_not_nil result
  end

  test "シフト追加拒否Postbackの処理" do
    result = @service.handle_shift_addition_approval_postback(@line_user_id, "reject_addition_1", "reject")

    assert_not_nil result
  end


  # ===== 異常系テスト =====

  test "従業員権限でのシフト追加コマンドの処理" do
    @employee.update!(role: "employee")
    event = mock_event(@line_user_id, "追加依頼")
    result = @service.handle_shift_addition_command(event)

    assert_not_nil result
    assert result.include?("オーナーのみが利用可能")
  end

  test "未認証ユーザーの処理" do
    @employee.update!(line_id: nil)
    event = mock_event(@line_user_id, "追加依頼")
    result = @service.handle_shift_addition_command(event)

    assert_not_nil result
    assert result.include?("認証が必要です")
  end

  test "シフト追加時間入力の処理（失敗パターン）" do
    state = { "selected_date" => (Date.current + 1).strftime("%m/%d") }
    result = @service.handle_shift_addition_time_input(@line_user_id, "invalid_time", state)

    assert_not_nil result
    assert result.include?("正しい時間形式")
  end

  test "シフト追加確認入力の処理（失敗パターン）" do
    state = {
      "selected_date" => (Date.current + 1).strftime("%m/%d"),
      "start_time" => "09:00",
      "end_time" => "17:00",
      "available_employees" => []
    }
    result = @service.handle_shift_addition_confirmation_input(@line_user_id, "maybe", state)

    assert_not_nil result
    assert result.include?("「はい」または「いいえ」")
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
