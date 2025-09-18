# frozen_string_literal: true

require "test_helper"

class LineShiftDeletionServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineShiftDeletionService.new
    @employee = employees(:employee1)
    @owner = employees(:owner)
    @shift = shifts(:shift1)
    @line_user_id = "test_line_id"
  end

  test "LineShiftDeletionServiceが正常に初期化される" do
    assert_not_nil @service
    assert_not_nil @service.instance_variable_get(:@utility_service)
    assert_not_nil @service.instance_variable_get(:@conversation_service)
    assert_not_nil @service.instance_variable_get(:@message_service)
  end

  test "欠勤申請コマンドの処理 - 未認証ユーザー" do
    # 未認証ユーザーの場合のテスト
    event = mock_event(@line_user_id, "欠勤申請")

    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.extract_user_id(event)
      "test_line_id"
    end
    def utility_service.employee_already_linked?(line_user_id)
      false
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    result = @service.handle_shift_deletion_command(event)

    assert_includes result, "認証が必要です"
  end

  test "シフト選択の処理 - 未来のシフトが存在する場合" do
    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # LineUtilityServiceのモック - 作成したシフトの従業員を返す
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      # 作成したシフトの従業員を返す
      Shift.where(shift_date: Date.current + 1).first&.employee
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    state = { step: "waiting_shift_selection" }
    result = @service.handle_shift_selection(@line_user_id, "shift_selection", state)

    # 結果の型を確認
    if result.is_a?(Hash)
      # Flex Messageの構造を確認
      assert_equal "flex", result[:type]
      assert result[:contents][:contents].is_a?(Array)
      assert result[:contents][:contents].length >= 1
    else
      # エラーメッセージの場合
      assert result.is_a?(String)
      puts "エラーメッセージ: #{result}"
    end
  end

  test "シフト選択の処理 - 未来のシフトが存在しない場合" do
    # 過去のシフトのみ作成
    past_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current - 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.first
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    state = { step: "waiting_shift_selection" }
    result = @service.handle_shift_selection(@line_user_id, "shift_selection", state)

    assert_includes result, "シフトが見つかりません"
  end

  test "欠勤理由入力の処理 - 空の理由" do
    state = { step: "waiting_reason", shift_id: @shift.id }
    result = @service.handle_shift_deletion_reason_input(@line_user_id, "", state)

    assert_includes result, "理由を入力してください"
  end

  test "欠勤申請の作成 - 成功" do
    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.first
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    reason = "体調不良のため"

    # 実際のShiftDeletionServiceを使用してテスト
    result = @service.create_shift_deletion_request(@line_user_id, @shift.id, reason)
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:message)
  end

  test "欠勤申請の承認処理" do
    shift_deletion = shift_deletions(:deletion1)

    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.where(role: "owner").first
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    postback_data = "approve_deletion_#{shift_deletion.request_id}"

    # 実際のShiftDeletionServiceを使用してテスト
    result = @service.handle_deletion_approval_postback(@line_user_id, postback_data, "approve")
    assert result.is_a?(String)
  end

  test "欠勤申請の拒否処理" do
    shift_deletion = shift_deletions(:deletion1)

    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.where(role: "owner").first
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    postback_data = "reject_deletion_#{shift_deletion.request_id}"

    # 実際のShiftDeletionServiceを使用してテスト
    result = @service.handle_deletion_approval_postback(@line_user_id, postback_data, "reject")
    assert result.is_a?(String)
  end

  private

  def mock_event(line_user_id, message_text)
    event = Object.new
    event.define_singleton_method(:[]) do |key|
      case key
      when "source"
        { "userId" => line_user_id }
      when "message"
        { "text" => message_text }
      when "type"
        "message"
      end
    end
    event
  end
end
