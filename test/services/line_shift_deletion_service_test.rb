# frozen_string_literal: true

require "test_helper"

class LineShiftDeletionServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineShiftDeletionService.new
    @line_user_id = "test_user_123"
    @employee = employees(:employee1)
    @employee.update!(line_id: @line_user_id)
  end

  # ===== 正常系テスト =====

  test "LineShiftDeletionServiceの正常な初期化" do
    assert_not_nil @service
  end

  test "欠勤申請コマンドの処理" do
    event = mock_event(@line_user_id, "欠勤申請")
    result = @service.handle_shift_deletion_command(event)

    assert_not_nil result
    assert result.include?("欠勤申請")
  end

  test "欠勤申請日付入力の処理" do
    tomorrow = (Date.current + 1).strftime("%m/%d")
    state = {}
    result = @service.handle_shift_deletion_date_input(@line_user_id, tomorrow, state)

    assert_not_nil result
  end

  test "欠勤理由入力の処理" do
    state = { "shift_id" => "1" }
    result = @service.handle_shift_deletion_reason_input(@line_user_id, "体調不良", state)

    assert_not_nil result
  end

  test "シフト選択のPostback処理" do
    result = @service.handle_deletion_shift_selection(@line_user_id, "deletion_shift_1")

    assert_not_nil result
    assert result.include?("欠勤理由を入力してください") || result.include?("シフトが見つかりません")
  end

  test "オーナー権限での欠勤申請承認Postbackの処理" do
    @employee.update!(role: "owner")
    result = @service.handle_deletion_approval_postback(@line_user_id, "approve_deletion_1", "approve")

    assert_not_nil result
  end

  test "オーナー権限での欠勤申請拒否Postbackの処理" do
    @employee.update!(role: "owner")
    result = @service.handle_deletion_approval_postback(@line_user_id, "reject_deletion_1", "reject")

    assert_not_nil result
  end

  # ===== 異常系テスト =====

  test "未認証ユーザーの処理" do
    @employee.update!(line_id: nil)
    event = mock_event(@line_user_id, "欠勤申請")
    result = @service.handle_shift_deletion_command(event)

    assert_not_nil result
    assert result.include?("認証が必要です")
  end

  test "欠勤申請日付入力の処理（過去の日付）" do
    yesterday = (Date.current - 1).strftime("%m/%d")
    state = {}
    result = @service.handle_shift_deletion_date_input(@line_user_id, yesterday, state)

    assert_not_nil result
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

  test "欠勤理由入力の処理（失敗パターン）" do
    state = { "shift_id" => "1" }
    result = @service.handle_shift_deletion_reason_input(@line_user_id, "", state)

    assert_not_nil result
    assert result.include?("欠勤理由を入力してください")
  end

  test "シフト選択のPostback処理（失敗パターン）" do
    result = @service.handle_deletion_shift_selection(@line_user_id, "invalid_postback")

    assert_not_nil result
    assert result.include?("シフトを選択してください")
  end

  test "従業員権限での欠勤申請承認Postbackの処理" do
    @employee.update!(role: "employee")
    result = @service.handle_deletion_approval_postback(@line_user_id, "approve_deletion_1", "approve")

    assert_not_nil result
    assert result.include?("権限がありません") || result.include?("申請が見つかりません")
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
