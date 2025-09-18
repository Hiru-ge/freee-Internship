# アクセス制御サービス
# 特定のメールアドレスからのみアクセス可能にする機能
class AccessControlService
  # メールアドレスが許可されているかチェック
  def self.allowed_email?(email)
    return false if email.blank?
    return false unless valid_email_format?(email)
    
    # 特定のメールアドレスをチェック
    return true if specific_allowed_emails.include?(email.downcase)
    
    # @freee.co.jpドメインをチェック
    return true if email.downcase.end_with?('@freee.co.jp')
    
    false
  end

  # 認証コードを生成・送信
  def self.send_verification_code(email)
    return { success: false, message: 'このメールアドレスはアクセスが許可されていません' } unless allowed_email?(email)
    
    # テスト環境では@freee.co.jpドメインへのメール送信を禁止
    if Rails.env.test? && email.downcase.end_with?('@freee.co.jp')
      return { success: false, message: 'テスト環境では@freee.co.jpドメインへのメール送信は禁止されています' }
    end
    
    begin
      # 既存の認証コードを削除
      EmailVerificationCode.where(email: email).delete_all
      
      # 新しい認証コードを生成
      code = EmailVerificationCode.generate_code
      
      # 認証コードを保存
      EmailVerificationCode.create!(
        email: email,
        code: code,
        expires_at: 10.minutes.from_now
      )
      
      # メール送信
      AuthMailer.access_control_verification_code(email, code).deliver_now
      
      { success: true, message: '認証コードを送信しました', code: code }
    rescue => e
      Rails.logger.error "認証コード送信エラー: #{e.message}"
      { success: false, message: '認証コードの送信に失敗しました' }
    end
  end

  # 認証コードを検証
  def self.verify_code(email, code)
    return { success: false, message: 'メールアドレスまたは認証コードが指定されていません' } if email.blank? || code.blank?
    
    # 認証コードを検索
    verification_code = EmailVerificationCode.valid.for_email(email).find_by(code: code)
    
    if verification_code
      # 認証成功 - 認証コードを削除
      verification_code.destroy
      return { success: true, message: '認証が完了しました' }
    end
    
    # 期限切れのコードがあるかチェック
    expired_code = EmailVerificationCode.for_email(email).find_by(code: code)
    if expired_code
      return { success: false, message: '認証コードの有効期限が切れています' }
    end
    
    # 認証コードが見つからない
    { success: false, message: '認証コードが正しくありません' }
  end

  private

  # 特定の許可メールアドレス一覧を取得
  def self.specific_allowed_emails
    @specific_allowed_emails ||= begin
      emails = ENV['ALLOWED_EMAIL_ADDRESSES'] || ''
      emails.split(',').map(&:strip).map(&:downcase).reject(&:blank?)
    end
  end

  # メールアドレスの形式をチェック
  def self.valid_email_format?(email)
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
