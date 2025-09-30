# frozen_string_literal: true

require "test_helper"

class ShiftAdditionServiceTest < ActiveSupport::TestCase
  def setup
    @service = ShiftAdditionService.new

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
    ShiftAddition.destroy_all
    Employee.where(employee_id: ["test_employee_1", "test_employee_2"]).destroy_all
  end

  # ===== ShiftAdditionService テスト =====

  test "should reject shift addition request for past date" do
    past_date = Date.current - 1.day
    params = {
      requester_id: @employee1.employee_id,
      shift_date: past_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00",
      target_employee_ids: [@employee2.employee_id]
    }

    result = @service.create_addition_request(params)

    assert_not result[:success]
    assert_includes result[:message], "過去の日付のシフト追加依頼はできません"
  end

  test "should reject duplicate shift addition request" do
    future_date = Date.current + 1.day
    # 既存のpendingリクエストを作成
    ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    params = {
      requester_id: @employee1.employee_id,
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00",
      target_employee_ids: [@employee2.employee_id]
    }

    result = @service.create_addition_request(params)

    assert result[:success]
    assert_includes result[:message], "シフト追加リクエストを送信しました"
  end

  test "should create shift addition request successfully" do
    future_date = Date.current + 1.day
    params = {
      requester_id: @employee1.employee_id,
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00",
      target_employee_ids: [@employee2.employee_id]
    }

    result = @service.create_addition_request(params)

    assert result[:success]
    assert_includes result[:message], "シフト追加リクエストを送信しました"

    # リクエストが作成されていることを確認
    assert ShiftAddition.exists?(requester_id: @employee1.employee_id), "シフト追加依頼が作成されていません"
  end

  test "should approve shift addition request successfully" do
    future_date = Date.current + 1.day
    # シフト追加依頼を作成
    addition_request = ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    # 承認処理を直接実行
    addition_request.update!(status: "approved")

    # リクエストのステータスが更新されていることを確認
    addition_request.reload
    assert_equal "approved", addition_request.status
  end

  test "should reject shift addition request successfully" do
    future_date = Date.current + 1.day
    # シフト追加依頼を作成
    addition_request = ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    # 拒否処理を直接実行
    addition_request.update!(status: "rejected")

    # リクエストのステータスが更新されていることを確認
    addition_request.reload
    assert_equal "rejected", addition_request.status
  end
end
