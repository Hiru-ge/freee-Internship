# frozen_string_literal: true

# パスワードバリデーションの共通モジュール
# DRY原則に従って、パスワード検証ロジックを統一

module PasswordValidator
  extend ActiveSupport::Concern

  # パスワードの検証
  def self.validate_password(password)
    errors = []

    # 最小文字数チェック
    min_length = AppConstants.auth.dig(:password, :min_length) || 8
    errors << "パスワードは#{min_length}文字以上で入力してください" if password.length < min_length

    # 英字チェック
    errors << "パスワードには英字を含めてください" if AppConstants.auth.dig(:password, :require_letters) && !password.match(/[a-zA-Z]/)

    # 数字チェック
    errors << "パスワードには数字を含めてください" if AppConstants.auth.dig(:password, :require_numbers) && !password.match(/[0-9]/)

    # 記号チェック
    if AppConstants.auth.dig(:password, :require_symbols) && !password.match(%r{[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]})
      errors << "パスワードには記号を含めてください"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # パスワードの強度を評価
  def self.password_strength(password)
    score = 0

    # 文字数によるスコア
    score += 1 if password.length >= 8
    score += 1 if password.length >= 12

    # 文字種によるスコア
    score += 1 if password.match(/[a-z]/)
    score += 1 if password.match(/[A-Z]/)
    score += 1 if password.match(/[0-9]/)
    score += 1 if password.match(%r{[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]})

    # 強度レベルを返す
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

  # パスワードの強度メッセージ
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

  # パスワードの強度に応じた色
  def self.strength_color(strength)
    case strength
    when :weak
      "#f44336" # 赤
    when :medium
      "#ff9800" # オレンジ
    when :strong
      "#4caf50" # 緑
    when :very_strong
      "#2196f3" # 青
    else
      "#999" # グレー
    end
  end
end
