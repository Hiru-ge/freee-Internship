require 'test_helper'

class LineBotServiceExpiryCheckTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should prevent shift exchange requests for past dates" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 過去の日付のシフトを作成
    yesterday = Date.current - 1.day
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: yesterday,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 過去の日付のシフトに対して依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => yesterday.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 期限切れエラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "過去の日付のシフト交代依頼はできません"
    
    # テストデータのクリーンアップ
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should allow shift exchange requests for today" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 今日のシフトを作成
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 今日のシフトに対して依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 依頼が作成されることを確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should allow shift exchange requests for future dates" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 明日のシフトを作成
    tomorrow = Date.current + 1.day
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 明日のシフトに対して依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => tomorrow.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 依頼が作成されることを確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should prevent shift exchange requests for very old dates" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 1週間前のシフトを作成
    one_week_ago = Date.current - 7.days
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: one_week_ago,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # 1週間前のシフトに対して依頼を試行
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => one_week_ago.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 期限切れエラーが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "過去の日付のシフト交代依頼はできません"
    
    # テストデータのクリーンアップ
    shift.destroy
    approver.destroy
    requester.destroy
  end
end
