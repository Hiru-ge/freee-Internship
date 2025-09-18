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
    @line_message_log.line_user_id = nil
    assert_not @line_message_log.valid?
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
    @line_message_log.save!
    inbound_log = LineMessageLog.inbound.first
    assert_equal "inbound", inbound_log.direction
  end

  test "should have outbound scope" do
    @line_message_log.direction = "outbound"
    @line_message_log.save!
    outbound_log = LineMessageLog.outbound.first
    assert_equal "outbound", outbound_log.direction
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
