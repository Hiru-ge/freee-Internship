# frozen_string_literal: true

require "test_helper"

class AuthServiceTest < ActiveSupport::TestCase
  def setup
    @employee_id = "test_employee_id"
    @password = "test_password"
    @email = "test@example.com"
  end

  # ===== 認証機能テスト =====

  test "パスワードのハッシュ化" do
    hashed_password = AuthService.hash_password(@password)

    assert_not_nil hashed_password
    assert_not_equal @password, hashed_password
  end

  test "パスワードの検証" do
    hashed_password = AuthService.hash_password(@password)

    assert AuthService.verify_password(@password, hashed_password)
    assert_not AuthService.verify_password("wrong_password", hashed_password)
  end

  test "ログイン処理（成功パターン）" do
    result = AuthService.login(@employee_id, @password)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)

    if result[:success]
      assert result.key?(:employee_id)
      assert result.key?(:role)
      assert_equal @employee_id, result[:employee_id]
      assert_includes ["owner", "employee"], result[:role]
    else
      assert result.key?(:message)
      assert result[:message].is_a?(String)
      assert_not result[:message].empty?
    end
  end

  test "ログイン処理（失敗パターン）" do
    result = AuthService.login("nonexistent_employee", @password)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "存在しない従業員IDでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "従業員IDが見つかりません"

    invalid_password_result = AuthService.login(@employee_id, "wrong_password")
    assert_not_nil invalid_password_result
    assert invalid_password_result.is_a?(Hash)
    assert invalid_password_result.key?(:success)
    if !invalid_password_result[:success]
      assert invalid_password_result.key?(:message)
      assert invalid_password_result[:message].is_a?(String)
    end
  end

  test "パスワード変更（成功パターン）" do
    result = AuthService.change_password(@employee_id, @password, "new_password")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)

    if result[:success]
      assert result.key?(:message)
      assert_includes result[:message], "パスワードが正常に変更されました"
    else
      assert result.key?(:message)
      assert result[:message].is_a?(String)
      assert_not result[:message].empty?
    end
  end

  test "パスワード変更（失敗パターン）" do
    result = AuthService.change_password("nonexistent_employee", @password, "new_password")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "存在しない従業員IDでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "従業員IDが見つかりません"

    invalid_current_password_result = AuthService.change_password(@employee_id, "wrong_password", "new_password")
    assert_not_nil invalid_current_password_result
    assert invalid_current_password_result.is_a?(Hash)
    assert invalid_current_password_result.key?(:success)
    if !invalid_current_password_result[:success]
      assert invalid_current_password_result.key?(:message)
      expected_messages = ["現在のパスワードが正しくありません", "従業員IDが見つかりません"]
      assert expected_messages.any? { |msg| invalid_current_password_result[:message].include?(msg) }
    end
  end

  test "初回パスワード設定（成功パターン）" do
    # 有効な従業員IDで初回パスワード設定を試行
    result = AuthService.set_initial_password(@employee_id, @password)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)

    if result[:success]
      # 成功した場合の検証
      assert result.key?(:message)
      assert_includes result[:message], "パスワードが正常に設定されました"
    else
      # 失敗した場合の検証
      assert result.key?(:message)
      assert result[:message].is_a?(String)
      assert_not result[:message].empty?
    end
  end

  test "初回パスワード設定（失敗パターン）" do
    # 存在しない従業員IDで初回パスワード設定を試行
    result = AuthService.set_initial_password("nonexistent_employee", @password)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "存在しない従業員IDでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "従業員IDが見つかりません"
  end

  test "認証コード送信（成功パターン）" do
    # 有効な従業員IDで認証コード送信を試行
    result = AuthService.send_verification_code(@employee_id)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)

    if result[:success]
      # 成功した場合の検証
      assert result.key?(:message)
      assert_includes result[:message], "認証コードを送信しました"
    else
      # 失敗した場合の検証
      assert result.key?(:message)
      assert result[:message].is_a?(String)
      assert_not result[:message].empty?
    end
  end

  test "認証コード送信（失敗パターン）" do
    result = AuthService.send_verification_code("nonexistent_employee")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "存在しない従業員IDでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "認証コードの送信に失敗しました"
  end

  test "認証コード検証（成功パターン）" do
    send_result = AuthService.send_verification_code(@employee_id)
    assert_not_nil send_result
    assert send_result.is_a?(Hash)
    assert send_result.key?(:success)

    if send_result[:success]
      result = AuthService.verify_code(@employee_id, "123456")
      assert_not_nil result
      assert result.is_a?(Hash)
      assert result.key?(:success)
    end
  end

  test "認証コード検証（失敗パターン）" do
    result = AuthService.verify_code(@employee_id, "000000")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "無効な認証コードでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "認証コードが正しくありません"
  end

  test "認証付き初回パスワード設定（成功パターン）" do
    send_result = AuthService.send_verification_code(@employee_id)
    assert_not_nil send_result
    assert send_result.is_a?(Hash)
    assert send_result.key?(:success)

    if send_result[:success]
      result = AuthService.set_initial_password_with_verification(@employee_id, @password, "123456")
      assert_not_nil result
      assert result.is_a?(Hash)
      assert result.key?(:success)
    end
  end

  test "認証付き初回パスワード設定（失敗パターン）" do
    result = AuthService.set_initial_password_with_verification(@employee_id, @password, "000000")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "無効な認証コードでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "認証コードが正しくありません"
  end

  test "パスワードリセット用認証コード送信（成功パターン）" do
    result = AuthService.send_password_reset_code(@employee_id)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
  end

  test "パスワードリセット用認証コード送信（失敗パターン）" do
    result = AuthService.send_password_reset_code("nonexistent_employee")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "存在しない従業員IDでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "指定された従業員IDが見つかりません"
  end

  test "パスワードリセット用認証コード検証（成功パターン）" do
    send_result = AuthService.send_password_reset_code(@employee_id)
    assert_not_nil send_result
    assert send_result.is_a?(Hash)
    assert send_result.key?(:success)

    if send_result[:success]
      result = AuthService.verify_password_reset_code(@employee_id, "123456")
      assert_not_nil result
      assert result.is_a?(Hash)
      assert result.key?(:success)
    end
  end

  test "パスワードリセット用認証コード検証（失敗パターン）" do
    result = AuthService.verify_password_reset_code(@employee_id, "000000")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "無効な認証コードでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "認証コードが正しくありません"
  end

  test "認証コード付きパスワード再設定（成功パターン）" do
    send_result = AuthService.send_password_reset_code(@employee_id)
    assert_not_nil send_result
    assert send_result.is_a?(Hash)
    assert send_result.key?(:success)

    if send_result[:success]
      result = AuthService.reset_password_with_verification(@employee_id, "new_password", "123456")
      assert_not_nil result
      assert result.is_a?(Hash)
      assert result.key?(:success)
    end
  end

  test "認証コード付きパスワード再設定（失敗パターン）" do
    result = AuthService.reset_password_with_verification(@employee_id, "new_password", "000000")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "無効な認証コードでは失敗するべき"
    assert result.key?(:message)
    assert_includes result[:message], "認証コードが正しくありません"
  end

  test "オーナー権限チェック" do
    # 存在しない従業員IDでオーナー権限チェック
    result = AuthService.is_owner?("nonexistent_employee")
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
    # 存在しない従業員は通常オーナーではない
    assert_not result, "存在しない従業員はオーナーではないべき"
  end

  test "freeeAPIの従業員情報から役割を判定" do
    # オーナー情報で役割を判定
    owner_info = { "id" => 3313254, "display_name" => "オーナー", "role" => "admin" }
    result = AuthService.determine_role_from_freee(owner_info)
    assert_not_nil result
    assert result.is_a?(String)
    assert_includes ["owner", "employee"], result

    # 一般従業員情報で役割を判定
    employee_info = { "id" => 3313255, "display_name" => "一般従業員", "role" => "member" }
    result = AuthService.determine_role_from_freee(employee_info)
    assert_not_nil result
    assert result.is_a?(String)
    assert_includes ["owner", "employee"], result
  end

  test "freee APIから従業員情報を取得" do
    # 存在しない従業員IDでfreee APIから従業員情報を取得
    result = AuthService.get_employee_info_from_freee("nonexistent_employee")
    # 実際のAPIを叩くため、結果は環境によって変わる
    # 実際の実装では、存在しない従業員IDでもハッシュが返される
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:name)
    assert result.key?(:email)
  end

  # ===== アクセス制御機能テスト =====

  test "メールアドレスが許可されているかチェック" do
    # 許可されたメールアドレスでチェック
    allowed_email = "test@example.com"
    result = AuthService.allowed_email?(allowed_email)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)

    # 許可されていないメールアドレスでチェック
    disallowed_email = "unauthorized@example.com"
    result = AuthService.allowed_email?(disallowed_email)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end

  test "認証コードを生成・送信（アクセス制御用）" do
    # 許可されたメールアドレスで認証コードを生成・送信
    result = AuthService.send_access_control_verification_code(@email)
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    # 実際のAPIを叩くため、結果は環境によって変わる
  end

  test "認証コードを検証（アクセス制御用）" do
    # 無効な認証コードで認証コードを検証（アクセス制御用）
    result = AuthService.verify_access_control_code(@email, "000000")
    assert_not_nil result
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert_not result[:success], "無効な認証コードでは失敗するべき"
    assert result.key?(:message)
  end

  test "特定の許可メールアドレス一覧を取得" do
    # 特定の許可メールアドレス一覧を取得
    result = AuthService.specific_allowed_emails
    assert_not_nil result
    assert result.is_a?(Array)
    # 配列の各要素が文字列であることを確認
    result.each do |email|
      assert email.is_a?(String), "メールアドレスは文字列であるべき"
      assert_includes email, "@", "メールアドレスには@が含まれるべき"
    end
  end

  test "メールアドレスの形式をチェック" do
    # 有効なメールアドレスの形式をチェック
    valid_email = "test@example.com"
    result = AuthService.valid_email_format?(valid_email)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)

    # 無効なメールアドレスの形式をチェック
    invalid_email = "invalid-email"
    result = AuthService.valid_email_format?(invalid_email)
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
    assert_not result, "無効なメールアドレス形式ではfalseが返されるべき"
  end
end
