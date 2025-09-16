require 'test_helper'
require 'ostruct'

class LineBotServiceShiftExchangeRedesignTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_123"
  end

  test "should prompt for date input when shift exchange command is used" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 今月のシフトを作成
    today = Date.current
    Shift.create!(
      employee_id: requester.employee_id,
      shift_date: today,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('17:00')
    )
    
    # シフト交代コマンドを実行
    event = create_mock_event("シフト交代", @test_user_id)
    result = @line_bot_service.handle_message(event)
    
    # 日付入力の案内が返されることを確認
    assert_includes result, "シフト交代依頼"
    assert_includes result, "日付を入力してください"
    assert_includes result, "例: 09/16"
    
    # テストデータのクリーンアップ
    Shift.where(employee_id: requester.employee_id).destroy_all
    requester.destroy
  end

  test "should show shift card for specific date when valid date is entered" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 特定の日付のシフトを作成
    target_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: target_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('17:00')
    )
    
    # 会話状態を設定
    @line_bot_service.send(:set_conversation_state, @test_user_id, { step: 'waiting_shift_date' })
    
    # 日付を入力
    event = create_mock_event(target_date.strftime('%m/%d'), @test_user_id)
    result = @line_bot_service.handle_message(event)
    
    # Flex Messageが返されることを確認
    assert_equal Hash, result.class
    assert_equal 'flex', result[:type]
    assert_equal 'carousel', result[:contents][:type]
    assert_equal 1, result[:contents][:contents].length
    
    # カードの内容を確認
    bubble = result[:contents][:contents][0]
    assert_equal 'シフト交代依頼', bubble[:body][:contents][0][:text]
    assert_equal '交代を依頼', bubble[:footer][:contents][0][:action][:label]
    
    # テストデータのクリーンアップ
    shift.destroy
    requester.destroy
  end

  test "should show error message when no shift exists for entered date" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 会話状態を設定
    @line_bot_service.send(:set_conversation_state, @test_user_id, { step: 'waiting_shift_date' })
    
    # 存在しない日付を入力
    non_existent_date = Date.current + 30.days
    event = create_mock_event(non_existent_date.strftime('%m/%d'), @test_user_id)
    result = @line_bot_service.handle_message(event)
    
    # エラーメッセージが返されることを確認
    assert_equal String, result.class
    assert_includes result, "指定された日付のシフトが見つかりません"
    assert_includes result, "再度日付を入力してください"
    
    # テストデータのクリーンアップ
    requester.destroy
  end

  test "should show error message when invalid date format is entered" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 会話状態を設定
    @line_bot_service.send(:set_conversation_state, @test_user_id, { step: 'waiting_shift_date' })
    
    # 無効な日付形式を入力
    event = create_mock_event("無効な日付", @test_user_id)
    result = @line_bot_service.handle_message(event)
    
    # エラーメッセージが返されることを確認
    assert_equal String, result.class
    assert_includes result, "日付の形式が正しくありません"
    assert_includes result, "例: 09/16"
    
    # テストデータのクリーンアップ
    requester.destroy
  end

  test "should handle multiple shifts for same date" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 同じ日付の複数のシフトを作成
    target_date = Date.current + 1.day
    shift1 = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: target_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('12:00')
    )
    shift2 = Shift.create!(
      employee_id: requester.employee_id,
      shift_date: target_date,
      start_time: Time.zone.parse('13:00'),
      end_time: Time.zone.parse('17:00')
    )
    
    # 会話状態を設定
    @line_bot_service.send(:set_conversation_state, @test_user_id, { step: 'waiting_shift_date' })
    
    # 日付を入力
    event = create_mock_event(target_date.strftime('%m/%d'), @test_user_id)
    result = @line_bot_service.handle_message(event)
    
    # 複数のカードが返されることを確認
    assert_equal Hash, result.class
    assert_equal 'flex', result[:type]
    assert_equal 'carousel', result[:contents][:type]
    assert_equal 2, result[:contents][:contents].length
    
    # 各カードの時間を確認
    times = result[:contents][:contents].map do |bubble|
      # 時間は2番目のboxの2番目のtext要素
      bubble[:body][:contents][2][:contents][1][:contents][1][:text]
    end
    assert_includes times, "09:00-12:00"
    assert_includes times, "13:00-17:00"
    
    # テストデータのクリーンアップ
    shift1.destroy
    shift2.destroy
    requester.destroy
  end

  test "should handle past date input" do
    # 申請者
    requester = Employee.create!(employee_id: "999", role: "employee", line_id: @test_user_id)
    
    # 会話状態を設定
    @line_bot_service.send(:set_conversation_state, @test_user_id, { step: 'waiting_shift_date' })
    
    # 過去の日付を入力
    past_date = Date.current - 1.day
    event = create_mock_event(past_date.strftime('%m/%d'), @test_user_id)
    result = @line_bot_service.handle_message(event)
    
    # エラーメッセージが返されることを確認
    assert_equal String, result.class
    assert_includes result, "過去の日付のシフト交代依頼はできません"
    
    # テストデータのクリーンアップ
    requester.destroy
  end

  private

  def create_mock_event(message_text, user_id)
    OpenStruct.new(
      message: { 'text' => message_text },
      source: { 'type' => 'user', 'userId' => user_id },
      replyToken: 'test_reply_token',
      type: 'message'
    )
  end
end
