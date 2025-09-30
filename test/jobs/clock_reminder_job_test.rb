# frozen_string_literal: true

require "test_helper"

class ClockReminderJobTest < ActiveJob::TestCase
  def setup
    @employee = Employee.create!(
      employee_id: "test_employee_001",
      role: "employee"
    )
  end

  test "出勤打刻忘れチェックジョブ（成功パターン）" do
    assert_nothing_raised do
      ClockReminderJob.perform_now("clock_in")
    end
  end

  test "退勤打刻忘れチェックジョブ（成功パターン）" do
    assert_nothing_raised do
      ClockReminderJob.perform_now("clock_out")
    end
  end

  test "無効なリマインダータイプ（失敗パターン）" do
    assert_nothing_raised do
      ClockReminderJob.perform_now("invalid_type")
    end
  end

  test "ジョブの非同期実行" do
    assert_enqueued_with(job: ClockReminderJob, args: ["clock_in"]) do
      ClockReminderJob.perform_later("clock_in")
    end
  end
end
