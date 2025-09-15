class AuthMailer < ApplicationMailer
  default from: 'noreply@attendance-system.com'
  
  def password_reset_code(email, name, code)
    @name = name
    @code = code
    @expires_at = 10.minutes.from_now
    
    mail(
      to: email,
      subject: '【勤怠管理システム】パスワード再設定の認証コード'
    )
  end
  
  def verification_code(email, name, code)
    @name = name
    @code = code
    @expires_at = 10.minutes.from_now
    
    mail(
      to: email,
      subject: '【勤怠管理システム】初回パスワード設定の認証コード'
    )
  end

  def line_authentication_code(email, name, code)
    @name = name
    @code = code
    @expires_at = 10.minutes.from_now
    
    mail(
      to: email,
      subject: '【勤怠管理システム】LINE連携認証コード'
    )
  end
end
