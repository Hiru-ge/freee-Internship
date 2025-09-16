require 'test_helper'

class LineBotServiceCancelTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should cancel pending shift exchange request" do
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
    
    # シフト交代依頼を作成
    exchange_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )
    
    # キャンセル処理を実行
    result = @line_bot_service.send(:cancel_shift_exchange_request, @test_user_id, exchange_request.id)
    
    # キャンセル成功メッセージが返されることを確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼をキャンセルしました"
    
    # リクエストのステータスがcancelledに変更されることを確認
    exchange_request.reload
    assert_equal 'cancelled', exchange_request.status
    
    # テストデータのクリーンアップ
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should not allow cancellation of approved request" do
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
    
    # 承認済みのシフト交代依頼を作成
    exchange_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'approved'
    )
    
    # キャンセル処理を実行
    result = @line_bot_service.send(:cancel_shift_exchange_request, @test_user_id, exchange_request.id)
    
    # キャンセル不可エラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "承認済みのリクエストはキャンセルできません"
    
    # リクエストのステータスが変更されていないことを確認
    exchange_request.reload
    assert_equal 'approved', exchange_request.status
    
    # テストデータのクリーンアップ
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should not allow cancellation of rejected request" do
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
    
    # 拒否済みのシフト交代依頼を作成
    exchange_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'rejected'
    )
    
    # キャンセル処理を実行
    result = @line_bot_service.send(:cancel_shift_exchange_request, @test_user_id, exchange_request.id)
    
    # キャンセル不可エラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "既に処理済みのリクエストはキャンセルできません"
    
    # リクエストのステータスが変更されていないことを確認
    exchange_request.reload
    assert_equal 'rejected', exchange_request.status
    
    # テストデータのクリーンアップ
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should not allow cancellation by non-requester" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 他の従業員（申請者ではない）
    other_employee = Employee.create!(employee_id: "1001", role: "employee", line_id: "other_user")
    
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
    
    # シフト交代依頼を作成
    exchange_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )
    
    # 他の従業員がキャンセル処理を実行
    result = @line_bot_service.send(:cancel_shift_exchange_request, "other_user", exchange_request.id)
    
    # 権限エラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "このリクエストをキャンセルする権限がありません"
    
    # リクエストのステータスが変更されていないことを確認
    exchange_request.reload
    assert_equal 'pending', exchange_request.status
    
    # テストデータのクリーンアップ
    exchange_request.destroy
    shift.destroy
    approver.destroy
    other_employee.destroy
    requester.destroy
  end

  test "should handle non-existent request cancellation" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 存在しないリクエストIDでキャンセル処理を実行
    result = @line_bot_service.send(:cancel_shift_exchange_request, @test_user_id, 99999)
    
    # リクエスト不存在エラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "シフト交代リクエストが見つかりません"
    
    # テストデータのクリーンアップ
    requester.destroy
  end
end
