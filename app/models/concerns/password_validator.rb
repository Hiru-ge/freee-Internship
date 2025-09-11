# パスワードバリデーションの共通モジュール
# DRY原則に従って、パスワード検証ロジックを統一

module PasswordValidator
  extend ActiveSupport::Concern
  
  # パスワードの検証
  def self.validate_password(password)
    errors = []
    
    # 最小文字数チェック
    min_length = AppConstants.auth.dig(:password, :min_length) || 8
    if password.length < min_length
      errors << "パスワードは#{min_length}文字以上で入力してください"
    end
    
    # 英字チェック
    if AppConstants.auth.dig(:password, :require_letters) && !password.match(/[a-zA-Z]/)
      errors << "パスワードには英字を含めてください"
    end
    
    # 数字チェック
    if AppConstants.auth.dig(:password, :require_numbers) && !password.match(/[0-9]/)
      errors << "パスワードには数字を含めてください"
    end
    
    # 記号チェック
    if AppConstants.auth.dig(:password, :require_symbols) && !password.match(/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/)
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
    if password.length >= 8
      score += 1
    end
    if password.length >= 12
      score += 1
    end
    
    # 文字種によるスコア
    if password.match(/[a-z]/)
      score += 1
    end
    if password.match(/[A-Z]/)
      score += 1
    end
    if password.match(/[0-9]/)
      score += 1
    end
    if password.match(/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/)
      score += 1
    end
    
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
