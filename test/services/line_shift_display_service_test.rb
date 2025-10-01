# frozen_string_literal: true

require "test_helper"

class LineShiftDisplayServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineShiftDisplayService.new
    @line_user_id = "test_user_123"
    @employee = employees(:employee1)
    @employee.update!(line_id: @line_user_id)
  end

  # ===== 正常系テスト =====

  test "LineShiftDisplayServiceの正常な初期化" do
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


  # ===== 異常系テスト =====

  test "未認証ユーザーの処理" do
    @employee.update!(line_id: nil)
    event = mock_event(@line_user_id, "シフト確認")
    result = @service.handle_shift_command(event)

    assert_not_nil result
    assert result.include?("認証が必要です")
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
