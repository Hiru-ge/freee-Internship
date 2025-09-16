require 'test_helper'

class LineBotServiceShiftMergeTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should merge shifts when approver has existing shift" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（20:00-23:00）
    today = Date.current
    requester_shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # 承認者の既存シフト（18:00-20:00）
    approver_shift = Shift.create!(
      employee_id: approver.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # シフト交代リクエスト
    exchange_request = ShiftExchange.create!(
      request_id: "req_#{SecureRandom.hex(8)}",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: requester_shift.id,
      status: 'pending'
    )
    
    # 承認処理を実行
    result = @line_bot_service.handle_approval_postback("approver_user", "approve_#{exchange_request.id}", 'approve')
    
    # 成功することを確認
    assert_includes result, "シフト交代リクエストを承認しました"
    
    # 承認者のシフトが18:00-23:00にマージされていることを確認
    merged_shift = Shift.find_by(employee_id: approver.employee_id, shift_date: today)
    assert_not_nil merged_shift
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
    
    # 申請者のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: requester_shift.id)
    
    # テストデータのクリーンアップ
    merged_shift.destroy
    exchange_request.destroy
    approver.destroy
    requester.destroy
  end

  test "should merge shifts when approver has later shift" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（09:00-12:00）
    today = Date.current
    requester_shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('12:00')
    )
    
    # 承認者の既存シフト（13:00-17:00）
    approver_shift = Shift.create!(
      employee_id: approver.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('13:00'),
      end_time: Time.zone.parse('17:00')
    )
    
    # シフト交代リクエスト
    exchange_request = ShiftExchange.create!(
      request_id: "req_#{SecureRandom.hex(8)}",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: requester_shift.id,
      status: 'pending'
    )
    
    # 承認処理を実行
    result = @line_bot_service.handle_approval_postback("approver_user", "approve_#{exchange_request.id}", 'approve')
    
    # 成功することを確認
    assert_includes result, "シフト交代リクエストを承認しました"
    
    # 承認者のシフトが09:00-17:00にマージされていることを確認
    merged_shift = Shift.find_by(employee_id: approver.employee_id, shift_date: today)
    assert_not_nil merged_shift
    assert_equal '09:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '17:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
    
    # 申請者のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: requester_shift.id)
    
    # テストデータのクリーンアップ
    merged_shift.destroy
    exchange_request.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle overlapping shifts correctly" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（19:00-22:00）
    today = Date.current
    requester_shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    # 承認者の既存シフト（18:00-20:00）
    approver_shift = Shift.create!(
      employee_id: approver.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # シフト交代リクエスト
    exchange_request = ShiftExchange.create!(
      request_id: "req_#{SecureRandom.hex(8)}",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: requester_shift.id,
      status: 'pending'
    )
    
    # 承認処理を実行
    result = @line_bot_service.handle_approval_postback("approver_user", "approve_#{exchange_request.id}", 'approve')
    
    # 成功することを確認
    assert_includes result, "シフト交代リクエストを承認しました"
    
    # 承認者のシフトが18:00-22:00にマージされていることを確認
    merged_shift = Shift.find_by(employee_id: approver.employee_id, shift_date: today)
    assert_not_nil merged_shift
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '22:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
    
    # 申請者のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: requester_shift.id)
    
    # テストデータのクリーンアップ
    merged_shift.destroy
    exchange_request.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle case when approver has no existing shift" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（09:00-17:00）
    today = Date.current
    requester_shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('17:00')
    )
    
    # シフト交代リクエスト
    exchange_request = ShiftExchange.create!(
      request_id: "req_#{SecureRandom.hex(8)}",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: requester_shift.id,
      status: 'pending'
    )
    
    # 承認処理を実行
    result = @line_bot_service.handle_approval_postback("approver_user", "approve_#{exchange_request.id}", 'approve')
    
    # 成功することを確認
    assert_includes result, "シフト交代リクエストを承認しました"
    
    # 承認者のシフトが09:00-17:00で作成されていることを確認
    new_shift = Shift.find_by(employee_id: approver.employee_id, shift_date: today)
    assert_not_nil new_shift
    assert_equal '09:00', new_shift.start_time.strftime('%H:%M')
    assert_equal '17:00', new_shift.end_time.strftime('%H:%M')
    assert_equal true, new_shift.is_modified
    
    # 申請者のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: requester_shift.id)
    
    # テストデータのクリーンアップ
    new_shift.destroy
    exchange_request.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle case when requester shift is completely within approver shift" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 申請者のシフト（19:00-20:00）
    today = Date.current
    requester_shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # 承認者の既存シフト（18:00-22:00）
    approver_shift = Shift.create!(
      employee_id: approver.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    # シフト交代リクエスト
    exchange_request = ShiftExchange.create!(
      request_id: "req_#{SecureRandom.hex(8)}",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift_id: requester_shift.id,
      status: 'pending'
    )
    
    # 承認処理を実行
    result = @line_bot_service.handle_approval_postback("approver_user", "approve_#{exchange_request.id}", 'approve')
    
    # 成功することを確認
    assert_includes result, "シフト交代リクエストを承認しました"
    
    # 承認者のシフトが18:00-22:00のままであることを確認（変更なし）
    existing_shift = Shift.find_by(employee_id: approver.employee_id, shift_date: today)
    assert_not_nil existing_shift
    assert_equal '18:00', existing_shift.start_time.strftime('%H:%M')
    assert_equal '22:00', existing_shift.end_time.strftime('%H:%M')
    assert_equal false, existing_shift.is_modified # 元のシフトなので変更フラグはfalse
    
    # 申請者のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: requester_shift.id)
    
    # テストデータのクリーンアップ
    existing_shift.destroy
    exchange_request.destroy
    approver.destroy
    requester.destroy
  end
end
