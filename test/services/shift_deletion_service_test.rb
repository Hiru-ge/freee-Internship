# frozen_string_literal: true

require "test_helper"

class ShiftDeletionServiceTest < ActiveSupport::TestCase
  def setup
    @service = ShiftDeletionService.new
    @employee = employees(:employee1)
    @owner = employees(:owner)
    @shift = shifts(:shift1)
  end

  # ===== 正常系テスト =====

  test "欠勤申請の作成" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    reason = "体調不良のため"
    result = @service.create_deletion_request(future_shift.id, @employee.employee_id, reason)

    assert result[:success]
    assert_includes result[:message], "欠勤申請を送信しました"
    assert_not_nil result[:shift_deletion]

    deletion = ShiftDeletion.find_by(shift: future_shift)
    assert_not_nil deletion
    assert_equal "pending", deletion.status
    assert_equal reason, deletion.reason
    assert_equal @employee.employee_id, deletion.requester_id

    future_shift.destroy
    deletion.destroy
  end

  test "欠勤申請の承認" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_001_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "pending"
    )

    result = @service.approve_deletion_request(shift_deletion.request_id, @owner.employee_id)

    assert result[:success]
    assert_includes result[:message], "欠勤申請を承認しました"

    assert_raises(ActiveRecord::RecordNotFound) do
      Shift.find(future_shift.id)
    end

    shift_deletion.reload
    assert_equal "approved", shift_deletion.status
    assert_not_nil shift_deletion.responded_at

    shift_deletion.destroy
  end

  test "欠勤申請の拒否" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_002_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "pending"
    )

    result = @service.reject_deletion_request(shift_deletion.request_id, @owner.employee_id)

    assert result[:success]
    assert_includes result[:message], "欠勤申請を拒否しました"

    assert_not_nil Shift.find(future_shift.id)

    shift_deletion.reload
    assert_equal "rejected", shift_deletion.status
    assert_not_nil shift_deletion.responded_at

    future_shift.destroy
    shift_deletion.destroy
  end

  # ===== 異常系テスト =====

  test "過去のシフトの欠勤申請の拒否" do
    past_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current - 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    reason = "体調不良のため"
    result = @service.create_deletion_request(past_shift.id, @employee.employee_id, reason)

    assert_not result[:success]
    assert_includes result[:message], "過去のシフトの欠勤申請はできません"

    deletion = ShiftDeletion.find_by(shift: past_shift)
    assert_nil deletion

    past_shift.destroy
  end

  test "他の従業員のシフトの欠勤申請の拒否" do
    other_employee = Employee.create!(
      employee_id: "999_#{Time.current.to_i}",
      role: "employee"
    )

    other_shift = Shift.create!(
      employee: other_employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    reason = "体調不良のため"
    result = @service.create_deletion_request(other_shift.id, @employee.employee_id, reason)

    assert_not result[:success]
    assert_includes result[:message], "自分のシフトのみ欠勤申請が可能です"

    deletion = ShiftDeletion.find_by(shift: other_shift)
    assert_nil deletion

    other_shift.destroy
    other_employee.destroy
  end

  test "重複した欠勤申請の拒否" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    reason1 = "体調不良のため"
    result1 = @service.create_deletion_request(future_shift.id, @employee.employee_id, reason1)
    assert result1[:success]

    reason2 = "急用ができたため"
    result2 = @service.create_deletion_request(future_shift.id, @employee.employee_id, reason2)

    assert_not result2[:success]
    assert_includes result2[:message], "既に申請済みです"

    deletions = ShiftDeletion.where(shift: future_shift)
    assert_equal 1, deletions.count

    future_shift.destroy
    deletions.destroy_all
  end

  test "存在しないリクエストの承認処理" do
    result = @service.approve_deletion_request("non_existent_id", @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "リクエストが見つかりません"
  end

  test "存在しないリクエストの拒否処理" do
    result = @service.reject_deletion_request("non_existent_id", @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "リクエストが見つかりません"
  end

  test "既に処理済みのリクエストの承認処理" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_003_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "approved",
      responded_at: Time.current
    )

    result = @service.approve_deletion_request(shift_deletion.request_id, @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "既に処理済みです"

    future_shift.destroy
    shift_deletion.destroy
  end

  test "既に処理済みのリクエストの拒否処理" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_004_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "rejected",
      responded_at: Time.current
    )

    result = @service.reject_deletion_request(shift_deletion.request_id, @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "既に処理済みです"

    future_shift.destroy
    shift_deletion.destroy
  end

  test "無効なシフトIDでの申請作成エラー" do
    result = @service.create_deletion_request(99999, @employee.employee_id, "体調不良のため")

    assert_not result[:success]
    assert_includes result[:message], "欠勤申請の送信に失敗しました"
  end

  test "承認処理中のエラー" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_005_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "pending"
    )

    future_shift.destroy

    result = @service.approve_deletion_request(shift_deletion.request_id, @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "承認処理に失敗しました"

    shift_deletion.destroy
  end

  test "拒否処理中のエラー" do
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_006_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "pending"
    )

    request_id = shift_deletion.request_id
    shift_deletion.destroy

    result = @service.reject_deletion_request(request_id, @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "リクエストが見つかりません"

    future_shift.destroy
  end

end
