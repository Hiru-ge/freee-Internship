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

  test "should be valid with valid attributes" do
    assert @line_message_log.valid?
  end

  test "should require line_user_id" do
    # line_user_idなしで作成を試行
    @line_message_log.line_user_id = nil
    assert_not @line_message_log.valid?, "line_user_idなしでは無効であるべき"
    assert_includes @line_message_log.errors[:line_user_id], "can't be blank"

    # line_user_idありで作成
    @line_message_log.line_user_id = "test_user"
    assert @line_message_log.valid?, "line_user_idありでは有効であるべき"

    # 実際に保存できることを確認
    assert @line_message_log.save, "有効なデータは保存できるべき"
    @line_message_log.destroy
  end

  test "should require message_type" do
    @line_message_log.message_type = nil
    assert_not @line_message_log.valid?
  end

  test "should require direction" do
    @line_message_log.direction = nil
    assert_not @line_message_log.valid?
  end

  test "should validate message_type inclusion" do
    @line_message_log.message_type = "invalid_type"
    assert_not @line_message_log.valid?
  end

  test "should validate direction inclusion" do
    @line_message_log.direction = "invalid_direction"
    assert_not @line_message_log.valid?
  end

  test "should allow nil message_content" do
    @line_message_log.message_content = nil
    assert @line_message_log.valid?
  end

  test "should have inbound scope" do
    # テスト用のログデータを作成
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

    # inboundスコープが正しく動作することを確認
    inbound_logs = LineMessageLog.inbound
    assert_includes inbound_logs, inbound_log
    assert_not_includes inbound_logs, outbound_log

    # クリーンアップ
    inbound_log.destroy
    outbound_log.destroy
  end

  test "should have outbound scope" do
    # テスト用のログデータを作成
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

    # outboundスコープが正しく動作することを確認
    outbound_logs = LineMessageLog.outbound
    assert_includes outbound_logs, outbound_log
    assert_not_includes outbound_logs, inbound_log

    # クリーンアップ
    inbound_log.destroy
    outbound_log.destroy
  end

  test "should log inbound message" do
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

  test "should log outbound message" do
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
end
