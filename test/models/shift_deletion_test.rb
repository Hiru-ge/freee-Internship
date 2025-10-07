# frozen_string_literal: true

require "test_helper"

class ShiftDeletionTest < ActiveSupport::TestCase
  def setup
    # テスト用の従業員データ
    @employee1 = Employee.create!(
      employee_id: "test_employee_1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "test_employee_2",
      role: "employee"
    )
    @owner = Employee.create!(
      employee_id: "test_owner",
      role: "owner"
    )
  end

  def teardown
    # テストデータのクリーンアップ（外部キー制約を考慮した順序）
    ActiveRecord::Base.connection.disable_referential_integrity do
      ShiftDeletion.delete_all
      Shift.delete_all
      Employee.where(employee_id: ["test_employee_1", "test_employee_2", "test_owner"]).delete_all
    end
  end

  # ===== バリデーションテスト =====

  test "有効なShiftDeletionの作成" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift_deletion = ShiftDeletion.new(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "pending"
    )

    assert shift_deletion.valid?
  end

  test "必須項目のバリデーション" do
    shift_deletion = ShiftDeletion.new

    assert_not shift_deletion.valid?
    assert shift_deletion.errors[:request_id].present?
    assert shift_deletion.errors[:requester_id].present?
    assert shift_deletion.errors[:shift_id].present?
    assert shift_deletion.errors[:reason].present?
    # statusはデフォルト値があるため、バリデーションエラーは発生しない
  end

  # ===== クラスメソッドテスト =====

  test "create_request_for - 正常な欠勤申請作成" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    result = ShiftDeletion.create_request_for(
      shift_id: future_shift.id,
      requester_id: @employee1.employee_id,
      reason: "体調不良のため"
    )

    assert_instance_of ShiftDeletion::DeletionResult, result
    assert_includes result.success_message, "欠勤申請を送信しました"

    created_request = result.request
    assert_equal @employee1.employee_id, created_request.requester_id
    assert_equal future_shift.id, created_request.shift_id
    assert_equal "体調不良のため", created_request.reason
    assert_equal "pending", created_request.status
  end

  test "create_request_for - 必須項目不足でのエラー" do
    assert_raises(ShiftDeletion::ValidationError, "必須項目が不足しています") do
      ShiftDeletion.create_request_for(
        shift_id: "",
        requester_id: @employee1.employee_id,
        reason: "体調不良のため"
      )
    end
  end

  test "create_request_for - 存在しないシフトでのエラー" do
    assert_raises(ShiftDeletion::ValidationError, "シフトが見つかりません") do
      ShiftDeletion.create_request_for(
        shift_id: 99999,
        requester_id: @employee1.employee_id,
        reason: "体調不良のため"
      )
    end
  end

  test "create_request_for - 他人のシフトでの権限エラー" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    assert_raises(ShiftDeletion::AuthorizationError, "自分のシフトのみ欠勤申請が可能です") do
      ShiftDeletion.create_request_for(
        shift_id: future_shift.id,
        requester_id: @employee2.employee_id,
        reason: "体調不良のため"
      )
    end
  end

  test "create_request_for - 過去のシフトでのエラー" do
    past_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current - 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    assert_raises(ShiftDeletion::ValidationError, "過去のシフトの欠勤申請はできません") do
      ShiftDeletion.create_request_for(
        shift_id: past_shift.id,
        requester_id: @employee1.employee_id,
        reason: "体調不良のため"
      )
    end
  end

  test "create_request_for - 重複申請でのエラー" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    # 最初の申請
    ShiftDeletion.create_request_for(
      shift_id: future_shift.id,
      requester_id: @employee1.employee_id,
      reason: "体調不良のため"
    )

    # 重複申請
    assert_raises(ShiftDeletion::ValidationError, "このシフトは既に申請済みです") do
      ShiftDeletion.create_request_for(
        shift_id: future_shift.id,
        requester_id: @employee1.employee_id,
        reason: "急用ができたため"
      )
    end
  end

  # ===== インスタンスメソッドテスト =====

  test "approve_by! - 正常な承認処理" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "pending"
    )

    message = shift_deletion.approve_by!(@owner.employee_id)

    assert_equal "approved", shift_deletion.reload.status
    assert_not_nil shift_deletion.responded_at
    assert_equal "欠勤申請を承認しました", message

    # シフトが削除されていることを確認
    assert_raises(ActiveRecord::RecordNotFound) do
      Shift.find(future_shift.id)
    end
  end

  test "approve_by! - 既に処理済みでのエラー" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "approved",
      responded_at: Time.current
    )

    assert_raises(ShiftDeletion::ValidationError, "このリクエストは既に処理済みです") do
      shift_deletion.approve_by!(@owner.employee_id)
    end
  end

  test "reject_by! - 正常な拒否処理" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "pending"
    )

    message = shift_deletion.reject_by!(@owner.employee_id)

    assert_equal "rejected", shift_deletion.reload.status
    assert_not_nil shift_deletion.responded_at
    assert_equal "欠勤申請を拒否しました", message

    # シフトが残っていることを確認
    assert_not_nil Shift.find(future_shift.id)
  end

  test "reject_by! - 既に処理済みでのエラー" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    shift_deletion = ShiftDeletion.create!(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "rejected",
      responded_at: Time.current
    )

    assert_raises(ShiftDeletion::ValidationError, "このリクエストは既に処理済みです") do
      shift_deletion.reject_by!(@owner.employee_id)
    end
  end

  # ===== スコープテスト =====

  test "スコープの動作確認" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    pending_request = ShiftDeletion.create!(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "pending"
    )

    approved_request = ShiftDeletion.create!(
      request_id: "DELETION_002",
      requester_id: @employee2.employee_id,
      shift_id: future_shift.id,
      reason: "急用のため",
      status: "approved"
    )

    assert_includes ShiftDeletion.pending, pending_request
    assert_not_includes ShiftDeletion.pending, approved_request

    assert_includes ShiftDeletion.approved, approved_request
    assert_not_includes ShiftDeletion.approved, pending_request

    assert_includes ShiftDeletion.for_requester(@employee1.employee_id), pending_request
    assert_not_includes ShiftDeletion.for_requester(@employee1.employee_id), approved_request
  end

  # ===== ヘルパーメソッドテスト =====

  test "ステータス確認メソッド" do
    future_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00:00"),
      end_time: Time.zone.parse("18:00:00")
    )

    pending_request = ShiftDeletion.create!(
      request_id: "DELETION_001",
      requester_id: @employee1.employee_id,
      shift_id: future_shift.id,
      reason: "体調不良のため",
      status: "pending"
    )

    assert pending_request.pending?
    assert_not pending_request.approved?
    assert_not pending_request.rejected?

    pending_request.update!(status: "approved")
    assert_not pending_request.pending?
    assert pending_request.approved?
    assert_not pending_request.rejected?

    pending_request.update!(status: "rejected")
    assert_not pending_request.pending?
    assert_not pending_request.approved?
    assert pending_request.rejected?
  end
end
