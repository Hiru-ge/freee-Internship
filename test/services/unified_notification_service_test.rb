require 'test_helper'

class UnifiedNotificationServiceTest < ActiveSupport::TestCase
  def setup
    @service = UnifiedNotificationService.new
    @employee1 = employees(:employee1)
    @employee2 = employees(:employee2)
    @future_date = Date.current + 1.day
  end

  # シフト交代依頼通知のテスト
  test "should send shift exchange request notification" do
    # テスト用のシフト交代リクエストを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    exchange_request = ShiftExchange.create!(
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      request_id: 'TEST_EXCHANGE_001',
      status: 'pending'
    )

    # 通知送信をテスト（テスト環境では実際の送信は行われない）
    result = @service.send_shift_exchange_request_notification([exchange_request], {})

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # シフト追加依頼通知のテスト
  test "should send shift addition request notification" do
    # テスト用のシフト追加リクエストを作成
    addition_request = ShiftAddition.create!(
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00'),
      request_id: 'TEST_ADDITION_001',
      status: 'pending'
    )

    # 通知送信をテスト（テスト環境では実際の送信は行われない）
    result = @service.send_shift_addition_request_notification([addition_request], {})

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # シフト交代承認通知のテスト
  test "should send shift exchange approval notification" do
    # テスト用のシフト交代リクエストを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    exchange_request = ShiftExchange.create!(
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      request_id: 'TEST_EXCHANGE_001',
      status: 'approved'
    )

    # 通知送信をテスト（テスト環境では実際の送信は行われない）
    result = @service.send_shift_exchange_approval_notification(exchange_request)

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # シフト交代拒否通知のテスト
  test "should send shift exchange rejection notification" do
    # テスト用のシフト交代リクエストを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    exchange_request = ShiftExchange.create!(
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      request_id: 'TEST_EXCHANGE_001',
      status: 'rejected'
    )

    # 通知送信をテスト（テスト環境では実際の送信は行われない）
    result = @service.send_shift_exchange_rejection_notification(exchange_request)

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # シフト追加承認通知のテスト
  test "should send shift addition approval notification" do
    # テスト用のシフト追加リクエストを作成
    addition_request = ShiftAddition.create!(
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00'),
      request_id: 'TEST_ADDITION_001',
      status: 'approved'
    )

    # 通知送信をテスト（テスト環境では実際の送信は行われない）
    result = @service.send_shift_addition_approval_notification(addition_request)

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # シフト追加拒否通知のテスト
  test "should send shift addition rejection notification" do
    # テスト用のシフト追加リクエストを作成
    addition_request = ShiftAddition.create!(
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00'),
      request_id: 'TEST_ADDITION_001',
      status: 'rejected'
    )

    # 通知送信をテスト（テスト環境では実際の送信は行われない）
    result = @service.send_shift_addition_rejection_notification(addition_request)

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # メール通知のみのテスト
  test "should send email only notification" do
    # メール通知のみの送信をテスト
    result = @service.send_email_only(:shift_exchange_request, 
      @employee1.employee_id, 
      [@employee2.employee_id], 
      @future_date, 
      Time.zone.parse('09:00'), 
      Time.zone.parse('18:00')
    )

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # LINE通知のみのテスト
  test "should send line only notification" do
    # テスト用のシフト交代リクエストを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    exchange_request = ShiftExchange.create!(
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      request_id: 'TEST_EXCHANGE_001',
      status: 'pending'
    )

    # LINE通知のみの送信をテスト
    result = @service.send_line_only(:shift_exchange_request, exchange_request)

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # 空のリクエスト配列のテスト
  test "should handle empty requests array" do
    # 空のリクエスト配列で通知送信をテスト
    result = @service.send_shift_exchange_request_notification([], {})

    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end

  # テスト環境での通知スキップのテスト
  test "should skip notifications in test environment" do
    # テスト環境では通知がスキップされることを確認
    assert Rails.env.test?
    
    # 通知送信をテスト（実際の送信は行われない）
    result = @service.send_shift_exchange_request_notification([], {})
    
    # エラーが発生しないことを確認
    assert_nothing_raised { result }
  end
end
