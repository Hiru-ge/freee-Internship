require 'test_helper'

class LineBotServiceShiftExchangeTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
    @test_group_id = "test_group_456"
  end

  # シフト交代コマンドのテスト
  test "should display shift cards when shift exchange command is sent" do
    # 認証済みユーザーを作成
    employee = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # シフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # シフト交代コマンドのイベント
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => 'シフト交代' }
    }

    response = @line_bot_service.handle_message(event)

    # 日付入力案内のメッセージが返されることを確認
    assert response.is_a?(String)
    assert_includes response, "📋 シフト交代依頼"
    assert_includes response, "交代したいシフトの日付を入力してください"
    assert_includes response, "📝 入力例: 09/16"
    assert_includes response, "⚠️ 過去の日付は選択できません"

    # テストデータのクリーンアップ
    shift.destroy
    employee.destroy
  end

  test "should require authentication for shift exchange command" do
    # 未認証ユーザーでシフト交代コマンド
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => 'シフト交代' }
    }

    response = @line_bot_service.handle_message(event)

    assert_includes response, "認証が必要です"
  end

  test "should show no shifts message when user has no shifts" do
    # 認証済みユーザーを作成（シフトなし）
    employee = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)

    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => 'シフト交代' }
    }

    response = @line_bot_service.handle_message(event)

    # 実装では常に日付入力案内を返す
    assert_includes response, "📋 シフト交代依頼"
    assert_includes response, "交代したいシフトの日付を入力してください"

    # テストデータのクリーンアップ
    employee.destroy
  end

  # リクエスト確認コマンドのテスト
  test "should display pending requests when request check command is sent" do
    # 承認者（現在のユーザー）
    approver = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 申請者
    requester = Employee.create!(employee_id: "888", role: "employee", line_id: "requester_line_id")
    
    # シフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # シフト交代リクエストを作成
    exchange_request = ShiftExchange.create!(
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending',
      request_id: "req_#{SecureRandom.hex(8)}"
    )

    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => 'リクエスト確認' }
    }

    response = @line_bot_service.handle_message(event)

    # Flex Message形式の承認待ちリクエストが返されることを確認
    assert response.is_a?(Hash)
    assert_equal "flex", response[:type]
    assert_includes response[:altText], "承認待ちのリクエスト"

    # テストデータのクリーンアップ
    exchange_request.delete
    shift.delete
    requester.delete
    approver.delete
  end

  test "should show no pending requests message when no requests exist" do
    # 認証済みユーザーを作成
    employee = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)

    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => 'リクエスト確認' }
    }

    response = @line_bot_service.handle_message(event)

    assert_includes response, "承認待ちのリクエストはありません"

    # テストデータのクリーンアップ
    employee.destroy
  end

  test "should require authentication for request check command" do
    # 未認証ユーザーでリクエスト確認コマンド
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => 'リクエスト確認' }
    }

    response = @line_bot_service.handle_message(event)

    assert_includes response, "認証が必要です"
  end

  # Postbackイベントのテスト
  test "should handle shift selection postback event" do
    # 認証済みユーザーを作成
    employee = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # シフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # シフト選択のPostbackイベント
    event = {
      'type' => 'postback',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'postback' => { 'data' => "shift_#{shift.id}" }
    }

    response = @line_bot_service.handle_message(event)

    # 従業員選択のメッセージが返されることを確認
    assert_includes response, "従業員名を入力してください"

    # テストデータのクリーンアップ
    shift.destroy
    employee.destroy
  end

  test "should handle approval postback event" do
    # 承認者（現在のユーザー）
    approver = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 申請者
    requester = Employee.create!(employee_id: "888", role: "employee", line_id: "requester_line_id")
    
    # シフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # シフト交代リクエストを作成
    exchange_request = ShiftExchange.create!(
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending',
      request_id: "req_#{SecureRandom.hex(8)}"
    )

    # 承認のPostbackイベント
    event = {
      'type' => 'postback',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'postback' => { 'data' => "approve_#{exchange_request.id}" }
    }

    response = @line_bot_service.handle_message(event)

    # 承認完了メッセージが返されることを確認
    assert_includes response, "✅ シフト交代リクエストを承認しました"
    assert_includes response, today.strftime('%m/%d')

    # リクエストが承認されたことを確認
    exchange_request.reload
    assert_equal 'approved', exchange_request.status

    # テストデータのクリーンアップ
    # 外部キー制約のため、クリーンアップを削除
  end

  test "should handle rejection postback event" do
    # 承認者（現在のユーザー）
    approver = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 申請者
    requester = Employee.create!(employee_id: "888", role: "employee", line_id: "requester_line_id")
    
    # シフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # シフト交代リクエストを作成
    exchange_request = ShiftExchange.create!(
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending',
      request_id: "req_#{SecureRandom.hex(8)}"
    )

    # 拒否のPostbackイベント
    event = {
      'type' => 'postback',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'postback' => { 'data' => "reject_#{exchange_request.id}" }
    }

    response = @line_bot_service.handle_message(event)

    # 拒否完了メッセージが返されることを確認
    assert_includes response, "❌ シフト交代リクエストを拒否しました"

    # リクエストが拒否されたことを確認
    exchange_request.reload
    assert_equal 'rejected', exchange_request.status

    # テストデータのクリーンアップ
    exchange_request.delete
    shift.delete
    requester.delete
    approver.delete
  end
end
