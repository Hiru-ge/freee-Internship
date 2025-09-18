# frozen_string_literal: true

module RequestIdGenerator
  extend ActiveSupport::Concern

  # リクエストIDの生成（共通化）
  def generate_request_id
    "REQ_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end
end
