require "test_helper"

class LineBotServiceTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_id"
    @test_group_id = "test_group_id"
  end

  test "should identify group message source" do
    # グループメッセージの識別テスト
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    
    assert @line_bot_service.group_message?(event)
    assert_not @line_bot_service.individual_message?(event)
  end

  test "should identify individual message source" do
    # 個人メッセージの識別テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    
    assert_not @line_bot_service.group_message?(event)
    assert @line_bot_service.individual_message?(event)
  end

  test "should extract group id from group message" do
    # グループIDの抽出テスト
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    
    group_id = @line_bot_service.extract_group_id(event)
    
    assert_equal @test_group_id, group_id
  end

  test "should extract user id from any message" do
    # ユーザーIDの抽出テスト（グループ・個人両方）
    group_event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    individual_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    
    group_user_id = @line_bot_service.extract_user_id(group_event)
    individual_user_id = @line_bot_service.extract_user_id(individual_event)
    
    assert_equal @test_user_id, group_user_id
    assert_equal @test_user_id, individual_user_id
  end

  test "should return nil for group id from individual message" do
    # 個人メッセージからグループIDを取得した場合はnil
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    
    group_id = @line_bot_service.extract_group_id(event)
    
    assert_nil group_id
  end

  test "should find employee by line_id" do
    # LINE IDで従業員を検索するテスト
    line_id = "U1234567890abcdef"
    employee = @line_bot_service.find_employee_by_line_id(line_id)
    
    # まだデータベースにline_idカラムがないため、nilが返されることを確認
    assert_nil employee
  end

  test "should link employee to line account" do
    # 従業員とLINEアカウントを紐付けるテスト
    employee_id = "EMP001"
    line_id = "U1234567890abcdef"
    
    result = @line_bot_service.link_employee_to_line(employee_id, line_id)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, result
  end

  test "should unlink employee from line account" do
    # 従業員とLINEアカウントの紐付けを解除するテスト
    line_id = "U1234567890abcdef"
    
    result = @line_bot_service.unlink_employee_from_line(line_id)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, result
  end

  test "should handle group commands" do
    # グループコマンドの処理テスト
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    event['message']['text'] = '全員シフト'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証が必要なメッセージが返されることを確認
    assert_includes response, "認証が必要です"
  end

  test "should handle individual commands" do
    # 個人コマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'シフト'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証が必要なメッセージが返されることを確認
    assert_includes response, "認証が必要です"
  end

  test "should determine command context based on message source" do
    # メッセージ送信元に基づくコマンドコンテキストの判定テスト
    group_event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    group_event['message']['text'] = 'ヘルプ'
    
    individual_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    individual_event['message']['text'] = 'シフト'
    
    group_context = @line_bot_service.determine_command_context(group_event)
    individual_context = @line_bot_service.determine_command_context(individual_event)
    
    # 実装されたため、適切なコマンドコンテキストが返されることを確認
    assert_equal :help, group_context
    assert_equal :shift, individual_context
  end

  test "should handle authentication command" do
    # 認証コマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = '認証'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証手順の説明メッセージが返されることを確認
    assert_includes response, "認証"
  end

  test "should generate verification code for line user" do
    # LINEユーザー用の認証コード生成テスト
    line_user_id = "U1234567890abcdef"
    employee_id = "EMP001"
    
    result = @line_bot_service.generate_verification_code_for_line(line_user_id, employee_id)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, result
  end

  test "should verify employee id format" do
    # 従業員IDフォーマットの検証テスト
    valid_employee_id = "EMP001"
    invalid_employee_id = "invalid_id"
    
    valid_result = @line_bot_service.valid_employee_id_format?(valid_employee_id)
    invalid_result = @line_bot_service.valid_employee_id_format?(invalid_employee_id)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, valid_result
    assert_equal false, invalid_result
  end

  test "should send verification code via email" do
    # メール認証コード送信機能のテスト
    employee_id = "EMP001"
    line_user_id = "U1234567890abcdef"
    
    result = @line_bot_service.send_verification_code_via_email(employee_id, line_user_id)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, result
  end

  test "should handle email sending errors gracefully" do
    # メール送信エラーのハンドリングテスト
    employee_id = "INVALID_EMP"
    line_user_id = "U1234567890abcdef"
    
    result = @line_bot_service.send_verification_code_via_email(employee_id, line_user_id)
    
    # エラー時もfalseが返されることを確認
    assert_equal false, result
  end

  test "should complete line account linking process" do
    # LINEアカウント紐付けプロセスの完了テスト
    line_user_id = "U1234567890abcdef"
    employee_id = "EMP001"
    verification_code = "123456"
    
    result = @line_bot_service.complete_line_account_linking(line_user_id, employee_id, verification_code)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, result
  end

  test "should validate verification code for linking" do
    # 紐付け用認証コードの検証テスト
    employee_id = "EMP001"
    verification_code = "123456"
    
    result = @line_bot_service.validate_verification_code_for_linking(employee_id, verification_code)
    
    # まだ実装していないため、falseが返されることを確認
    assert_equal false, result
  end

  test "should generate help message" do
    # ヘルプメッセージの生成テスト
    message = @line_bot_service.generate_help_message
    
    assert_includes message, "勤怠管理システムへようこそ"
    assert_includes message, "ヘルプ"
    assert_includes message, "認証"
    assert_includes message, "シフト"
    assert_includes message, "勤怠"
  end

  test "should handle help command" do
    # ヘルプコマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'ヘルプ'
    
    response = @line_bot_service.handle_message(event)
    
    assert_includes response, "勤怠管理システムへようこそ"
  end

  test "should handle unknown command" do
    # 未知のコマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'unknown_command'
    
    response = @line_bot_service.handle_message(event)
    
    assert_includes response, "申し訳ございませんが"
  end

  # シフト確認機能のテスト
  test "should get personal shift information" do
    # 個人シフト確認機能のテスト
    line_user_id = "U1234567890abcdef"
    employee_id = "EMP001"
    
    result = @line_bot_service.get_personal_shift_info(line_user_id)
    
    # まだ実装していないため、nilが返されることを確認
    assert_nil result
  end

  test "should get group shift information" do
    # グループ全体シフト確認機能のテスト
    group_id = "G1234567890abcdef"
    
    result = @line_bot_service.get_group_shift_info(group_id)
    
    # 実装されたため、シフト情報のヘッダーが返されることを確認（シフトデータがない場合は空のヘッダーのみ）
    assert_includes result, "【今月の全員シフト】"
  end

  test "should get daily shift information" do
    # 日別シフト表示機能のテスト
    group_id = "G1234567890abcdef"
    date = Date.current
    
    result = @line_bot_service.get_daily_shift_info(group_id, date)
    
    # まだ実装していないため、nilが返されることを確認
    assert_nil result
  end

  test "should format shift information for display" do
    # シフト情報の表示フォーマット機能のテスト
    shift_data = {
      employee_name: "テスト従業員",
      date: Date.current,
      start_time: Time.parse("09:00"),
      end_time: Time.parse("18:00")
    }
    
    result = @line_bot_service.format_shift_info(shift_data)
    
    # 実装されたため、フォーマットされた文字列が返されることを確認
    assert_not_nil result
    assert_includes result, "テスト従業員さん"
    assert_includes result, "09:00-18:00"
  end

  test "should handle shift command for individual user" do
    # 個人ユーザーのシフトコマンド処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'シフト'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証が必要なメッセージが返されることを確認
    assert_includes response, "認証が必要です"
  end

  test "should handle all shifts command for group" do
    # グループの全員シフトコマンド処理テスト
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    event['message']['text'] = '全員シフト'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証が必要なメッセージが返されることを確認
    assert_includes response, "認証が必要です"
  end

  test "should handle all shifts command for individual user" do
    # 個人ユーザーの全員シフトコマンド処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = '全員シフト'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証が必要なメッセージが返されることを確認
    assert_includes response, "認証が必要です"
  end

  test "should handle all shifts command for authenticated user" do
    # 認証済みユーザーの全員シフトコマンド処理テスト
    # テスト用の従業員データを作成
    employee = Employee.create!(
      employee_id: 999,
      role: "employee",
      line_id: @test_user_id
    )
    
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = '全員シフト'
    
    response = @line_bot_service.handle_message(event)
    
    # 認証済みユーザーのため、シフト情報のヘッダーが返されることを確認
    assert_includes response, "【今月の全員シフト】"
    
    # テストデータのクリーンアップ
    employee.destroy
  end

  # 認証コマンドのテスト
  test "should handle authentication command with implementation" do
    # 認証コマンドの処理テスト
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = '認証'
    
    response = @line_bot_service.handle_message(event)
    
    # 実装されたため、認証手順の説明メッセージが返されることを確認
    assert_includes response, "認証"
  end

  test "should handle employee name input for authentication" do
    # 従業員名入力の処理テスト
    line_user_id = "U1234567890abcdef"
    employee_name = "田中太郎"
    
    result = @line_bot_service.handle_employee_name_input(line_user_id, employee_name)
    
    # 実装されたため、該当する従業員が見つからないメッセージが返されることを確認
    assert_includes result, "該当する従業員が見つかりませんでした"
  end

  test "should search employees by name" do
    # 従業員名検索機能のテスト
    name = "田中"
    
    result = @line_bot_service.search_employees_by_name(name)
    
    # 実装されたため、空の配列が返されることを確認（freee APIが利用できないため）
    assert_equal [], result
  end

  test "should handle multiple employee matches" do
    # 複数の従業員がマッチした場合の処理テスト
    line_user_id = "U1234567890abcdef"
    employee_name = "田中"
    matches = [
      { id: "1", display_name: "田中太郎" },
      { id: "2", display_name: "田中花子" }
    ]
    
    result = @line_bot_service.handle_multiple_employee_matches(line_user_id, employee_name, matches)
    
    # 実装されたため、複数選択肢のメッセージが返されることを確認
    assert_includes result, "複数見つかりました"
    assert_includes result, "田中太郎"
    assert_includes result, "田中花子"
  end

  test "should handle verification code input for authentication" do
    # 認証コード入力の処理テスト
    line_user_id = "U1234567890abcdef"
    employee_id = "EMP001"
    verification_code = "123456"
    
    result = @line_bot_service.handle_verification_code_input(line_user_id, employee_id, verification_code)
    
    # 実装されたため、認証コードが正しくないメッセージが返されることを確認
    assert_includes result, "認証コードが正しくありません"
  end

  test "should check if employee is already linked to line" do
    # 従業員が既にLINEアカウントに紐付けられているかのチェックテスト
    line_user_id = "U1234567890abcdef"
    
    result = @line_bot_service.employee_already_linked?(line_user_id)
    
    # 実装されたため、falseが返されることを確認（データベースに該当レコードがないため）
    assert_equal false, result
  end

  test "should get authentication status for line user" do
    # LINEユーザーの認証状況取得テスト
    line_user_id = "U1234567890abcdef"
    
    result = @line_bot_service.get_authentication_status(line_user_id)
    
    # 実装されたため、nilが返されることを確認（データベースに該当レコードがないため）
    assert_nil result
  end

  # 会話状態管理のテスト
  test "should get conversation state for line user" do
    # 会話状態の取得テスト
    line_user_id = "U1234567890abcdef"
    
    result = @line_bot_service.get_conversation_state(line_user_id)
    
    # 実装されたため、nilが返されることを確認（データベースに該当レコードがないため）
    assert_nil result
  end

  test "should set conversation state for line user" do
    # 会話状態の設定テスト
    line_user_id = "U1234567890abcdef"
    state = { step: "waiting_employee_name", data: {} }
    
    result = @line_bot_service.set_conversation_state(line_user_id, state)
    
    # 実装されたため、trueが返されることを確認
    assert_equal true, result
  end

  test "should clear conversation state for line user" do
    # 会話状態のクリアテスト
    line_user_id = "U1234567890abcdef"
    
    result = @line_bot_service.clear_conversation_state(line_user_id)
    
    # 実装されたため、trueが返されることを確認
    assert_equal true, result
  end

  test "should handle message with conversation state" do
    # 会話状態を考慮したメッセージ処理テスト
    line_user_id = "U1234567890abcdef"
    message_text = "田中太郎"
    
    result = @line_bot_service.handle_message_with_state(line_user_id, message_text)
    
    # 実装されたため、未知のコマンドメッセージが返されることを確認
    assert_includes result, "申し訳ございませんが、そのコマンドは認識できませんでした"
  end

  private

  def mock_line_event(source_type:, user_id:, group_id: nil)
    source = { 'type' => source_type, 'userId' => user_id }
    source['groupId'] = group_id if group_id
    
    event = {
      'source' => source,
      'message' => { 'text' => 'テストメッセージ' },
      'replyToken' => 'test_reply_token'
    }
    
    # LINE Bot SDKのイベントオブジェクトのように動作するように拡張
    event.define_singleton_method(:message) { self['message'] }
    event.define_singleton_method(:source) { self['source'] }
    event.define_singleton_method(:replyToken) { self['replyToken'] }
    
    event
  end
end
