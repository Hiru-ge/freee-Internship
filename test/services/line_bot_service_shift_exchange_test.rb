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

    # Flex Message形式のシフトカードが返されることを確認
    assert response.is_a?(Hash)
    assert_equal 'flex', response[:type]
    assert_equal 'シフト交代依頼 - 交代したいシフトを選択してください', response[:altText]
    assert response[:contents][:contents].is_a?(Array)
    assert response[:contents][:contents].length > 0

    # シフトカードの内容を確認
    shift_card = response[:contents][:contents].first
    assert_equal 'bubble', shift_card[:type]
    assert_includes shift_card[:body][:contents].first[:text], 'シフト交代依頼'
    
    # 交代を依頼ボタンが存在することを確認
    footer_buttons = shift_card[:footer][:contents]
    exchange_button = footer_buttons.find { |button| button[:action][:label] == '交代を依頼' }
    assert_not_nil exchange_button
    assert_equal 'postback', exchange_button[:action][:type]
    assert_match(/^shift_\d+$/, exchange_button[:action][:data])

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

    assert_includes response, "今月のシフトがありません"

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
    assert_equal 'flex', response[:type]
    assert_equal '承認待ちのシフト交代リクエスト', response[:altText]
    assert response[:contents][:contents].is_a?(Array)
    assert response[:contents][:contents].length > 0

    # 承認待ちリクエストカードの内容を確認
    request_card = response[:contents][:contents].first
    assert_equal 'bubble', request_card[:type]
    assert_includes request_card[:body][:contents].first[:text], 'シフト交代承認'
    
    # 承認・拒否ボタンが存在することを確認
    footer_buttons = request_card[:footer][:contents]
    approve_button = footer_buttons.find { |button| button[:action][:label] == '承認' }
    reject_button = footer_buttons.find { |button| button[:action][:label] == '拒否' }
    
    assert_not_nil approve_button
    assert_not_nil reject_button
    assert_equal 'postback', approve_button[:action][:type]
    assert_equal 'postback', reject_button[:action][:type]
    assert_match(/^approve_\d+$/, approve_button[:action][:data])
    assert_match(/^reject_\d+$/, reject_button[:action][:data])

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

    assert_includes response, "承認待ちのシフト交代リクエストはありません"

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
    assert_includes response, "交代先の従業員を選択してください"

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
