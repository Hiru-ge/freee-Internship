# frozen_string_literal: true

require "test_helper"

class LineUtilityServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineUtilityService.new
    @line_user_id = "test_user_123"
    @employee = employees(:employee1)
    @employee.update!(line_id: @line_user_id)
  end

  # ===== 正常系テスト =====

  test "LineUtilityServiceの正常な初期化" do
    assert_not_nil @service
    assert_respond_to @service, :extract_user_id
    assert_respond_to @service, :extract_group_id
    assert_respond_to @service, :group_message?

    test_event = { "source" => { "userId" => "test_user" } }
    user_id = @service.extract_user_id(test_event)
    assert_equal "test_user", user_id
  end

  test "ユーザーIDの抽出" do
    event = mock_event(@line_user_id, "test")
    result = @service.extract_user_id(event)

    assert_equal @line_user_id, result
  end

  test "グループIDの抽出" do
    event = mock_group_event(@line_user_id, "test", "group_123")
    result = @service.extract_group_id(event)

    assert_equal "group_123", result
  end

  test "グループメッセージの判定" do
    event = mock_group_event(@line_user_id, "test", "group_123")
    result = @service.group_message?(event)

    assert result
  end

  test "個人メッセージの判定" do
    event = mock_event(@line_user_id, "test")
    result = @service.individual_message?(event)

    assert result
  end

  test "従業員のリンク状態チェック" do
    result = @service.employee_already_linked?(@line_user_id)

    assert result
  end

  test "LINE IDから従業員を検索" do
    result = @service.find_employee_by_line_id(@line_user_id)

    assert_not_nil result
    assert_equal @employee.id, result.id
  end

  test "認証状態の取得" do
    result = @service.get_authentication_status(@line_user_id)

    assert_not_nil result
    assert result[:linked]
    assert_equal @employee.employee_id, result[:employee_id]
    assert_equal @employee.display_name, result[:display_name]
    assert_equal @employee.role, result[:role]
  end

  # ===== 異常系テスト =====

  test "従業員のリンク状態チェック（未リンク）" do
    result = @service.employee_already_linked?("unlinked_user")

    assert_not result
  end

  test "LINE IDから従業員を検索（見つからない）" do
    result = @service.find_employee_by_line_id("nonexistent_user")

    assert_nil result
  end

  test "認証状態の取得（未認証）" do
    result = @service.get_authentication_status("unlinked_user")

    assert_nil result
  end

  test "認証コマンドの処理" do
    event = mock_event(@line_user_id, "認証")
    result = @service.handle_auth_command(event)

    assert_not_nil result
    assert result.include?("認証を開始します") || result.include?("既に認証済みです")
  end

  test "認証コマンドの処理（既に認証済み）" do
    event = mock_event(@line_user_id, "認証")
    result = @service.handle_auth_command(event)

    assert_not_nil result
    assert result.include?("既に認証済みです")
  end

  test "認証コマンドの処理（グループチャット）" do
    event = mock_group_event(@line_user_id, "認証", "group_123")
    result = @service.handle_auth_command(event)

    assert_not_nil result
    assert result.include?("個人チャットでのみ利用できます")
  end

  test "従業員名入力の処理" do
    result = @service.handle_employee_name_input(@line_user_id, "テスト従業員")

    assert_not_nil result
  end

  test "従業員名入力の処理（見つからない）" do
    result = @service.handle_employee_name_input(@line_user_id, "存在しない従業員")

    assert_not_nil result
    assert result.include?("見つかりませんでした")
  end

  test "従業員名入力の処理（成功パターン）" do
    result = @service.handle_employee_name_input(@line_user_id, "テスト従業員")

    assert_not_nil result
    assert result.is_a?(String)
  end

  test "従業員名入力の処理（失敗パターン）" do
    result = @service.handle_employee_name_input(@line_user_id, "a" * 25)

    assert_not_nil result
    assert result.include?("有効な従業員名を入力してください")
  end

  test "従業員選択入力の処理" do
    employee_matches = [
      { id: 1, display_name: "テスト従業員1" },
      { id: 2, display_name: "テスト従業員2" }
    ]
    result = @service.handle_employee_selection_input(@line_user_id, "1", employee_matches)

    assert_not_nil result
  end

  test "従業員選択入力の処理（失敗パターン）" do
    employee_matches = [
      { id: 1, display_name: "テスト従業員1" }
    ]
    result = @service.handle_employee_selection_input(@line_user_id, "5", employee_matches)

    assert_not_nil result
    assert result.include?("正しい番号を入力してください")
  end

  test "認証コード生成" do
    employee = { id: 1, display_name: "テスト従業員" }
    result = @service.generate_verification_code_for_employee(@line_user_id, employee)

    assert_not_nil result
  end

  test "認証コード入力の処理" do
    result = @service.handle_verification_code_input(@line_user_id, "1", "123456")

    assert_not_nil result
  end

  test "認証コード入力の処理（失敗パターン）" do
    result = @service.handle_verification_code_input(@line_user_id, "1", "000000")

    assert_not_nil result
    assert result.include?("認証コードが正しくありません")
  end

  test "会話状態の設定と取得" do
    state = { "test" => "value" }
    result = @service.set_conversation_state(@line_user_id, state)

    assert result

    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_not_nil retrieved_state
    assert_equal "value", retrieved_state["test"]
  end

  test "会話状態のクリア" do
    state = { "test" => "value" }
    @service.set_conversation_state(@line_user_id, state)

    result = @service.clear_conversation_state(@line_user_id)
    assert result

    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_nil retrieved_state
  end

  test "状態付きメッセージの処理" do
    state = { "state" => "waiting_for_employee_name" }
    result = @service.handle_stateful_message(@line_user_id, "テスト従業員", state)

    assert_not_nil result
  end

  test "状態付きメッセージの処理（不明な状態）" do
    state = { "state" => "unknown_state" }
    result = @service.handle_stateful_message(@line_user_id, "test", state)

    assert_not_nil result
    assert result.include?("不明な状態です")
  end

  test "状態付きメッセージの処理（コマンド送信）" do
    state = { "state" => "waiting_for_employee_name" }
    result = @service.handle_stateful_message(@line_user_id, "ヘルプ", state)

    assert_nil result
  end

  test "状態付きメッセージの処理（状態なし）" do
    result = @service.handle_message_with_state(@line_user_id, "test")

    assert_nil result
  end

  test "従業員名の正規化" do
    result = @service.normalize_employee_name("テスト　従業員")

    assert_equal "てすと　従業員", result
  end

  test "従業員名の部分一致検索" do
    result = @service.find_employees_by_name("テスト")

    assert_not_nil result
    assert result.is_a?(Array)
  end

  test "従業員IDの有効性チェック" do
    assert @service.valid_employee_id_format?("123")
    assert_not @service.valid_employee_id_format?("abc")
    assert_not @service.valid_employee_id_format?(123)
  end

  test "従業員選択の解析" do
    result = @service.parse_employee_selection("123")

    assert_equal :id, result[:type]
    assert_equal "123", result[:value]
  end

  test "従業員選択の解析（名前）" do
    result = @service.parse_employee_selection("テスト従業員")

    assert_equal :name, result[:type]
    assert_equal "テスト従業員", result[:value]
  end

  test "シフト重複チェック" do
    # 重複するシフトでチェック
    result = @service.has_shift_overlap?(@employee.employee_id, Date.current, "09:00", "17:00")
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)

    # 重複しないシフトでチェック
    non_overlapping_result = @service.has_shift_overlap?(@employee.employee_id, Date.current + 1.day, "09:00", "17:00")
    assert_not_nil non_overlapping_result
    assert non_overlapping_result.is_a?(TrueClass) || non_overlapping_result.is_a?(FalseClass)
  end

  test "依頼可能な従業員と重複している従業員を取得" do
    employee_ids = [@employee.employee_id]
    result = @service.get_available_and_overlapping_employees(employee_ids, Date.current, "09:00", "17:00")

    assert_not_nil result
    assert result.key?(:available)
    assert result.key?(:overlapping)
  end

  test "リクエストIDの生成" do
    result = @service.generate_request_id("TEST")

    assert_not_nil result
    assert result.start_with?("TEST_")
  end

  test "日付フォーマット" do
    date = Date.new(2024, 1, 15)
    result = @service.format_date(date)

    assert_equal "01/15", result
  end

  test "時間フォーマット" do
    time = Time.new(2024, 1, 15, 9, 30)
    result = @service.format_time(time)

    assert_equal "09:30", result
  end

  test "日付と曜日のフォーマット" do
    date = Date.new(2024, 1, 15) # 月曜日
    result = @service.format_date_with_day(date)

    assert_equal "01/15 (月)", result
  end

  test "時間範囲のフォーマット" do
    start_time = Time.new(2024, 1, 15, 9, 0)
    end_time = Time.new(2024, 1, 15, 17, 0)
    result = @service.format_time_range(start_time, end_time)

    assert_equal "09:00-17:00", result
  end

  test "現在の日時を取得" do
    # メソッドを実行
    result = @service.current_time

    # 結果の型と内容を検証
    assert_not_nil result
    assert result.is_a?(Time)

    # 現在時刻に近い値が返されることを確認
    now = Time.current
    assert (now - result).abs < 1.second, "現在時刻に近い値が返されるべき"

    # タイムゾーンが正しく設定されていることを確認
    assert_equal "JST", result.zone, "正しいタイムゾーンが設定されるべき"
  end

  test "現在の日付を取得" do
    result = @service.current_date

    assert_not_nil result
    assert result.is_a?(Date)
  end

  test "今月の開始日を取得" do
    result = @service.current_month_start

    assert_not_nil result
    assert result.is_a?(Date)
    assert_equal 1, result.day
  end

  test "今月の終了日を取得" do
    result = @service.current_month_end

    assert_not_nil result
    assert result.is_a?(Date)
  end

  test "来月の開始日を取得" do
    result = @service.next_month_start

    assert_not_nil result
    assert result.is_a?(Date)
    assert_equal 1, result.day
  end

  test "来月の終了日を取得" do
    result = @service.next_month_end

    assert_not_nil result
    assert result.is_a?(Date)
  end

  test "複数従業員マッチ時のメッセージ生成" do
    matches = [
      { id: 1, display_name: "テスト従業員1" },
      { id: 2, display_name: "テスト従業員2" }
    ]
    result = @service.generate_multiple_employee_selection_message("テスト", matches)

    assert_not_nil result
    assert result.include?("複数見つかりました")
    assert result.include?("テスト従業員1")
    assert result.include?("テスト従業員2")
  end

  test "エラーメッセージの生成" do
    result = @service.generate_error_message("テストエラー")

    assert_equal "❌ テストエラー", result
  end

  test "成功メッセージの生成" do
    result = @service.generate_success_message("テスト成功")

    assert_equal "✅ テスト成功", result
  end

  test "警告メッセージの生成" do
    result = @service.generate_warning_message("テスト警告")

    assert_equal "⚠️ テスト警告", result
  end

  test "情報メッセージの生成" do
    result = @service.generate_info_message("テスト情報")

    assert_equal "ℹ️ テスト情報", result
  end

  test "ログ出力" do
    assert_nothing_raised do
      @service.log_info("テスト情報")
      @service.log_error("テストエラー")
      @service.log_warn("テスト警告")
      @service.log_debug("テストデバッグ")
    end
  end

  private

  def mock_event(line_user_id, message_text)
    event = Object.new
    event.define_singleton_method(:source) { { "type" => "user", "userId" => line_user_id } }
    event.define_singleton_method(:message) { { "text" => message_text } }
    event.define_singleton_method(:type) { "message" }
    event.define_singleton_method(:[]) { |key| send(key) }
    event
  end

  def mock_group_event(line_user_id, message_text, group_id)
    event = Object.new
    event.define_singleton_method(:source) { { "type" => "group", "userId" => line_user_id, "groupId" => group_id } }
    event.define_singleton_method(:message) { { "text" => message_text } }
    event.define_singleton_method(:type) { "message" }
    event.define_singleton_method(:[]) { |key| send(key) }
    event
  end
end
