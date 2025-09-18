# frozen_string_literal: true

require "test_helper"

class ClockReminderMailerTest < ActionMailer::TestCase
  test "出勤打刻リマインダーメール" do
    email = ClockReminderMailer.clock_in_reminder(
      "test@example.com",
      "テスト従業員",
      "09:00～18:00"
    )

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["test@example.com"], email.to
    assert_equal "出勤打刻のお知らせ", email.subject
    assert_includes email.body.to_s, "テスト従業員"
    assert_includes email.body.to_s, "09:00～18:00"
  end

  test "退勤打刻リマインダーメール" do
    email = ClockReminderMailer.clock_out_reminder(
      "test@example.com",
      "テスト従業員",
      "09:00～18:00",
      18
    )

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["test@example.com"], email.to
    assert_equal "退勤打刻のお知らせ", email.subject
    assert_includes email.body.to_s, "テスト従業員"
    assert_includes email.body.to_s, "09:00～18:00"
    assert_includes email.body.to_s, "18:00"
  end
end
