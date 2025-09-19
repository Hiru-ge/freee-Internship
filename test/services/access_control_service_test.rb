# frozen_string_literal: true

require "test_helper"

class AccessControlServiceTest < ActiveSupport::TestCase
  def setup
    # テスト用の環境変数を設定
    ENV["ALLOWED_EMAIL_ADDRESSES"] = "okita2710@gmail.com"
  end

  def teardown
    # テスト後に環境変数をクリア
    ENV.delete("ALLOWED_EMAIL_ADDRESSES")
  end

  # allowed_email?メソッドのテスト
  test "should allow specific email address from environment variable" do
    assert AccessControlService.allowed_email?("okita2710@gmail.com")
  end

  test "should allow any email ending with @freee.co.jp" do
    assert AccessControlService.allowed_email?("test@freee.co.jp")
    assert AccessControlService.allowed_email?("admin@freee.co.jp")
  end

  test "should not allow email not in allowed list and not @freee.co.jp domain" do
    refute AccessControlService.allowed_email?("unauthorized@gmail.com")
    refute AccessControlService.allowed_email?("test@example.com")
    refute AccessControlService.allowed_email?("user@yahoo.co.jp")
  end

  test "should handle nil email gracefully" do
    refute AccessControlService.allowed_email?(nil)
  end

  test "should handle empty email gracefully" do
    refute AccessControlService.allowed_email?("")
  end

  test "should handle malformed email gracefully" do
    refute AccessControlService.allowed_email?("not-an-email")
    refute AccessControlService.allowed_email?("@freee.co.jp")
  end

  # send_verification_codeメソッドのテスト
  test "should send verification code for allowed email" do
    email = "okita2710@gmail.com"

    # メール送信をモック
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear

    result = AccessControlService.send_verification_code(email)

    assert result[:success]
    assert_equal "認証コードを送信しました。メールの送信には数分かかる場合があります。", result[:message]
    assert_not_nil result[:code]
    assert_equal 1, ActionMailer::Base.deliveries.length
  end

  test "should not send verification code for disallowed email" do
    email = "unauthorized@gmail.com"

    result = AccessControlService.send_verification_code(email)

    refute result[:success]
    assert_equal "このメールアドレスはアクセスが許可されていません", result[:message]
  end

  test "should generate 6-digit verification code" do
    email = "okita2710@gmail.com"

    # メール送信をモック
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear

    result = AccessControlService.send_verification_code(email)

    assert_match(/\A\d{6}\z/, result[:code])
  end

  test "should save verification code to database" do
    email = "okita2710@gmail.com"

    # メール送信をモック
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear

    assert_difference "EmailVerificationCode.count", 1 do
      AccessControlService.send_verification_code(email)
    end

    code_record = EmailVerificationCode.last
    assert_equal email, code_record.email
    assert_match(/\A\d{6}\z/, code_record.code)
    assert code_record.expires_at > 9.minutes.from_now
    assert code_record.expires_at < 11.minutes.from_now
  end

  # verify_codeメソッドのテスト
  test "should verify correct code" do
    email = "okita2710@gmail.com"
    code = "123456"

    # 認証コードを作成
    EmailVerificationCode.create!(
      email: email,
      code: code,
      expires_at: 10.minutes.from_now
    )

    result = AccessControlService.verify_code(email, code)

    assert result[:success]
    assert_equal "認証が完了しました", result[:message]
  end

  test "should not verify incorrect code" do
    email = "okita2710@gmail.com"
    correct_code = "123456"
    incorrect_code = "654321"

    # 認証コードを作成
    EmailVerificationCode.create!(
      email: email,
      code: correct_code,
      expires_at: 10.minutes.from_now
    )

    result = AccessControlService.verify_code(email, incorrect_code)

    refute result[:success]
    assert_equal "認証コードが正しくありません", result[:message]
  end

  test "should not verify expired code" do
    email = "okita2710@gmail.com"
    code = "123456"

    # 期限切れの認証コードを作成
    EmailVerificationCode.create!(
      email: email,
      code: code,
      expires_at: 1.minute.ago
    )

    result = AccessControlService.verify_code(email, code)

    refute result[:success]
    assert_equal "認証コードの有効期限が切れています", result[:message]
  end

  test "should delete verification code after successful verification" do
    email = "okita2710@gmail.com"
    code = "123456"

    # 認証コードを作成
    EmailVerificationCode.create!(
      email: email,
      code: code,
      expires_at: 10.minutes.from_now
    )

    assert_difference "EmailVerificationCode.count", -1 do
      AccessControlService.verify_code(email, code)
    end
  end

  test "should handle non-existent code gracefully" do
    email = "okita2710@gmail.com"
    code = "123456"

    result = AccessControlService.verify_code(email, code)

    refute result[:success]
    assert_equal "認証コードが正しくありません", result[:message]
  end

  # エラーハンドリングのテスト
  test "should handle mail delivery error gracefully" do
    email = "okita2710@gmail.com"

    # メール送信エラーをモック
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear

    # メール送信でエラーを発生させる
    AuthMailer.define_singleton_method(:access_control_verification_code) do |_email, _code|
      raise StandardError, "Mail delivery failed"
    end

    result = AccessControlService.send_verification_code(email)

    refute result[:success]
    assert_equal "認証コードの送信に失敗しました", result[:message]

    # 元のメソッドを復元
    AuthMailer.singleton_class.remove_method(:access_control_verification_code)
  end

  # テスト環境での@freee.co.jpドメイン保護
  test "should not send mail to @freee.co.jp domain in test environment" do
    email = "test@freee.co.jp"

    # テスト環境では@freee.co.jpドメインへのメール送信を禁止
    result = AccessControlService.send_verification_code(email)

    refute result[:success]
    assert_equal "テスト環境では@freee.co.jpドメインへのメール送信は禁止されています", result[:message]
  end
end
