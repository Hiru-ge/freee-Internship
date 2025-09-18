# frozen_string_literal: true

class ClockReminderMailer < ApplicationMailer
  def clock_in_reminder(email, employee_name, shift_time)
    @employee_name = employee_name
    @shift_time = shift_time
    mail(
      to: email,
      subject: "出勤打刻のお知らせ"
    )
  end

  def clock_out_reminder(email, employee_name, shift_time, end_hour)
    @employee_name = employee_name
    @shift_time = shift_time
    @end_hour = end_hour
    mail(
      to: email,
      subject: "退勤打刻のお知らせ"
    )
  end
end
