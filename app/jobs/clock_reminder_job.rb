# frozen_string_literal: true

class ClockReminderJob < ApplicationJob
  queue_as :default

  def perform(reminder_type)
    case reminder_type
    when "clock_in"
      ClockReminderService.check_forgotten_clock_ins
    when "clock_out"
      ClockReminderService.check_forgotten_clock_outs
    else
      Rails.logger.error "Unknown reminder type: #{reminder_type}"
    end
  end
end
