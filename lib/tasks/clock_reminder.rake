# frozen_string_literal: true

namespace :clock_reminder do
  desc "出勤打刻忘れチェック"
  task check_clock_ins: :environment do
    puts "出勤打刻忘れチェック開始: #{Time.current}"
    ClockReminderService.check_forgotten_clock_ins
    puts "出勤打刻忘れチェック完了: #{Time.current}"
  end

  desc "退勤打刻忘れチェック"
  task check_clock_outs: :environment do
    puts "退勤打刻忘れチェック開始: #{Time.current}"
    ClockReminderService.check_forgotten_clock_outs
    puts "退勤打刻忘れチェック完了: #{Time.current}"
  end

  desc "打刻忘れチェック（出勤・退勤両方）"
  task check_all: :environment do
    puts "打刻忘れチェック開始: #{Time.current}"
    ClockReminderService.check_forgotten_clock_ins
    ClockReminderService.check_forgotten_clock_outs
    puts "打刻忘れチェック完了: #{Time.current}"
  end
end
