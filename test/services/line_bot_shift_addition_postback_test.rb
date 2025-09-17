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
    event = mock_postback_event(user_id: @test_user_id, postback_data: "approve_addition_#{addition_request.request_id}")

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
    event = mock_postback_event(user_id: @test_user_id, postback_data: "reject_addition_#{addition_request.request_id}")

    # 拒否処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 拒否成功メッセージが返されることを確認
    assert_includes response, "シフト追加を拒否しました"

    # シフト追加リクエストのステータスが拒否に変更されることを確認
    addition_request.reload
    assert_equal 'rejected', addition_request.status

    # クリーンアップ（順序を考慮）
    addition_request.destroy
    target_employee.destroy
    owner.destroy
  end

  test "should handle approve_addition postback with invalid request id" do
    # 対象従業員を作成
    target_employee = Employee.create!(
      employee_id: "target_001",
      role: "employee",
      line_id: @test_user_id
    )

    # 存在しないIDの承認Postbackイベントを作成
    event = mock_postback_event(user_id: @test_user_id, postback_data: "approve_addition_99999")

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
    event = mock_postback_event(user_id: "unauthorized_user_id", postback_data: "approve_addition_#{addition_request.request_id}")

    # 承認処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 権限エラーメッセージが返されることを確認
    assert_includes response, "このリクエストを承認する権限がありません"

    # シフト追加リクエストのステータスが変更されていないことを確認
    addition_request.reload
    assert_equal 'pending', addition_request.status

    # クリーンアップ（順序を考慮）
    addition_request.destroy
    target_employee.destroy
    owner.destroy
    unauthorized_employee.destroy
  end

  # Redフェーズ: メール送信テスト（失敗するテスト）
  test "should send approval email when approving shift addition via LINE" do
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
    event = mock_postback_event(user_id: @test_user_id, postback_data: "approve_addition_#{addition_request.request_id}")

    # 承認処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 承認成功メッセージが返されることを確認
    assert_includes response, "シフト追加を承認しました"

    # シフト追加リクエストのステータスが承認に変更されることを確認
    addition_request.reload
    assert_equal 'approved', addition_request.status

    # メール送信メソッドが存在することを確認（実装されていないため失敗する）
    assert @line_bot_service.private_methods.include?(:send_shift_addition_approval_email), "メール送信メソッドが実装されていません"

    # クリーンアップ（順序を考慮）
    # 作成されたシフトを削除
    created_shift = Shift.find_by(
      employee_id: target_employee.employee_id,
      shift_date: future_date
    )
    created_shift&.destroy
    
    addition_request.destroy
    target_employee.destroy
    owner.destroy
  end

  test "should send rejection email when rejecting shift addition via LINE" do
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
    event = mock_postback_event(user_id: @test_user_id, postback_data: "reject_addition_#{addition_request.request_id}")

    # 拒否処理を実行
    response = @line_bot_service.handle_postback_event(event)

    # 拒否成功メッセージが返されることを確認
    assert_includes response, "シフト追加を拒否しました"

    # シフト追加リクエストのステータスが拒否に変更されることを確認
    addition_request.reload
    assert_equal 'rejected', addition_request.status

    # メール送信メソッドが存在することを確認（実装されていないため失敗する）
    assert @line_bot_service.private_methods.include?(:send_shift_addition_rejection_email), "メール送信メソッドが実装されていません"

    # クリーンアップ（順序を考慮）
    addition_request.destroy
    target_employee.destroy
    owner.destroy
  end

  private

  def mock_postback_event(user_id:, postback_data:)
    {
      'type' => 'postback',
      'postback' => {
        'data' => postback_data
      },
      'source' => {
        'type' => 'user',
        'userId' => user_id
      }
    }
  end
end
