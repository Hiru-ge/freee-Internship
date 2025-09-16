require 'test_helper'

class LineBotServiceDuplicateCheckTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should prevent duplicate shift exchange requests for same shift" do
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
    
    # 最初のシフト交代依頼を作成
    first_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )
    
    # 同じシフトに対して2回目の依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 重複エラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "既にシフト交代依頼が存在します"
    
    # テストデータのクリーンアップ
    first_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should allow new request after previous request is rejected" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（拒否済みリクエスト用）
    today = Date.current
    shift1 = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 申請者のシフト（新しいリクエスト用）
    tomorrow = Date.current + 1.day
    shift2 = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 最初のシフト交代依頼を作成（拒否済み）
    first_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift1.id,
      status: 'rejected'
    )
    
    # 別のシフトに対して新しい依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => tomorrow.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 新しい依頼が作成されることを確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # 新しいShiftExchangeレコードが作成されることを確認
    new_request = ShiftExchange.last
    assert_equal "999", new_request.requester_id
    assert_equal "1000", new_request.approver_id
    assert_equal "pending", new_request.status
    
    # テストデータのクリーンアップ
    new_request.destroy
    first_request.destroy
    shift2.destroy
    shift1.destroy
    approver.destroy
    requester.destroy
  end

  test "should allow new request after previous request is approved" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（承認済みリクエスト用）
    today = Date.current
    shift1 = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 申請者のシフト（新しいリクエスト用）
    tomorrow = Date.current + 1.day
    shift2 = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 最初のシフト交代依頼を作成（承認済み）
    first_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift1.id,
      status: 'approved'
    )
    
    # 別のシフトに対して新しい依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => tomorrow.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 新しい依頼が作成されることを確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # テストデータのクリーンアップ
    new_request = ShiftExchange.last
    new_request.destroy
    first_request.destroy
    shift2.destroy
    shift1.destroy
    approver.destroy
    requester.destroy
  end

  test "should prevent duplicate requests to same approver for same shift" do
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
    
    # 最初のシフト交代依頼を作成
    first_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )
    
    # 同じ承認者に対して同じシフトの依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 重複エラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "既にシフト交代依頼が存在します"
    
    # テストデータのクリーンアップ
    first_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should allow requests to different approvers for same shift" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者1
    approver1 = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user_1")
    
    # 承認者2
    approver2 = Employee.create!(employee_id: "1001", role: "employee", line_id: "approver_user_2")
    
    # 申請者のシフト
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 最初のシフト交代依頼を作成（承認者1へ）
    first_request = ShiftExchange.create!(
      request_id: "REQ_001",
      requester_id: requester.employee_id,
      approver_id: approver1.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )
    
    # 同じシフトに対して別の承認者への依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver2.employee_id
    })
    
    # 新しい依頼が作成されることを確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # 新しいShiftExchangeレコードが作成されることを確認
    new_request = ShiftExchange.last
    assert_equal "999", new_request.requester_id
    assert_equal "1001", new_request.approver_id
    assert_equal "pending", new_request.status
    
    # テストデータのクリーンアップ
    new_request.destroy
    first_request.destroy
    shift.destroy
    approver2.destroy
    approver1.destroy
    requester.destroy
  end
end
