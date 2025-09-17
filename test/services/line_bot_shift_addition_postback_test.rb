require "test_helper"

class LineBotShiftAdditionPostbackTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_id"
  end

  # Redフェーズ: 失敗するテスト
  test "should handle approve_addition postback event" do
    # オーナーと対象従業員を作成
    owner = Employee.create!(
      employee_id: "owner_001",
      role: "owner",
      line_id: "owner_user_id"
    )
    
    target_employee = Employee.create!(
      employee_id: "target_001",
      role: "employee",
      line_id: @test_user_id
    )

    # シフト追加リクエストを作成
    future_date = Date.current + 7.days
    addition_request = ShiftAddition.create!(
      request_id: "ADD_#{Time.current.strftime('%Y%m%d_%H%M%S')}_test",
      requester_id: owner.employee_id,
      target_employee_id: target_employee.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: 'pending'
    )

    # 承認Postbackイベントを作成
    event = mock_postback_event("approve_addition_#{addition_request.id}", @test_user_id)

    # 承認処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 承認成功メッセージが返されることを確認
    assert_includes response, "シフト追加を承認しました"

    # シフト追加リクエストのステータスが承認に変更されることを確認
    addition_request.reload
    assert_equal 'approved', addition_request.status

    # 作成されたシフトを確認
    created_shift = Shift.find_by(
      employee_id: target_employee.employee_id,
      shift_date: future_date
    )
    assert_not_nil created_shift

    # クリーンアップ
    created_shift.destroy if created_shift
    addition_request.destroy
    owner.destroy
    target_employee.destroy
  end

  test "should handle reject_addition postback event" do
    # オーナーと対象従業員を作成
    owner = Employee.create!(
      employee_id: "owner_001",
      role: "owner",
      line_id: "owner_user_id"
    )
    
    target_employee = Employee.create!(
      employee_id: "target_001",
      role: "employee",
      line_id: @test_user_id
    )

    # シフト追加リクエストを作成
    future_date = Date.current + 7.days
    addition_request = ShiftAddition.create!(
      request_id: "ADD_#{Time.current.strftime('%Y%m%d_%H%M%S')}_test",
      requester_id: owner.employee_id,
      target_employee_id: target_employee.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: 'pending'
    )

    # 拒否Postbackイベントを作成
    event = mock_postback_event("reject_addition_#{addition_request.id}", @test_user_id)

    # 拒否処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 拒否成功メッセージが返されることを確認
    assert_includes response, "シフト追加を拒否しました"

    # シフト追加リクエストのステータスが拒否に変更されることを確認
    addition_request.reload
    assert_equal 'rejected', addition_request.status

    # クリーンアップ
    addition_request.destroy
    owner.destroy
    target_employee.destroy
  end

  test "should handle approve_addition postback with invalid request id" do
    # 対象従業員を作成
    target_employee = Employee.create!(
      employee_id: "target_001",
      role: "employee",
      line_id: @test_user_id
    )

    # 存在しないIDの承認Postbackイベントを作成
    event = mock_postback_event("approve_addition_99999", @test_user_id)

    # 承認処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # エラーメッセージが返されることを確認
    assert_includes response, "シフト追加リクエストが見つかりません"

    # クリーンアップ
    target_employee.destroy
  end

  test "should handle approve_addition postback with unauthorized user" do
    # オーナーと対象従業員を作成
    owner = Employee.create!(
      employee_id: "owner_001",
      role: "owner",
      line_id: "owner_user_id"
    )
    
    target_employee = Employee.create!(
      employee_id: "target_001",
      role: "employee",
      line_id: @test_user_id
    )

    # 別の従業員を作成（権限なし）
    unauthorized_employee = Employee.create!(
      employee_id: "unauthorized_001",
      role: "employee",
      line_id: "unauthorized_user_id"
    )

    # シフト追加リクエストを作成
    future_date = Date.current + 7.days
    addition_request = ShiftAddition.create!(
      request_id: "ADD_#{Time.current.strftime('%Y%m%d_%H%M%S')}_test",
      requester_id: owner.employee_id,
      target_employee_id: target_employee.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: 'pending'
    )

    # 権限のないユーザーからの承認Postbackイベントを作成
    event = mock_postback_event("approve_addition_#{addition_request.id}", "unauthorized_user_id")

    # 承認処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 権限エラーメッセージが返されることを確認
    assert_includes response, "このリクエストを承認する権限がありません"

    # シフト追加リクエストのステータスが変更されていないことを確認
    addition_request.reload
    assert_equal 'pending', addition_request.status

    # クリーンアップ
    addition_request.destroy
    owner.destroy
    target_employee.destroy
    unauthorized_employee.destroy
  end

  private

  def mock_postback_event(data, user_id)
    {
      'type' => 'postback',
      'postback' => {
        'data' => data
      },
      'source' => {
        'type' => 'user',
        'userId' => user_id
      }
    }
  end
end
