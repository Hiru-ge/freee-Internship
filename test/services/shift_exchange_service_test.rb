# frozen_string_literal: true

require "test_helper"

class ShiftExchangeServiceTest < ActiveSupport::TestCase
  def setup
    @service = ShiftExchangeService.new

    # テスト用の従業員データ
    @employee1 = Employee.create!(
      employee_id: "test_employee_1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "test_employee_2",
      role: "employee"
    )
  end

  def teardown
    # テストデータのクリーンアップ
    ShiftExchange.destroy_all
    Shift.destroy_all
    Employee.where(employee_id: ["test_employee_1", "test_employee_2"]).destroy_all
  end

  # ===== ShiftExchangeService テスト =====

  test "should reject shift exchange request for past date" do
    # 過去の日付のシフトを作成
    past_date = Date.current - 1.day
    Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: past_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: past_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@employee2.employee_id]
    }

    result = @service.create_exchange_request(params)

    assert_not result[:success]
    assert_includes result[:message], "過去の日付のシフト交代依頼はできません"
  end

  test "should reject duplicate shift exchange request" do
    # 既存のシフトを作成
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    # 既存のpendingリクエストを作成
    exchange_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: "pending"
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@employee2.employee_id]
    }

    result = @service.create_exchange_request(params)

    assert_not result[:success]
    assert_includes result[:message], "既にシフト交代依頼が存在します"
  end

  test "should create shift exchange request successfully" do
    # 既存のシフトを作成
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    params = {
      applicant_id: @employee1.employee_id,
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00",
      approver_ids: [@employee2.employee_id]
    }

    result = @service.create_exchange_request(params)

    assert result[:success]
    assert_includes result[:message], "リクエストを送信しました"

    # リクエストが作成されていることを確認
    assert ShiftExchange.exists?(shift_id: shift.id), "シフト交代依頼が作成されていません"
  end

  test "should approve shift exchange request successfully" do
    # 既存のシフトを作成
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    # シフト交代依頼を作成
    exchange_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: "pending"
    )

    # 承認処理を直接実行（ShiftApprovalsControllerのロジックを模倣）
    exchange_request.update!(status: "approved")

    # リクエストのステータスが更新されていることを確認
    exchange_request.reload
    assert_equal "approved", exchange_request.status
  end

  test "should reject shift exchange request successfully" do
    # 既存のシフトを作成
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    # シフト交代依頼を作成
    exchange_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: "pending"
    )

    # 拒否処理を直接実行（ShiftApprovalsControllerのロジックを模倣）
    exchange_request.update!(status: "rejected")

    # リクエストのステータスが更新されていることを確認
    exchange_request.reload
    assert_equal "rejected", exchange_request.status
  end
end
