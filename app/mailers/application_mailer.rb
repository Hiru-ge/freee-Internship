# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
  prepend_view_path Rails.root.join("app", "views", "mailers")
end
