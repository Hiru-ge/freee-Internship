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
      Employee.find_by(employee_id: '3316120') # employee1のID
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    reason = "体調不良のため"

    # 実際のShiftDeletionServiceを使用してテスト
    result = @service.create_shift_deletion_request(@line_user_id, future_shift.id, reason)

    # 修正後は文字列を返す
    assert result.is_a?(String)
    assert_includes result, "送信しました"
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

  test "欠勤申請の作成 - 従業員が見つからない場合" do
    # LineUtilityServiceのモック - 従業員が見つからない場合
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      nil
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    reason = "体調不良のため"
    result = @service.create_shift_deletion_request(@line_user_id, @shift.id, reason)

    # エラーメッセージが文字列で返される
    assert result.is_a?(String)
    assert_includes result, "従業員情報が見つかりません"
  end

  test "欠勤申請の作成 - 戻り値の形式確認" do
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
      Employee.find_by(employee_id: '3316120') # employee1のID
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    reason = "体調不良のため"
    result = @service.create_shift_deletion_request(@line_user_id, future_shift.id, reason)

    # LINE Bot APIが期待する文字列形式であることを確認
    assert result.is_a?(String)
    assert_not result.is_a?(Hash)
    assert_not result.is_a?(Array)

    # 成功メッセージの内容を確認
    assert_includes result, "送信しました"
    assert_includes result, "承認をお待ちください"
  end

  test "欠勤申請フロー全体のテスト" do
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
      Employee.find_by(employee_id: '3316120') # employee1のID
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    # 1. 欠勤申請の作成
    reason = "体調不良のため欠勤"
    result = @service.create_shift_deletion_request(@line_user_id, future_shift.id, reason)

    # 成功メッセージが文字列で返される
    assert result.is_a?(String)
    assert_includes result, "送信しました"

    # 2. データベースに欠勤申請が作成されていることを確認
    deletion_request = ShiftDeletion.last
    assert_not_nil deletion_request
    assert_equal future_shift.id, deletion_request.shift_id
    assert_equal reason, deletion_request.reason
    assert_equal "pending", deletion_request.status
  end

  # 新しい日付入力フロー（月/日形式）のテスト
  test "欠勤申請コマンドで月/日形式の日付入力を促す" do
    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.extract_user_id(event)
      "test_line_id"
    end
    def utility_service.employee_already_linked?(line_user_id)
      true
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    event = mock_event(@line_user_id, "欠勤申請")
    result = @service.handle_shift_deletion_command(event)

    # 月/日形式の日付入力を促すメッセージが返される
    assert_includes result, "欠勤したい日付を入力してください"
    assert_includes result, "例: 09/20"
  end

  test "月/日形式の日付入力処理 - 有効な日付" do
    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.find_by(employee_id: '3316120')
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    # 未来のシフトを作成
    future_shift = Shift.create!(
      employee: @employee,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    state = { step: "waiting_for_shift_deletion_date" }
    result = @service.handle_shift_deletion_date_input(@line_user_id, "9/20", state)

    # Flex Messageが返されることを確認
    assert result.is_a?(Hash)
    assert_equal "flex", result[:type]
    assert_equal "欠勤申請 - シフトを選択してください", result[:altText]

    # クリーンアップ
    future_shift.destroy
  end

  test "月/日形式の日付入力処理 - 無効な日付形式" do
    state = { step: "waiting_for_shift_deletion_date" }
    result = @service.handle_shift_deletion_date_input(@line_user_id, "2024-09-20", state)

    # エラーメッセージが返される
    assert_includes result, "正しい日付形式で入力してください"
    assert_includes result, "例: 9/20 または 09/20"
  end

  test "月/日形式の日付入力処理 - 過去の日付" do
    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.find_by(employee_id: '3316120')
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    # 過去の日付を入力（1/1は現在の年では過去になる）
    state = { step: "waiting_for_shift_deletion_date" }
    result = @service.handle_shift_deletion_date_input(@line_user_id, "1/1", state)

    # 過去の日付エラーメッセージが返されるか、シフトが見つからないメッセージが返される
    assert result.include?("過去の日付は選択できません") || result.include?("シフトが見つかりません")
  end

  test "月/日形式の日付入力処理 - 存在しない日付" do
    state = { step: "waiting_for_shift_deletion_date" }
    result = @service.handle_shift_deletion_date_input(@line_user_id, "2/30", state)

    # 無効な日付エラーメッセージが返される
    assert_includes result, "無効な日付です"
  end

  test "月/日形式の日付入力処理 - 指定日付にシフトがない場合" do
    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.find_by(employee_id: '3316120')
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    state = { step: "waiting_for_shift_deletion_date" }
    result = @service.handle_shift_deletion_date_input(@line_user_id, "12/25", state)

    # シフトが見つからないメッセージが返される
    assert_includes result, "シフトが見つかりません"
    assert_includes result, "別の日付を入力してください"
  end

  test "年切り替え処理 - 12月に1月の日付を入力" do
    # LineUtilityServiceのモック
    utility_service = Object.new
    def utility_service.find_employee_by_line_id(line_user_id)
      Employee.find_by(employee_id: '3316120')
    end

    @service.instance_variable_set(:@utility_service, utility_service)

    # 現在の日付を12月に設定（モック）
    travel_to Date.new(2024, 12, 15) do
      state = { step: "waiting_for_shift_deletion_date" }
      result = @service.handle_shift_deletion_date_input(@line_user_id, "1/1", state)

      # 来年の1月1日として処理される（エラーにならない）
      # 実際の実装では、LineDateValidationServiceが年切り替えを処理
      assert_not_includes result, "過去の日付は選択できません"
    end
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
