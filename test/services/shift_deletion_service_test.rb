# frozen_string_literal: true

require "test_helper"

class ShiftDeletionServiceTest < ActiveSupport::TestCase
  def setup
    @service = ShiftDeletionService.new
    @employee = employees(:employee1)
    @owner = employees(:owner)
    @shift = shifts(:shift1)
  end

  test "should create deletion request successfully" do
    # 未来のシフトを作成
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

    # データベースに保存されていることを確認
    deletion = ShiftDeletion.find_by(shift: future_shift)
    assert_not_nil deletion
    assert_equal "pending", deletion.status
    assert_equal reason, deletion.reason
    assert_equal @employee.employee_id, deletion.requester_id

    # クリーンアップ
    future_shift.destroy
    deletion.destroy
  end

  test "should reject deletion request for past shift" do
    # 過去のシフトを作成
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

    # データベースに保存されていないことを確認
    deletion = ShiftDeletion.find_by(shift: past_shift)
    assert_nil deletion

    # クリーンアップ
    past_shift.destroy
  end

  test "should reject deletion request for other employee's shift" do
    # 他の従業員のシフトを作成
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

    # データベースに保存されていないことを確認
    deletion = ShiftDeletion.find_by(shift: other_shift)
    assert_nil deletion

    # クリーンアップ
    other_shift.destroy
    other_employee.destroy
  end

  test "should reject duplicate deletion request" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 最初の申請を作成
    reason1 = "体調不良のため"
    result1 = @service.create_deletion_request(future_shift.id, @employee.employee_id, reason1)
    assert result1[:success]

    # 重複申請を試行
    reason2 = "急用ができたため"
    result2 = @service.create_deletion_request(future_shift.id, @employee.employee_id, reason2)

    assert_not result2[:success]
    assert_includes result2[:message], "既に申請済みです"

    # データベースに1件のみ保存されていることを確認
    deletions = ShiftDeletion.where(shift: future_shift)
    assert_equal 1, deletions.count

    # クリーンアップ
    future_shift.destroy
    deletions.destroy_all
  end

  test "should approve deletion request successfully" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 欠勤申請を作成
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

    # シフトが削除されていることを確認
    assert_raises(ActiveRecord::RecordNotFound) do
      Shift.find(future_shift.id)
    end

    # 申請が承認されていることを確認
    shift_deletion.reload
    assert_equal "approved", shift_deletion.status
    assert_not_nil shift_deletion.responded_at

    # クリーンアップ
    shift_deletion.destroy
  end

  test "should reject deletion request successfully" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 欠勤申請を作成
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

    # シフトが削除されていないことを確認
    assert_not_nil Shift.find(future_shift.id)

    # 申請が拒否されていることを確認
    shift_deletion.reload
    assert_equal "rejected", shift_deletion.status
    assert_not_nil shift_deletion.responded_at

    # クリーンアップ
    future_shift.destroy
    shift_deletion.destroy
  end

  test "should handle approval of non-existent request" do
    result = @service.approve_deletion_request("non_existent_id", @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "リクエストが見つかりません"
  end

  test "should handle rejection of non-existent request" do
    result = @service.reject_deletion_request("non_existent_id", @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "リクエストが見つかりません"
  end

  test "should handle approval of already processed request" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 既に処理済みの欠勤申請を作成
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

    # クリーンアップ
    future_shift.destroy
    shift_deletion.destroy
  end

  test "should handle rejection of already processed request" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 既に処理済みの欠勤申請を作成
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

    # クリーンアップ
    future_shift.destroy
    shift_deletion.destroy
  end

  test "should handle error during deletion request creation" do
    # 無効なシフトIDで申請を作成
    result = @service.create_deletion_request(99999, @employee.employee_id, "体調不良のため")

    assert_not result[:success]
    assert_includes result[:message], "欠勤申請の送信に失敗しました"
  end

  test "should handle error during approval" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 欠勤申請を作成
    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_005_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "pending"
    )

    # シフトを削除してエラーを発生させる
    future_shift.destroy

    result = @service.approve_deletion_request(shift_deletion.request_id, @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "承認処理に失敗しました"

    # クリーンアップ
    shift_deletion.destroy
  end

  test "should handle error during rejection" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # 欠勤申請を作成
    shift_deletion = ShiftDeletion.create!(
      request_id: "deletion_test_006_#{Time.current.to_i}",
      requester_id: @employee.employee_id,
      shift: future_shift,
      reason: "体調不良のため",
      status: "pending"
    )

    # 申請を削除してエラーを発生させる
    request_id = shift_deletion.request_id
    shift_deletion.destroy

    result = @service.reject_deletion_request(request_id, @owner.employee_id)

    assert_not result[:success]
    assert_includes result[:message], "リクエストが見つかりません"

    # クリーンアップ
    future_shift.destroy
  end

end
