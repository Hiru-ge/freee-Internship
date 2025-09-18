require 'test_helper'

class ShiftExchangeServiceTest < ActiveSupport::TestCase
  def setup
    @employee1 = Employee.create!(
      employee_id: "1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "2",
      role: "employee"
    )
    @employee3 = Employee.create!(
      employee_id: "3",
      role: "employee"
    )
    @shift_date = Date.current
    @past_date = Date.current - 1.day
    @future_date = Date.current + 1.day
  end

  # 過去日付チェックのテスト
  test "should reject shift exchange request for past date" do
    # 過去の日付のシフトを作成
    past_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @past_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: @past_date.strftime('%Y-%m-%d'),
      start_time: '09:00',
      end_time: '18:00',
      approver_ids: [@employee2.employee_id]
    }

    service = ShiftExchangeService.new
    result = service.create_exchange_request(params)

    assert_not result[:success]
    assert_includes result[:message], "過去の日付のシフト交代依頼はできません"
  end

  # 重複リクエストチェックのテスト
  test "should reject duplicate shift exchange request" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # 既存のpendingリクエストを作成
    existing_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: @future_date.strftime('%Y-%m-%d'),
      start_time: '09:00',
      end_time: '18:00',
      approver_ids: [@employee2.employee_id]
    }

    service = ShiftExchangeService.new
    result = service.create_exchange_request(params)

    assert_not result[:success]
    assert_includes result[:message], "既にシフト交代依頼が存在します"
  end

  # 複数承認者への重複チェックのテスト
  test "should reject when some approvers have duplicate requests" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # 既存のpendingリクエストを作成（employee2のみ）
    existing_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: @future_date.strftime('%Y-%m-%d'),
      start_time: '09:00',
      end_time: '18:00',
      approver_ids: [@employee2.employee_id, @employee3.employee_id]
    }

    service = ShiftExchangeService.new
    result = service.create_exchange_request(params)

    assert_not result[:success]
    assert_includes result[:message], "既にシフト交代依頼が存在します"
  end

  # 正常なシフト交代依頼作成のテスト
  test "should create shift exchange request successfully" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: @future_date.strftime('%Y-%m-%d'),
      start_time: '09:00',
      end_time: '18:00',
      approver_ids: [@employee2.employee_id, @employee3.employee_id]
    }

    service = ShiftExchangeService.new
    result = service.create_exchange_request(params)

    assert result[:success]
    assert_equal 2, result[:created_requests].length
    assert_equal "リクエストを送信しました。承認をお待ちください。", result[:message]

    # 作成されたリクエストを確認
    created_requests = result[:created_requests]
    approver_ids = created_requests.map(&:approver_id)
    assert_includes approver_ids, @employee2.employee_id
    assert_includes approver_ids, @employee3.employee_id
  end

  # 承認処理の排他制御のテスト
  test "should reject other requests when one is approved" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # 複数の承認者へのリクエストを作成
    request1 = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    request2 = ShiftExchange.create!(
      request_id: "EXCHANGE_002",
      requester_id: @employee1.employee_id,
      approver_id: @employee3.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    # employee2が承認
    service = ShiftExchangeService.new
    result = service.approve_exchange_request(request1.request_id, @employee2.employee_id)

    assert result[:success]

    # request2が自動的に拒否されているか確認
    request2.reload
    assert_equal 'rejected', request2.status
  end

  # 権限チェックのテスト
  test "should reject approval by unauthorized approver" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # リクエストを作成
    request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    # employee3（権限なし）が承認を試行
    service = ShiftExchangeService.new
    result = service.approve_exchange_request(request.request_id, @employee3.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "このリクエストを承認する権限がありません"
  end

  # 拒否処理のテスト
  test "should reject shift exchange request successfully" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # リクエストを作成
    request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    # employee2が拒否
    service = ShiftExchangeService.new
    result = service.reject_exchange_request(request.request_id, @employee2.employee_id)

    assert result[:success]
    assert_includes result[:message], "シフト交代リクエストを拒否しました"

    # リクエストのステータスが拒否になっているか確認
    request.reload
    assert_equal 'rejected', request.status
  end

  # パラメータ検証のテスト
  test "should reject request with missing parameters" do
    params = {
      applicant_id: @employee1.employee_id,
      shift_date: @future_date.strftime('%Y-%m-%d'),
      start_time: '09:00',
      end_time: '18:00',
      approver_ids: [] # 空の配列
    }

    service = ShiftExchangeService.new
    result = service.create_exchange_request(params)

    assert_not result[:success]
    assert_includes result[:message], "必須項目が不足しています"
  end

  # 状況確認のテスト
  test "should get exchange status successfully" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # 複数のリクエストを作成
    ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    ShiftExchange.create!(
      request_id: "EXCHANGE_002",
      requester_id: @employee1.employee_id,
      approver_id: @employee3.employee_id,
      shift_id: shift.id,
      status: 'approved'
    )

    service = ShiftExchangeService.new
    result = service.get_exchange_status(@employee1.employee_id)

    assert result[:success]
    assert_equal 1, result[:status_counts][:pending]
    assert_equal 1, result[:status_counts][:approved]
  end

  # キャンセル処理のテスト
  test "should cancel shift exchange request successfully" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # リクエストを作成
    request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    # employee1がキャンセル
    service = ShiftExchangeService.new
    result = service.cancel_exchange_request(request.request_id, @employee1.employee_id)

    assert result[:success]
    assert_includes result[:message], "シフト交代リクエストをキャンセルしました"

    # リクエストのステータスがキャンセルになっているか確認
    request.reload
    assert_equal 'cancelled', request.status
  end

  # 通知処理のテスト
  test "should send approval notification successfully" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # リクエストを作成
    request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    service = ShiftExchangeService.new
    
    # テスト環境では通知がスキップされることを確認
    result = service.send(:send_approval_notification, request)
    assert_nil result
  end

  test "should send rejection notification successfully" do
    # 既存のシフトを作成
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @future_date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )

    # リクエストを作成
    request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: 'pending'
    )

    service = ShiftExchangeService.new
    
    # テスト環境では通知がスキップされることを確認
    result = service.send(:send_rejection_notification, request)
    assert_nil result
  end

  test "should skip notification when shift is nil" do
    # シフトが削除されたリクエストを作成
    request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: nil,
      status: 'pending'
    )

    service = ShiftExchangeService.new
    
    # シフトがnilの場合は通知がスキップされることを確認
    result = service.send(:send_approval_notification, request)
    assert_nil result
  end
end
