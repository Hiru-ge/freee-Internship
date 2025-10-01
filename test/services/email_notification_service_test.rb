# frozen_string_literal: true

require "test_helper"

class EmailNotificationServiceTest < ActiveSupport::TestCase
  def setup
    @service = EmailNotificationService.new
    @line_user_id = "test_line_user_id"
    @employee_id = "test_employee_id"
  end

  # ===== シフト交代通知テスト =====

  test "シフト交代依頼通知の送信" do
    # テスト環境では通知は送信されないが、メソッドの動作をテスト
    requests = []
    params = {}

    result = @service.send_shift_exchange_request_notification(requests, params)
    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result
    # エラーが発生しないことを確認
    assert_nothing_raised { @service.send_shift_exchange_request_notification(requests, params) }
  end

  test "シフト交代承認通知の送信" do
    # テスト環境では通知は送信されないが、メソッドの動作をテスト
    exchange_request = mock_exchange_request

    result = @service.send_shift_exchange_approval_notification(exchange_request)
    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result
    # エラーが発生しないことを確認
    assert_nothing_raised { @service.send_shift_exchange_approval_notification(exchange_request) }
  end

  test "シフト交代拒否通知の送信" do
    # テスト環境では通知は送信されないが、メソッドの動作をテスト
    exchange_request = mock_exchange_request

    result = @service.send_shift_exchange_rejection_notification(exchange_request)
    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result
    # エラーが発生しないことを確認
    assert_nothing_raised { @service.send_shift_exchange_rejection_notification(exchange_request) }
  end

  # ===== シフト追加通知テスト =====

  test "シフト追加依頼通知の送信" do
    # テスト環境では通知は送信されないが、メソッドの動作をテスト
    requests = []
    params = {}

    result = @service.send_shift_addition_request_notification(requests, params)
    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result
    # エラーが発生しないことを確認
    assert_nothing_raised { @service.send_shift_addition_request_notification(requests, params) }
  end

  test "シフト追加承認通知の送信" do
    # テスト環境では通知は送信されないが、メソッドの動作をテスト
    addition_request = mock_addition_request

    result = @service.send_shift_addition_approval_notification(addition_request)
    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result
    # エラーが発生しないことを確認
    assert_nothing_raised { @service.send_shift_addition_approval_notification(addition_request) }
  end

  test "シフト追加拒否通知の送信" do
    # テスト環境では通知は送信されないが、メソッドの動作をテスト
    addition_request = mock_addition_request

    result = @service.send_shift_addition_rejection_notification(addition_request)
    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result
    # エラーが発生しないことを確認
    assert_nothing_raised { @service.send_shift_addition_rejection_notification(addition_request) }
  end

  # ===== 欠勤申請通知テスト =====

  test "欠勤申請通知の送信" do
    # テスト用の欠勤申請を作成
    employee = Employee.create!(employee_id: "test_employee", role: "employee")
    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )
    deletion_request = ShiftDeletion.create!(
      request_id: "test_deletion_request",
      requester_id: employee.employee_id,
      shift: shift,
      reason: "体調不良",
      status: "pending"
    )

    # 通知送信を実行
    result = @service.send_shift_deletion_request_notification(deletion_request)

    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result, "テスト環境では通知は送信されない"

    # クリーンアップ
    deletion_request.destroy
    shift.destroy
    employee.destroy
  end

  test "欠勤申請承認通知の送信" do
    # テスト用の欠勤申請を作成
    employee = Employee.create!(employee_id: "test_employee", role: "employee")
    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )
    deletion_request = ShiftDeletion.create!(
      request_id: "test_deletion_request",
      requester_id: employee.employee_id,
      shift: shift,
      reason: "体調不良",
      status: "approved"
    )

    # 通知送信を実行
    result = @service.send_shift_deletion_approval_notification(deletion_request)

    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result, "テスト環境では通知は送信されない"

    # クリーンアップ
    deletion_request.destroy
    shift.destroy
    employee.destroy
  end

  test "欠勤申請拒否通知の送信" do
    # テスト用の欠勤申請を作成
    employee = Employee.create!(employee_id: "test_employee", role: "employee")
    shift = Shift.create!(
      employee_id: employee.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )
    deletion_request = ShiftDeletion.create!(
      request_id: "test_deletion_request",
      requester_id: employee.employee_id,
      shift: shift,
      reason: "体調不良",
      status: "rejected"
    )

    # 通知送信を実行
    result = @service.send_shift_deletion_rejection_notification(deletion_request)

    # テスト環境ではnilが返されるが、メソッドが正常に実行されることを確認
    assert_nil result, "テスト環境では通知は送信されない"

    # クリーンアップ
    deletion_request.destroy
    shift.destroy
    employee.destroy
  end

  # ===== メール通知テスト =====


  private

  def mock_exchange_request
    mock_shift = Struct.new(:shift_date, :start_time, :end_time).new(
      Date.current,
      Time.current,
      Time.current + 1.hour
    )

    mock_request = Struct.new(:requester_id, :approver_id, :shift_id, :shift).new(
      @employee_id,
      @employee_id,
      1,
      mock_shift
    )

    mock_request
  end

  def mock_addition_request
    mock_request = Struct.new(:requester_id, :target_employee_id, :shift_date, :start_time, :end_time, :request_id).new(
      @employee_id,
      @employee_id,
      Date.current,
      Time.current,
      Time.current + 1.hour,
      1
    )

    mock_request
  end

  def mock_deletion_request
    mock_shift = Struct.new(:shift_date, :start_time, :end_time).new(
      Date.current,
      Time.current,
      Time.current + 1.hour
    )

    mock_request = Struct.new(:requester_id, :reason, :shift).new(
      @employee_id,
      "テスト理由",
      mock_shift
    )

    mock_request
  end
end
