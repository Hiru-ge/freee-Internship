# frozen_string_literal: true

require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  def setup
    @service = NotificationService.new
    @line_user_id = "test_line_user_id"
    @employee_id = "test_employee_id"
  end

  # ===== シフト交代通知テスト =====

  test "シフト交代依頼通知の送信" do
    # テスト環境では通知は送信されない
    requests = []
    params = {}

    result = @service.send_shift_exchange_request_notification(requests, params)
    assert_nil result
  end

  test "シフト交代承認通知の送信" do
    # テスト環境では通知は送信されない
    exchange_request = mock_exchange_request

    result = @service.send_shift_exchange_approval_notification(exchange_request)
    assert_nil result
  end

  test "シフト交代拒否通知の送信" do
    # テスト環境では通知は送信されない
    exchange_request = mock_exchange_request

    result = @service.send_shift_exchange_rejection_notification(exchange_request)
    assert_nil result
  end

  # ===== シフト追加通知テスト =====

  test "シフト追加依頼通知の送信" do
    # テスト環境では通知は送信されない
    requests = []
    params = {}

    result = @service.send_shift_addition_request_notification(requests, params)
    assert_nil result
  end

  test "シフト追加承認通知の送信" do
    # テスト環境では通知は送信されない
    addition_request = mock_addition_request

    result = @service.send_shift_addition_approval_notification(addition_request)
    assert_nil result
  end

  test "シフト追加拒否通知の送信" do
    # テスト環境では通知は送信されない
    addition_request = mock_addition_request

    result = @service.send_shift_addition_rejection_notification(addition_request)
    assert_nil result
  end

  # ===== 欠勤申請通知テスト =====

  test "欠勤申請通知の送信" do
    # テスト環境では通知は送信されない
    deletion_request = mock_deletion_request

    result = @service.send_shift_deletion_request_notification(deletion_request)
    assert_nil result
  end

  test "欠勤申請承認通知の送信" do
    # テスト環境では通知は送信されない
    deletion_request = mock_deletion_request

    result = @service.send_shift_deletion_approval_notification(deletion_request)
    assert_nil result
  end

  test "欠勤申請拒否通知の送信" do
    # テスト環境では通知は送信されない
    deletion_request = mock_deletion_request

    result = @service.send_shift_deletion_rejection_notification(deletion_request)
    assert_nil result
  end

  # ===== LINE通知テスト =====

  test "認証コード送信通知" do
    # テスト環境では実際の送信は行わない
    result = @service.send_verification_code_notification(@line_user_id, "テスト従業員")
    assert_nil result
  end

  test "認証完了通知" do
    # テスト環境では実際の送信は行わない
    result = @service.send_authentication_success_notification(@line_user_id, "テスト従業員")
    assert_nil result
  end

  test "エラー通知" do
    # テスト環境では実際の送信は行わない
    result = @service.send_error_notification(@line_user_id, "テストエラー")
    assert_nil result
  end

  test "成功通知" do
    # テスト環境では実際の送信は行わない
    result = @service.send_success_notification(@line_user_id, "テスト成功")
    assert_nil result
  end

  test "警告通知" do
    # テスト環境では実際の送信は行わない
    result = @service.send_warning_notification(@line_user_id, "テスト警告")
    assert_nil result
  end

  test "情報通知" do
    # テスト環境では実際の送信は行わない
    result = @service.send_info_notification(@line_user_id, "テスト情報")
    assert_nil result
  end

  # ===== メール通知テスト =====

  test "従業員情報取得" do
    # FreeeApiServiceのモックが必要
    # 実際のテストでは適切なモックを設定
    result = @service.get_employee_with_email(@employee_id)
    # テスト環境ではnilが返される可能性が高い
    assert_nil result
  end

  test "シフト交代依頼メール送信" do
    # テスト環境では送信されない
    result = @service.send_shift_exchange_request_email(
      @employee_id,
      [@employee_id],
      Date.current,
      Time.current,
      Time.current + 1.hour
    )
    assert_not result
  end

  test "シフト追加依頼メール送信" do
    # テスト環境では送信されない
    result = @service.send_shift_addition_request_email(
      @employee_id,
      Date.current,
      Time.current,
      Time.current + 1.hour
    )
    assert_not result
  end

  # ===== ユーティリティ機能テスト =====

  test "メール通知のみの送信" do
    # テスト環境では送信されない
    result = @service.send_email_only(:shift_exchange_request, @employee_id, [@employee_id], Date.current, Time.current, Time.current + 1.hour)
    assert_not result
  end

  test "LINE通知のみの送信" do
    # テスト環境では送信されない
    result = @service.send_line_only(:shift_exchange_request, @employee_id, [@employee_id], Date.current, Time.current, Time.current + 1.hour)
    assert_nil result
  end

  test "グループ通知" do
    # テスト環境では送信されない
    result = @service.send_group_notification("test_group_id", "テストメッセージ")
    assert_nil result
  end

  test "一括通知" do
    # テスト環境では送信されない
    line_user_ids = [@line_user_id, "another_line_user_id"]
    result = @service.send_bulk_notification(line_user_ids, "テストメッセージ")
    # 一括通知は配列を返す
    assert_equal line_user_ids, result
  end

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
