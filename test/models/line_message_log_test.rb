# frozen_string_literal: true

require "test_helper"

class LineMessageLogTest < ActiveSupport::TestCase
  def setup
    @line_message_log = LineMessageLog.new(
      line_user_id: "U1234567890abcdef",
      message_type: "text",
      message_content: "Hello, World!",
      direction: "inbound"
    )
  end

  # ===== 正常系テスト =====

  test "有効な属性でのバリデーション成功" do
    assert @line_message_log.valid?
  end

  test "受信メッセージのログ記録" do
    line_user_id = "U1234567890abcdef"
    message_type = "text"
    content = "Test message"

    log = LineMessageLog.log_inbound_message(line_user_id, message_type, content)

    assert_equal line_user_id, log.line_user_id
    assert_equal message_type, log.message_type
    assert_equal content, log.message_content
    assert_equal "inbound", log.direction
    assert_not_nil log.processed_at
  end

  test "送信メッセージのログ記録" do
    line_user_id = "U1234567890abcdef"
    message_type = "text"
    content = "Test reply"

    log = LineMessageLog.log_outbound_message(line_user_id, message_type, content)

    assert_equal line_user_id, log.line_user_id
    assert_equal message_type, log.message_type
    assert_equal content, log.message_content
    assert_equal "outbound", log.direction
    assert_not_nil log.processed_at
  end

  test "受信メッセージスコープの動作" do
    inbound_log = LineMessageLog.create!(
      line_user_id: "test_user",
      message_type: "text",
      direction: "inbound",
      message_content: "テストメッセージ"
    )
    outbound_log = LineMessageLog.create!(
      line_user_id: "test_user",
      message_type: "text",
      direction: "outbound",
      message_content: "返信メッセージ"
    )

    inbound_logs = LineMessageLog.inbound
    assert_includes inbound_logs, inbound_log
    assert_not_includes inbound_logs, outbound_log

    inbound_log.destroy
    outbound_log.destroy
  end

  test "送信メッセージスコープの動作" do
    inbound_log = LineMessageLog.create!(
      line_user_id: "test_user",
      message_type: "text",
      direction: "inbound",
      message_content: "テストメッセージ"
    )
    outbound_log = LineMessageLog.create!(
      line_user_id: "test_user",
      message_type: "text",
      direction: "outbound",
      message_content: "返信メッセージ"
    )

    outbound_logs = LineMessageLog.outbound
    assert_includes outbound_logs, outbound_log
    assert_not_includes outbound_logs, inbound_log

    inbound_log.destroy
    outbound_log.destroy
  end

  test "nilメッセージコンテンツの許可" do
    @line_message_log.message_content = nil
    assert @line_message_log.valid?
  end

  test "有効なline_user_idでの保存成功" do
    @line_message_log.line_user_id = "test_user"
    assert @line_message_log.valid?
    assert @line_message_log.save
    @line_message_log.destroy
  end

  # ===== 異常系テスト =====

  test "line_user_id必須バリデーション" do
    @line_message_log.line_user_id = nil
    assert_not @line_message_log.valid?
    assert_includes @line_message_log.errors[:line_user_id], "can't be blank"
  end

  test "message_type必須バリデーション" do
    @line_message_log.message_type = nil
    assert_not @line_message_log.valid?
  end

  test "direction必須バリデーション" do
    @line_message_log.direction = nil
    assert_not @line_message_log.valid?
  end

  test "message_type包含バリデーション" do
    @line_message_log.message_type = "invalid_type"
    assert_not @line_message_log.valid?
  end

  test "direction包含バリデーション" do
    @line_message_log.direction = "invalid_direction"
    assert_not @line_message_log.valid?
  end
end
