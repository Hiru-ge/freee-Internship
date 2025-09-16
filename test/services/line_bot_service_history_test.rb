require 'test_helper'

class LineBotServiceHistoryTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should display comprehensive shift exchange history" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 複数のシフト交代依頼を作成（異なるステータス）
    pending_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending',
      created_at: 1.hour.ago
    )
    
    approved_request = ShiftExchange.create!(
      request_id: "REQ_002",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'approved',
      created_at: 2.hours.ago,
      responded_at: 1.hour.ago
    )
    
    rejected_request = ShiftExchange.create!(
      request_id: "REQ_003",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'rejected',
      created_at: 3.hours.ago,
      responded_at: 2.hours.ago
    )
    
    cancelled_request = ShiftExchange.create!(
      request_id: "REQ_004",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'cancelled',
      created_at: 4.hours.ago,
      responded_at: 3.hours.ago
    )
    
    # 履歴表示コマンドを実行
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => '交代状況' }
    }
    
    response = @line_bot_service.handle_message(event)
    
    # 各ステータスのリクエストが表示されることを確認
    assert_includes response, "📊 シフト交代状況"
    assert_includes response, "⏳ 承認待ち (1件)"
    assert_includes response, "✅ 承認済み (1件)"
    assert_includes response, "❌ 拒否済み (1件)"
    assert_includes response, "🚫 キャンセル済み (1件)"
    
    # 各リクエストの詳細情報が表示されることを確認
    assert_includes response, today.strftime('%m/%d')
    assert_includes response, "09:00-18:00"
    
    # テストデータのクリーンアップ
    [pending_request, approved_request, rejected_request, cancelled_request].each(&:destroy)
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should display empty history when no requests exist" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 履歴表示コマンドを実行
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => '交代状況' }
    }
    
    response = @line_bot_service.handle_message(event)
    
    # リクエストがない場合のメッセージが表示されることを確認
    assert_includes response, "シフト交代リクエストはありません"
    
    # テストデータのクリーンアップ
    requester.destroy
  end

  test "should display only pending requests when others are empty" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # pendingリクエストのみ作成
    pending_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )
    
    # 履歴表示コマンドを実行
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => '交代状況' }
    }
    
    response = @line_bot_service.handle_message(event)
    
    # pendingリクエストのみが表示されることを確認
    assert_includes response, "⏳ 承認待ち (1件)"
    assert_not_includes response, "✅ 承認済み"
    assert_not_includes response, "❌ 拒否済み"
    assert_not_includes response, "🚫 キャンセル済み"
    
    # テストデータのクリーンアップ
    pending_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should require authentication for history command" do
    # 未認証ユーザーで履歴表示コマンドを実行
    event = {
      'type' => 'message',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'message' => { 'text' => '交代状況' }
    }
    
    response = @line_bot_service.handle_message(event)
    
    # 認証が必要なメッセージが返されることを確認
    assert_includes response, "認証が必要です"
  end
end
