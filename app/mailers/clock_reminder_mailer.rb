class ClockReminderMailer < ApplicationMailer
  def clock_in_reminder(employee)
    @employee = employee
    mail(
      to: @employee.email,
      subject: '出勤打刻のお知らせ'
    )
  end

  def clock_out_reminder(employee)
    @employee = employee
    mail(
      to: @employee.email,
      subject: '退勤打刻のお知らせ'
    )
  end
end
