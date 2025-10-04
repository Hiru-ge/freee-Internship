# frozen_string_literal: true

module PasswordValidator
  extend ActiveSupport::Concern

  def self.validate_password(password)
    errors = []

    min_length = AppConstants.auth.dig(:password, :min_length) || 8
    errors << "パスワードは#{min_length}文字以上で入力してください" if password.length < min_length

    errors << "パスワードには英字を含めてください" if AppConstants.auth.dig(:password, :require_letters) && !password.match(/[a-zA-Z]/)

    errors << "パスワードには数字を含めてください" if AppConstants.auth.dig(:password, :require_numbers) && !password.match(/[0-9]/)

    if AppConstants.auth.dig(:password, :require_symbols) && !password.match(%r{[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]})
      errors << "パスワードには記号を含めてください"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def self.password_strength(password)
    score = 0

    score += 1 if password.length >= 8
    score += 1 if password.length >= 12

    score += 1 if password.match(/[a-z]/)
    score += 1 if password.match(/[A-Z]/)
    score += 1 if password.match(/[0-9]/)
    score += 1 if password.match(%r{[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]})
    case score
    when 0..2
      :weak
    when 3..4
      :medium
    when 5..6
      :strong
    else
      :very_strong
    end
  end

  def self.strength_message(strength)
    case strength
    when :weak
      "弱い"
    when :medium
      "普通"
    when :strong
      "強い"
    when :very_strong
      "非常に強い"
    else
      "不明"
    end
  end

  def self.strength_color(strength)
    case strength
    when :weak
      "#f44336"
    when :medium
      "#ff9800"
    when :strong
      "#4caf50"
    when :very_strong
      "#2196f3"
    else
      "#999"
    end
  end
end
