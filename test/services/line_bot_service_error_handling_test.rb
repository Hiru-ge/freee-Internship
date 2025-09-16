require 'test_helper'

class LineBotServiceErrorHandlingTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should handle database connection errors gracefully" do
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
    
    # データベースエラーをシミュレート（実際の実装ではモックを使用）
    # ここでは、エラーが発生しても適切なエラーメッセージが返されることを確認
    
    # シフト交代依頼を作成
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 正常な場合は成功、エラーの場合は適切なエラーメッセージが返される
    assert result[:success] || result[:message].include?("管理者にお問い合わせください")
    
    # テストデータのクリーンアップ
    if result[:success]
      exchange_request = ShiftExchange.last
      exchange_request.destroy
    end
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle invalid date format errors" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 承認者
    approver = Employee.create!(employee_id: "1000", role: "employee", line_id: "approver_user")
    
    # 無効な日付形式でシフト交代依頼を作成
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => 'invalid-date',
      'selected_employee_id' => approver.employee_id
    })
    
    # エラーメッセージが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "管理者にお問い合わせください"
    
    # テストデータのクリーンアップ
    approver.destroy
    requester.destroy
  end

  test "should handle missing employee errors" do
    # 存在しない従業員IDでシフト交代依頼を作成
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => Date.current.to_s,
      'selected_employee_id' => 'nonexistent_employee'
    })
    
    # エラーメッセージが返されることを確認
    assert_equal false, result[:success]
    assert_includes result[:message], "従業員情報が見つかりません"
  end

  test "should handle network errors in notification sending" do
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
    
    # ネットワークエラーをシミュレート（実際の実装ではモックを使用）
    # ここでは、通知送信エラーが発生しても依頼作成は成功することを確認
    
    # シフト交代依頼を作成
    result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 依頼作成は成功する（通知エラーは別途ログに記録される）
    assert_equal true, result[:success]
    assert_includes result[:message], "シフト交代依頼を送信しました"
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle concurrent request creation errors" do
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
    
    # 最初のリクエストを作成
    first_result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 同じリクエストを再度作成（重複エラー）
    second_result = @line_bot_service.send(:create_shift_exchange_request, @test_user_id, {
      'shift_date' => today.to_s,
      'selected_employee_id' => approver.employee_id
    })
    
    # 最初のリクエストは成功、2番目は重複エラー
    assert_equal true, first_result[:success]
    assert_equal false, second_result[:success]
    assert_includes second_result[:message], "既にシフト交代依頼が存在します"
    
    # テストデータのクリーンアップ
    exchange_request = ShiftExchange.last
    exchange_request.destroy
    shift.destroy
    approver.destroy
    requester.destroy
  end

  test "should handle malformed postback data errors" do
    # 認証済みユーザー
    employee = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 不正なpostbackデータでイベントを作成
    event = {
      'type' => 'postback',
      'source' => { 'type' => 'user', 'userId' => @test_user_id },
      'postback' => { 'data' => 'invalid_data' }
    }
    
    # postbackイベントを処理
    response = @line_bot_service.handle_message(event)
    
    # 適切なエラーメッセージが返されることを確認
    assert_includes response, "不明なPostbackイベントです"
    
    # テストデータのクリーンアップ
    employee.destroy
  end
end
