require 'test_helper'

class ClockReminderJobTest < ActiveJob::TestCase
  test "出勤打刻忘れチェックジョブ" do
    # ジョブが正常に実行されることをテスト
    assert_nothing_raised do
      perform_enqueued_jobs do
        ClockReminderJob.perform_later('clock_in')
      end
    end
  end

  test "退勤打刻忘れチェックジョブ" do
    # ジョブが正常に実行されることをテスト
    assert_nothing_raised do
      perform_enqueued_jobs do
        ClockReminderJob.perform_later('clock_out')
      end
    end
  end

  test "無効なリマインダータイプ" do
    # エラーログが出力されることをテスト
    assert_nothing_raised do
      ClockReminderJob.perform_now('invalid_type')
    end
  end
end
