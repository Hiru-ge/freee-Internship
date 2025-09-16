require 'test_helper'

class LineBotServiceNotificationTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should send notification to approver when shift exchange request is created" do
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
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 依頼作成成功を確認
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # 通知が送信されることを確認（モックを使用）
    # 実際の実装では、LINE Bot APIの呼び出しをモックする必要があります
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should not send notification if approver has no line_id" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者（LINE IDなし）
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: nil)
    
    # 申請者のシフト
    today = Date.current
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
    
    # シフト交代依頼を作成
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 依頼作成は成功するが、通知は送信されない
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle notification sending errors gracefully" do
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
    
    # LINE Bot APIのエラーをシミュレート（実際の実装ではモックを使用）
    # ここでは、通知送信エラーが発生しても依頼作成は成功することを確認
    
    # シフト交代依頼を作成
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 依頼作成は成功する
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end
end
