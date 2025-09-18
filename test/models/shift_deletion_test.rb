# frozen_string_literal: true

require "test_helper"

class ShiftDeletionTest < ActiveSupport::TestCase
  def setup
    @employee = Employee.create!(
      employee_id: "emp_001",
      role: "employee"
    )
    @shift = Shift.create!(
      employee_id: @employee.employee_id,
      shift_date: Date.current,
      start_time: Time.parse("09:00"),
      end_time: Time.parse("17:00")
    )
  end

  test "有効な属性でShiftDeletionが作成できること" do
    shift_deletion = ShiftDeletion.new(
      request_id: "test_request_123",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )
    assert shift_deletion.valid?
  end

  test "request_idが必須であること" do
    shift_deletion = ShiftDeletion.new(
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )
    assert_not shift_deletion.valid?
    assert_includes shift_deletion.errors[:request_id], "can't be blank"
  end

  test "request_idが一意であること" do
    ShiftDeletion.create!(
      request_id: "test_request_123",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    duplicate = ShiftDeletion.new(
      request_id: "test_request_123",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:request_id], "has already been taken"
  end

  test "requester_idが必須であること" do
    shift_deletion = ShiftDeletion.new(
      request_id: "test_request_123",
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )
    assert_not shift_deletion.valid?
    assert_includes shift_deletion.errors[:requester_id], "can't be blank"
  end

  test "shift_idが必須であること" do
    shift_deletion = ShiftDeletion.new(
      request_id: "test_request_123",
      requester_id: @employee.employee_id,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )
    assert_not shift_deletion.valid?
    assert_includes shift_deletion.errors[:shift_id], "can't be blank"
  end

  test "reasonが必須であること" do
    shift_deletion = ShiftDeletion.new(
      request_id: "test_request_123",
      requester_id: @employee.employee_id,
      shift: @shift,
      status: "pending"
    )
    assert_not shift_deletion.valid?
    assert_includes shift_deletion.errors[:reason], "can't be blank"
  end

  test "statusが必須であること" do
    shift_deletion = ShiftDeletion.new(
      request_id: "test_request_123",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: nil
    )
    assert_not shift_deletion.valid?
    assert_includes shift_deletion.errors[:status], "can't be blank"
  end

  test "statusが有効な値であること" do
    valid_statuses = %w[pending approved rejected]
    valid_statuses.each do |status|
      shift_deletion = ShiftDeletion.new(
        request_id: "test_request_#{status}",
        requester_id: @employee.employee_id,
        shift: @shift,
        reason: "体調不良のため欠勤します",
        status: status
      )
      assert shift_deletion.valid?, "#{status} should be valid"
    end
  end

  test "statusが無効な値の場合エラーになること" do
    shift_deletion = ShiftDeletion.new(
      request_id: "test_request_invalid",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "invalid"
    )
    assert_not shift_deletion.valid?
    assert_includes shift_deletion.errors[:status], "is not included in the list"
  end

  test "pendingスコープが正しく動作すること" do
    pending_deletion = ShiftDeletion.create!(
      request_id: "pending_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    approved_deletion = ShiftDeletion.create!(
      request_id: "approved_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "approved"
    )

    assert_includes ShiftDeletion.pending, pending_deletion
    assert_not_includes ShiftDeletion.pending, approved_deletion
  end

  test "approvedスコープが正しく動作すること" do
    pending_deletion = ShiftDeletion.create!(
      request_id: "pending_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    approved_deletion = ShiftDeletion.create!(
      request_id: "approved_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "approved"
    )

    assert_includes ShiftDeletion.approved, approved_deletion
    assert_not_includes ShiftDeletion.approved, pending_deletion
  end

  test "rejectedスコープが正しく動作すること" do
    pending_deletion = ShiftDeletion.create!(
      request_id: "pending_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    rejected_deletion = ShiftDeletion.create!(
      request_id: "rejected_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "rejected"
    )

    assert_includes ShiftDeletion.rejected, rejected_deletion
    assert_not_includes ShiftDeletion.rejected, pending_deletion
  end

  test "for_requesterスコープが正しく動作すること" do
    other_employee = Employee.create!(
      employee_id: "emp_002",
      role: "employee"
    )

    deletion1 = ShiftDeletion.create!(
      request_id: "request_1",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    deletion2 = ShiftDeletion.create!(
      request_id: "request_2",
      requester_id: other_employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    result = ShiftDeletion.for_requester(@employee.employee_id)
    assert_includes result, deletion1
    assert_not_includes result, deletion2
  end

  test "shiftと関連付けられること" do
    shift_deletion = ShiftDeletion.create!(
      request_id: "test_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    assert_equal @shift, shift_deletion.shift
  end

  test "pending?メソッドが正しく動作すること" do
    shift_deletion = ShiftDeletion.create!(
      request_id: "test_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    assert shift_deletion.pending?

    shift_deletion.update!(status: "approved")
    assert_not shift_deletion.pending?
  end

  test "approved?メソッドが正しく動作すること" do
    shift_deletion = ShiftDeletion.create!(
      request_id: "test_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    assert_not shift_deletion.approved?

    shift_deletion.update!(status: "approved")
    assert shift_deletion.approved?
  end

  test "rejected?メソッドが正しく動作すること" do
    shift_deletion = ShiftDeletion.create!(
      request_id: "test_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    assert_not shift_deletion.rejected?

    shift_deletion.update!(status: "rejected")
    assert shift_deletion.rejected?
  end

  test "approve!メソッドが正しく動作すること" do
    shift_deletion = ShiftDeletion.create!(
      request_id: "test_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    freeze_time do
      shift_deletion.approve!
      assert_equal "approved", shift_deletion.status
      assert_equal Time.current, shift_deletion.responded_at
    end
  end

  test "reject!メソッドが正しく動作すること" do
    shift_deletion = ShiftDeletion.create!(
      request_id: "test_request",
      requester_id: @employee.employee_id,
      shift: @shift,
      reason: "体調不良のため欠勤します",
      status: "pending"
    )

    freeze_time do
      shift_deletion.reject!
      assert_equal "rejected", shift_deletion.status
      assert_equal Time.current, shift_deletion.responded_at
    end
  end
end
