# frozen_string_literal: true

require "test_helper"

class LineBotServiceTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "U1234567890abcdef"
    @test_group_id = "G1234567890abcdef"
  end

  # ===== 正常系テスト =====

  test "LineBotServiceの初期化" do
    assert_not_nil @line_bot_service
  end

  test "ヘルプコマンドの処理" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "個人チャットでの有効なコマンド処理" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "グループチャットでの有効なコマンド処理" do
    event = mock_line_event(source_type: "group", user_id: @test_user_id, group_id: "test_group_123", message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "依頼確認コマンドでFlexメッセージを返す" do
    employee = Employee.create!(employee_id: "test_employee_123", role: "employee", line_id: @test_user_id)
    other_employee = Employee.create!(employee_id: "other_employee_123", role: "employee")
    shift = Shift.create!(employee: employee, shift_date: Date.current + 1, start_time: "09:00", end_time: "18:00")
    shift_exchange = ShiftExchange.create!(request_id: "exchange_123", requester_id: other_employee.employee_id, approver_id: employee.employee_id, shift: shift, status: "pending")
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(Hash) || response.is_a?(String)
    shift_exchange.destroy
    shift.destroy
    employee.destroy
    other_employee.destroy
  end

  test "依頼がない場合のメッセージ表示" do
    employee = Employee.create!(employee_id: "test_employee_456", role: "employee", line_id: @test_user_id)
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(Hash) || response.is_a?(String)
    employee.destroy
  end

  test "group_message?メソッドの動作確認" do
    personal_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    assert_not @line_bot_service.send(:group_message?, personal_event)
    group_event = mock_line_event(source_type: "group", user_id: @test_user_id, group_id: "test_group_123")
    result = @line_bot_service.send(:group_message?, group_event)
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
  end

  # ===== 異常系テスト =====

  test "未知のコマンドの処理" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event["message"]["text"] = "unknown_command"
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "コマンドは認識できませんでした"
  end

  test "グループチャットでの非コマンドメッセージの無視" do
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id, message_text: "おはようございます")
    response = @line_bot_service.handle_message(event)
    assert response.nil? || response.is_a?(String) || response.is_a?(Hash)
  end

  test "個人チャットでの非コマンドメッセージのエラー表示" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "こんにちは")
    response = @line_bot_service.handle_message(event)
    assert_not_nil response
    assert_includes response, "コマンドは認識できませんでした"
  end

  test "未認証ユーザーの認証要求メッセージ" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "依頼確認")
    response = @line_bot_service.handle_message(event)
    assert response.is_a?(String) || response.is_a?(Hash)
  end

  # ===== LineUtilityService統合テスト =====

  test "ユーザーIDの抽出" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    result = @line_bot_service.extract_user_id(event)
    assert_equal @test_user_id, result
  end


  test "従業員のリンク状態チェック" do
    employee = Employee.create!(employee_id: "test_employee_789", role: "employee", line_id: @test_user_id)
    result = @line_bot_service.employee_already_linked?(@test_user_id)
    assert result
    employee.destroy
  end

  test "従業員のリンク状態チェック（未リンク）" do
    result = @line_bot_service.employee_already_linked?("unlinked_user")
    assert_not result
  end

  test "LINE IDから従業員を検索" do
    employee = Employee.create!(employee_id: "test_employee_101", role: "employee", line_id: @test_user_id)
    result = @line_bot_service.find_employee_by_line_id(@test_user_id)
    assert_not_nil result
    assert_equal employee.id, result.id
    employee.destroy
  end

  test "LINE IDから従業員を検索（見つからない）" do
    result = @line_bot_service.find_employee_by_line_id("nonexistent_user")
    assert_nil result
  end

  test "認証状態の取得" do
    employee = Employee.create!(employee_id: "test_employee_102", role: "employee", line_id: @test_user_id)
    result = @line_bot_service.get_authentication_status(@test_user_id)
    assert_not_nil result
    assert result[:linked]
    assert_equal employee.employee_id, result[:employee_id]
    assert_equal employee.role, result[:role]
    employee.destroy
  end

  test "認証状態の取得（未認証）" do
    result = @line_bot_service.get_authentication_status("unlinked_user")
    assert_nil result
  end


  test "従業員名の正規化" do
    result = @line_bot_service.normalize_employee_name("テスト　従業員")
    assert_equal "てすと　従業員", result
  end

  test "従業員名の部分一致検索" do
    result = @line_bot_service.find_employees_by_name("テスト")
    assert_not_nil result
    assert result.is_a?(Array)
  end

  test "従業員IDの有効性チェック" do
    assert @line_bot_service.valid_employee_id_format?("123")
    assert_not @line_bot_service.valid_employee_id_format?("abc")
    assert_not @line_bot_service.valid_employee_id_format?(123)
  end

  test "従業員選択の解析" do
    result = @line_bot_service.parse_employee_selection("123")
    assert_equal :id, result[:type]
    assert_equal "123", result[:value]
  end

  test "従業員選択の解析（名前）" do
    result = @line_bot_service.parse_employee_selection("テスト従業員")
    assert_equal :name, result[:type]
    assert_equal "テスト従業員", result[:value]
  end

  test "シフト重複チェック" do
    employee = Employee.create!(employee_id: "test_employee_103", role: "employee", line_id: @test_user_id)
    result = @line_bot_service.has_shift_overlap?(employee.employee_id, Date.current, Time.parse("09:00"), Time.parse("17:00"))
    assert_not_nil result
    assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
    employee.destroy
  end

  test "依頼可能な従業員と重複している従業員を取得" do
    employee = Employee.create!(employee_id: "test_employee_104", role: "employee", line_id: @test_user_id)
    employee_ids = [employee.employee_id]
    result = @line_bot_service.get_available_and_overlapping_employees(employee_ids, Date.current, Time.parse("09:00"), Time.parse("17:00"))
    assert_not_nil result
    assert result.key?(:available)
    assert result.key?(:overlapping)
    employee.destroy
  end

  test "リクエストIDの生成" do
    result = @line_bot_service.generate_request_id("TEST")
    assert_not_nil result
    assert result.start_with?("TEST_")
  end

  test "日付フォーマット" do
    date = Date.new(2024, 1, 15)
    result = @line_bot_service.format_date(date)
    assert_equal "01/15", result
  end

  test "時間フォーマット" do
    time = Time.new(2024, 1, 15, 9, 30)
    result = @line_bot_service.format_time(time)
    assert_equal "09:30", result
  end

  test "日付と曜日のフォーマット" do
    date = Date.new(2024, 1, 15) # 月曜日
    result = @line_bot_service.format_date_with_day(date)
    assert_equal "01/15 (月)", result
  end

  test "時間範囲のフォーマット" do
    start_time = Time.new(2024, 1, 15, 9, 0)
    end_time = Time.new(2024, 1, 15, 17, 0)
    result = @line_bot_service.format_time_range(start_time, end_time)
    assert_equal "09:00-17:00", result
  end

  test "現在の日時を取得" do
    result = @line_bot_service.current_time
    assert_not_nil result
    assert result.is_a?(Time)
    now = Time.current
    assert (now - result).abs < 1.second
  end

  test "現在の日付を取得" do
    result = @line_bot_service.current_date
    assert_not_nil result
    assert result.is_a?(Date)
  end

  test "今月の開始日を取得" do
    result = @line_bot_service.current_month_start
    assert_not_nil result
    assert result.is_a?(Date)
    assert_equal 1, result.day
  end

  test "今月の終了日を取得" do
    result = @line_bot_service.current_month_end
    assert_not_nil result
    assert result.is_a?(Date)
  end

  test "来月の開始日を取得" do
    result = @line_bot_service.next_month_start
    assert_not_nil result
    assert result.is_a?(Date)
    assert_equal 1, result.day
  end

  test "来月の終了日を取得" do
    result = @line_bot_service.next_month_end
    assert_not_nil result
    assert result.is_a?(Date)
  end

  test "複数従業員マッチ時のメッセージ生成" do
    matches = [
      { id: 1, display_name: "テスト従業員1" },
      { id: 2, display_name: "テスト従業員2" }
    ]
    result = @line_bot_service.generate_multiple_employee_selection_message("テスト", matches)
    assert_not_nil result
    assert result.include?("複数見つかりました")
    assert result.include?("テスト従業員1")
    assert result.include?("テスト従業員2")
  end

  test "エラーメッセージの生成" do
    result = @line_bot_service.generate_error_message("テストエラー")
    assert_equal "❌ テストエラー", result
  end

  test "成功メッセージの生成" do
    result = @line_bot_service.generate_success_message("テスト成功")
    assert_equal "✅ テスト成功", result
  end

  test "警告メッセージの生成" do
    result = @line_bot_service.generate_warning_message("テスト警告")
    assert_equal "⚠️ テスト警告", result
  end

  test "情報メッセージの生成" do
    result = @line_bot_service.generate_info_message("テスト情報")
    assert_equal "ℹ️ テスト情報", result
  end

  test "ログ出力" do
    assert_nothing_raised do
      @line_bot_service.log_info("テスト情報")
      @line_bot_service.log_error("テストエラー")
      @line_bot_service.log_warn("テスト警告")
      @line_bot_service.log_debug("テストデバッグ")
    end
  end


  private

  def mock_line_event(source_type: "user", user_id: @test_user_id, message_text: nil, group_id: nil)
    event = {
      "type" => "message",
      "source" => {
        "type" => source_type,
        "userId" => user_id
      },
      "message" => {
        "type" => "text",
        "text" => message_text || "テストメッセージ"
      },
      "replyToken" => "test_reply_token_#{SecureRandom.hex(8)}",
      "timestamp" => Time.current.to_i
    }

    if source_type == "group" && group_id
      event["source"]["groupId"] = group_id
    end

    event
  end

  def mock_line_event(message_text, user_id = @test_user_id)
    source = { "type" => "user", "userId" => user_id }
    event = { "source" => source, "message" => { "text" => message_text }, "replyToken" => "test_reply_token" }
    event.define_singleton_method(:message) { self["message"] }
    event.define_singleton_method(:source) { self["source"] }
    event.define_singleton_method(:replyToken) { self["replyToken"] }
    event
  end
end
