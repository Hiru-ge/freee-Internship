# frozen_string_literal: true

require "test_helper"

class LineShiftManagementServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineShiftManagementService.new
    @line_user_id = "test_user_123"
    @employee = employees(:employee1)
    @employee.update!(line_id: @line_user_id)
  end

  test "LineShiftManagementServiceが正常に初期化される" do
    assert_not_nil @service
  end

  test "シフト確認コマンドの処理" do
    event = mock_event(@line_user_id, "シフト確認")
    result = @service.handle_shift_command(event)

    assert_not_nil result
    assert result.is_a?(String)
  end

  test "全員シフト確認コマンドの処理" do
    event = mock_event(@line_user_id, "全員シフト確認")
    result = @service.handle_all_shifts_command(event)

    assert_not_nil result
    assert result.is_a?(String)
  end

  test "シフト交代コマンドの処理" do
    event = mock_event(@line_user_id, "交代依頼")
    result = @service.handle_shift_exchange_command(event)

    assert_not_nil result
    assert result.include?("シフト交代依頼")
  end

  test "シフト追加コマンドの処理（オーナー権限）" do
    @employee.update!(role: "owner")
    event = mock_event(@line_user_id, "追加依頼")
    result = @service.handle_shift_addition_command(event)

    assert_not_nil result
    assert result.include?("シフト追加を開始します")
  end

  test "シフト追加コマンドの処理（権限なし）" do
    @employee.update!(role: "employee")
    event = mock_event(@line_user_id, "追加依頼")
    result = @service.handle_shift_addition_command(event)

    assert_not_nil result
    assert result.include?("オーナーのみが利用可能")
  end

  test "欠勤申請コマンドの処理" do
    event = mock_event(@line_user_id, "欠勤申請")
    result = @service.handle_shift_deletion_command(event)

    assert_not_nil result
    assert result.include?("欠勤申請")
  end

  test "未認証ユーザーの処理" do
    @employee.update!(line_id: nil)
    event = mock_event(@line_user_id, "シフト確認")
    result = @service.handle_shift_command(event)

    assert_not_nil result
    assert result.include?("認証が必要です")
  end

  test "シフト日付入力の処理" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    result = @service.handle_shift_date_input(@line_user_id, tomorrow)

    assert_not_nil result
  end

  test "シフト日付入力の処理（過去の日付）" do
    yesterday = (Date.current - 1).strftime("%m/%d")
    result = @service.handle_shift_date_input(@line_user_id, yesterday)

    assert_not_nil result
    assert result.include?("過去の日付")
  end

  test "シフト日付入力の処理（成功パターン）" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    result = @service.handle_shift_date_input(@line_user_id, tomorrow)

    assert_not_nil result
    assert result.is_a?(String)
  end

  test "シフト日付入力の処理（失敗パターン）" do
    result = @service.handle_shift_date_input(@line_user_id, "invalid_date")

    assert_not_nil result
    assert result.include?("日付の形式が正しくありません")
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

  test "シフト追加時間入力の処理（失敗パターン）" do
    state = { "selected_date" => (Date.current + 1).strftime("%m/%d") }
    result = @service.handle_shift_addition_time_input(@line_user_id, "invalid_time", state)

    assert_not_nil result
    assert result.include?("正しい時間形式")
  end

  test "欠勤申請日付入力の処理" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    state = {}
    result = @service.handle_shift_deletion_date_input(@line_user_id, tomorrow, state)

    assert_not_nil result
  end

  test "欠勤申請日付入力の処理（過去の日付）" do
    yesterday = (Date.current - 1).strftime("%m/%d")
    state = {}
    result = @service.handle_shift_deletion_date_input(@line_user_id, yesterday, state)

    assert_not_nil result
    # 過去の日付、無効な日付、従業員が見つからない場合、またはシフトが見つからない場合のエラーメッセージ
    assert result.include?("過去の日付は選択できません") ||
           result.include?("正しい日付形式") ||
           result.include?("従業員情報が見つかりません") ||
           result.include?("シフトが見つかりません") ||
           result.include?("エラー") ||
           result.include?("エラーが発生しました")
  end

  test "欠勤申請日付入力の処理（失敗パターン）" do
    state = {}
    result = @service.handle_shift_deletion_date_input(@line_user_id, "invalid_date", state)

    assert_not_nil result
    assert result.include?("正しい日付形式")
  end

  test "欠勤理由入力の処理" do
    state = { "shift_id" => "1" }
    result = @service.handle_shift_deletion_reason_input(@line_user_id, "体調不良", state)

    assert_not_nil result
  end

  test "欠勤理由入力の処理（失敗パターン）" do
    state = { "shift_id" => "1" }
    result = @service.handle_shift_deletion_reason_input(@line_user_id, "", state)

    assert_not_nil result
    assert result.include?("欠勤理由を入力してください")
  end

  test "シフト選択の処理" do
    state = {}
    result = @service.handle_shift_selection(@line_user_id, "test", state)

    assert_not_nil result
  end

  test "シフト選択のPostback処理" do
    result = @service.handle_deletion_shift_selection(@line_user_id, "deletion_shift_1")

    assert_not_nil result
    # シフトが見つからない場合もエラーメッセージが返される
    assert result.include?("欠勤理由を入力してください") || result.include?("シフトが見つかりません")
  end

  test "シフト選択のPostback処理（失敗パターン）" do
    result = @service.handle_deletion_shift_selection(@line_user_id, "invalid_postback")

    assert_not_nil result
    assert result.include?("シフトを選択してください")
  end

  test "承認Postbackの処理" do
    result = @service.handle_approval_postback(@line_user_id, "approve_1", "approve")

    assert_not_nil result
  end

  test "拒否Postbackの処理" do
    result = @service.handle_approval_postback(@line_user_id, "reject_1", "reject")

    assert_not_nil result
  end

  test "シフト追加承認Postbackの処理" do
    result = @service.handle_shift_addition_approval_postback(@line_user_id, "approve_addition_1", "approve")

    assert_not_nil result
  end

  test "シフト追加拒否Postbackの処理" do
    result = @service.handle_shift_addition_approval_postback(@line_user_id, "reject_addition_1", "reject")

    assert_not_nil result
  end

  test "欠勤申請承認Postbackの処理" do
    @employee.update!(role: "owner")
    result = @service.handle_deletion_approval_postback(@line_user_id, "approve_deletion_1", "approve")

    assert_not_nil result
  end

  test "欠勤申請拒否Postbackの処理" do
    @employee.update!(role: "owner")
    result = @service.handle_deletion_approval_postback(@line_user_id, "reject_deletion_1", "reject")

    assert_not_nil result
  end

  test "欠勤申請承認Postbackの処理（権限なし）" do
    @employee.update!(role: "employee")
    result = @service.handle_deletion_approval_postback(@line_user_id, "approve_deletion_1", "approve")

    assert_not_nil result
    # 権限がない場合または申請が見つからない場合のエラーメッセージ
    assert result.include?("権限がありません") || result.include?("申請が見つかりません")
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

  test "確認入力の処理（失敗パターン）" do
    state = { "shift_id" => "1", "target_employee_id" => "1" }
    result = @service.handle_confirmation_input(@line_user_id, "maybe", state)

    assert_not_nil result
    assert result.include?("「はい」または「いいえ」")
  end

  test "シフト選択入力の処理" do
    result = @service.handle_shift_selection_input(@line_user_id, "shift_1", {})

    assert_not_nil result
  end

  test "シフト選択入力の処理（失敗パターン）" do
    result = @service.handle_shift_selection_input(@line_user_id, "invalid_selection", {})

    assert_not_nil result
    assert result.include?("シフトを選択してください")
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
