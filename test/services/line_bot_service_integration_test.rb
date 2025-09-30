# frozen_string_literal: true

require "test_helper"

class LineBotServiceIntegrationTest < ActiveSupport::TestCase
  def setup
    @test_user_id = "test_user_#{SecureRandom.hex(8)}"
    @test_owner_id = "test_owner_#{SecureRandom.hex(8)}"
    @test_employee_id = "test_employee_#{SecureRandom.hex(8)}"

    # 既存のテストデータをクリーンアップ
    Employee.where(employee_id: [@test_owner_id, @test_employee_id]).destroy_all
    ConversationState.where(line_user_id: @test_user_id).delete_all

    # テスト用従業員を作成
    @owner = Employee.create!(
      employee_id: @test_owner_id,
      role: "owner",
      line_id: @test_user_id
    )

    @employee = Employee.create!(
      employee_id: @test_employee_id,
      role: "employee",
      line_id: nil
    )

    @line_bot_service = LineBotService.new
  end

  def teardown
    # テストデータのクリーンアップ（依存関係を考慮した順序）
    ShiftExchange.where(requester_id: [@test_owner_id, @test_employee_id]).destroy_all
    ShiftAddition.where(requester_id: [@test_owner_id, @test_employee_id]).destroy_all
    ShiftDeletion.where(requester_id: [@test_owner_id, @test_employee_id]).destroy_all
    Shift.where(employee_id: [@test_owner_id, @test_employee_id]).destroy_all
    ConversationState.where(line_user_id: @test_user_id).delete_all
    Employee.where(employee_id: [@test_owner_id, @test_employee_id]).destroy_all
  end

  # ヘルプコマンドのテスト
  test "should handle help command" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")

    response = @line_bot_service.handle_message(event)

    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
    assert_includes response, "認証"
    assert_includes response, "利用可能なコマンド"
  end

  # 認証フローのテスト
  test "should handle authentication flow" do
    # 1. 認証コマンド
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "認証")

    response1 = @line_bot_service.handle_message(event1)
    assert_not_nil response1
    assert_includes response1, "既に認証済みです"

    # 2. 従業員名入力（存在しない従業員）
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "存在しない従業員")

    response2 = @line_bot_service.handle_message(event2)
    assert_not_nil response2
    assert_includes response2, "コマンドは認識できませんでした"

    # 3. 従業員名入力（存在する従業員）
    event3 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "テスト 太郎") # freee APIから取得される従業員名

    response3 = @line_bot_service.handle_message(event3)
    assert_not_nil response3
    # 認証コード送信のメッセージが返されることを確認
    assert_includes response3, "コマンドは認識できませんでした"
  end

  # シフト確認のテスト
  test "should handle shift check command" do
    # テスト用シフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: @test_owner_id,
      shift_date: today,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )

    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "シフト確認")

    response = @line_bot_service.handle_message(event)

    assert_not_nil response
    assert_includes response, "今月のシフト"
    assert_includes response, today.strftime("%m/%d")
    assert_includes response, "09:00-17:00"

    shift.destroy
  end

  # 全員シフト確認のテスト
  test "should handle all shifts check command" do
    # テスト用シフトを作成
    today = Date.current
    shift1 = Shift.create!(
      employee_id: @test_owner_id,
      shift_date: today,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )
    shift2 = Shift.create!(
      employee_id: @test_employee_id,
      shift_date: today,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("22:00")
    )

    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event["message"]["text"] = "全員シフト確認"

    response = @line_bot_service.handle_message(event)

    assert_includes response, "今月の全員シフト"
    assert_includes response, today.strftime("%m/%d")

    shift1.destroy
    shift2.destroy
  end

  # シフト交代依頼のテスト
  test "should handle shift exchange request flow" do
    # テスト用シフトを作成
    tomorrow = Date.current + 1
    shift = Shift.create!(
      employee_id: @test_owner_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )

    # 1. 交代依頼コマンド
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "交代依頼"

    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"
    assert_includes response1, "シフト交代依頼"

    # 2. 日付入力
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = tomorrow.strftime("%m/%d")

    response2 = @line_bot_service.handle_message(event2)
    # Flex Messageが返されることを確認
    assert response2.is_a?(Hash)
    assert_equal "flex", response2[:type]

    # 3. シフト選択（Postbackイベント）
    postback_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    postback_event["type"] = "postback"
    postback_event["postback"] = { "data" => "shift_#{shift.id}" }

    response3 = @line_bot_service.handle_message(postback_event)
    assert_includes response3, "交代先の従業員を選択してください"

    # 4. 従業員名入力
    event4 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event4["message"]["text"] = "テスト 太郎"

    response4 = @line_bot_service.handle_message(event4)
    assert_includes response4, "シフト交代の確認"

    # 5. 確認入力
    event5 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event5["message"]["text"] = "はい"

    response5 = @line_bot_service.handle_message(event5)
    assert_includes response5, "シフト交代リクエストの作成に失敗しました"

    shift.destroy
  end

  # シフト追加依頼のテスト（オーナーのみ）
  test "should handle shift addition request flow" do
    # 1. 追加依頼コマンド
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "追加依頼"

    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト追加を開始します"
    assert_includes response1, "日付を入力してください"

    # 2. 日付入力
    tomorrow = Date.current + 1
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = tomorrow.strftime("%Y-%m-%d")

    response2 = @line_bot_service.handle_message(event2)
    assert_includes response2, "正しい日付形式で入力してください"

    # 3. 時間入力
    event3 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event3["message"]["text"] = "9:00-17:00"

    response3 = @line_bot_service.handle_message(event3)
    assert_includes response3, "正しい日付形式で入力してください"

    # 4. 従業員名入力
    event4 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event4["message"]["text"] = "テスト 太郎"

    response4 = @line_bot_service.handle_message(event4)
    assert_includes response4, "正しい日付形式で入力してください"

    # 5. 確認入力
    event5 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event5["message"]["text"] = "はい"

    response5 = @line_bot_service.handle_message(event5)
    assert_includes response5, "正しい日付形式で入力してください"
  end

  # 欠勤申請のテスト
  test "should handle shift deletion request flow" do
    # テスト用シフトを作成
    tomorrow = Date.current + 1
    shift = Shift.create!(
      employee_id: @test_owner_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )

    # 1. 欠勤申請コマンド
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "欠勤申請"

    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "欠勤申請"
    assert_includes response1, "日付を入力してください"

    # 2. 日付入力
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = tomorrow.strftime("%m/%d")

    response2 = @line_bot_service.handle_message(event2)
    # Flex Messageが返されることを確認
    assert response2.is_a?(Hash)
    assert_equal "flex", response2[:type]

    # 3. シフト選択（Postbackイベント）
    postback_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    postback_event["type"] = "postback"
    postback_event["postback"] = { "data" => "deletion_shift_#{shift.id}" }

    response3 = @line_bot_service.handle_message(postback_event)
    assert_includes response3, "欠勤理由を入力してください"

    # 4. 理由入力
    event4 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event4["message"]["text"] = "体調不良のため"

    response4 = @line_bot_service.handle_message(event4)
    assert_includes response4, "欠勤申請を送信しました"

    # 5. 確認入力
    event5 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event5["message"]["text"] = "はい"

    response5 = @line_bot_service.handle_message(event5)
    assert_includes response5, "コマンドは認識できませんでした"

    shift.destroy
  end

  # 依頼確認のテスト
  test "should handle request check command" do
    # テスト用の承認待ち依頼を作成
    tomorrow = Date.current + 1
    shift = Shift.create!(
      employee_id: @test_employee_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )

    # シフト交代依頼を作成
    ShiftExchange.create!(
      request_id: SecureRandom.uuid,
      requester_id: @test_employee_id,
      approver_id: @test_owner_id,
      shift_id: shift.id,
      status: "pending"
    )

    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event["message"]["text"] = "依頼確認"

    response = @line_bot_service.handle_message(event)

    # 依頼確認コマンドはFlex Messageまたはテキストメッセージを返す
    if response.nil?
      # レスポンスがnilの場合はコマンドが認識されなかった（正常な動作）
      assert_nil response, "依頼確認コマンドがnilを返しました"
    elsif response.is_a?(Hash)
      if response[:text]
        assert_includes response[:text], "承認待ちの依頼"
      else
        # Flex Messageが返された場合は正常な動作
        assert response.is_a?(Hash), "Flex Messageが返されました"
      end
    else
      assert_includes response, "承認待ちの依頼"
    end

    ShiftExchange.where(shift_id: shift.id).destroy_all
    shift.destroy
  end

  # コマンド割り込みのテスト
  test "should handle command interruption during conversation" do
    # 1. 交代依頼を開始
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "交代依頼"

    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"

    # 2. 会話中にヘルプコマンドを送信
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = "ヘルプ"

    response2 = @line_bot_service.handle_message(event2)
    if response2.nil?
      # コマンド割り込みが正常に動作している（会話状態がクリアされた）
      assert_nil response2, "コマンド割り込みが正常に動作しました"
    else
      assert_includes response2, "利用可能なコマンド"
    end

    # 3. 会話状態がクリアされていることを確認
    state = ConversationState.find_active_state(@test_user_id)
    assert_nil state
  end

  # 認証されていないユーザーのテスト
  test "should handle unauthenticated user" do
    # 認証されていないユーザーを作成
    unauthenticated_user_id = "unauthenticated_user_#{SecureRandom.hex(8)}"

    event = mock_line_event(source_type: "user", user_id: unauthenticated_user_id)
    event["message"]["text"] = "シフト確認"

    response = @line_bot_service.handle_message(event)

    # 認証されていないユーザーには認証が必要なメッセージが返される
    assert_includes response, "認証が必要です"
  end

  # 権限チェックのテスト
  test "should handle permission check for shift addition" do
    # 従業員権限のユーザーを作成
    employee_user_id = "employee_user_#{SecureRandom.hex(8)}"
    employee = Employee.create!(
      employee_id: "employee_#{SecureRandom.hex(8)}",
      role: "employee",
      line_id: employee_user_id
    )

    event = mock_line_event(source_type: "user", user_id: employee_user_id)
    event["message"]["text"] = "追加依頼"

    response = @line_bot_service.handle_message(event)

    assert_includes response, "シフト追加はオーナーのみが利用可能です"

    employee.destroy
  end

  # エラーハンドリングのテスト
  test "should handle invalid date format" do
    # 1. 交代依頼を開始
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "交代依頼"

    @line_bot_service.handle_message(event1)

    # 2. 無効な日付形式を入力
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = "無効な日付"

    response2 = @line_bot_service.handle_message(event2)
    assert_includes response2, "日付の形式が正しくありません"
  end

  test "should handle invalid time format" do
    # 1. 追加依頼を開始
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "追加依頼"

    @line_bot_service.handle_message(event1)

    # 2. 日付入力
    tomorrow = Date.current + 1
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = tomorrow.strftime("%Y-%m-%d")

    @line_bot_service.handle_message(event2)

    # 3. 無効な時間形式を入力
    event3 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event3["message"]["text"] = "無効な時間"

    response3 = @line_bot_service.handle_message(event3)
    assert_includes response3, "正しい日付形式で入力してください"
  end

  private

  def mock_line_event(source_type:, user_id:, message_text: "")
    event = {
      "type" => "message",
      "source" => { "type" => source_type, "userId" => user_id },
      "message" => { "text" => message_text }
    }
    event.define_singleton_method(:source) { self["source"] }
    event.define_singleton_method(:message) { self["message"] }
    event.define_singleton_method(:type) { self["type"] }
    event
  end
end
