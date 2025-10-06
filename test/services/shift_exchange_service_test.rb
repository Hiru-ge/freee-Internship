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

  # ===== 正常系テスト =====

  test "シフト交代依頼の作成" do
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
    assert ShiftExchange.exists?(shift_id: shift.id)
  end

  test "シフト交代依頼の承認" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    exchange_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: "pending"
    )

    exchange_request.update!(status: "approved")
    exchange_request.reload
    assert_equal "approved", exchange_request.status
  end

  test "シフト交代依頼の拒否" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    exchange_request = ShiftExchange.create!(
      request_id: "EXCHANGE_001",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: shift.id,
      status: "pending"
    )

    exchange_request.update!(status: "rejected")
    exchange_request.reload
    assert_equal "rejected", exchange_request.status
  end

  # ===== 異常系テスト =====

  test "過去の日付のシフト交代依頼の拒否" do
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

  test "重複したシフト交代依頼の拒否" do
    future_date = Date.current + 1.day
    shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )

    ShiftExchange.create!(
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
    assert_includes result[:message], "選択された従業員は全員、既に同じ時間帯のシフト交代依頼が存在します"
  end
end
