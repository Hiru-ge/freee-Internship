require "test_helper"

class ShiftApprovalsControllerTest < ActionController::TestCase
  def setup
    @employee1 = Employee.create!(
      employee_id: "1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "2",
      role: "employee"
    )
    
    # シフトを作成
    @shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )
    
    # シフト交代リクエストを作成
    @shift_exchange = ShiftExchange.create!(
      request_id: "test_request_123",
      requester_id: @employee1.employee_id,
      approver_id: @employee2.employee_id,
      shift_id: @shift.id,
      status: 'pending'
    )
    
    # ログイン（テスト用のセッション設定）
    @controller.session[:authenticated] = true
    @controller.session[:employee_id] = @employee2.employee_id
  end

  test "should approve shift exchange request and update shifts correctly" do
    # 承認前の状態確認
    assert_equal 'pending', @shift_exchange.status
    assert_equal @employee1.employee_id, @shift.employee_id
    assert_equal 1, Shift.where(employee_id: @employee1.employee_id).count
    assert_equal 0, Shift.where(employee_id: @employee2.employee_id).count

    # 承認処理を実行
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # リダイレクト確認
    assert_redirected_to shift_approvals_path

    # 承認後の状態確認
    @shift_exchange.reload
    assert_equal 'approved', @shift_exchange.status
    
    # 元のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: @shift.id)
    
    # 新しいシフトが承認者に作成されていることを確認
    new_shift = Shift.find_by(employee_id: @employee2.employee_id)
    assert_not_nil new_shift
    assert_equal @shift.shift_date, new_shift.shift_date
    assert_equal @shift.start_time, new_shift.start_time
    assert_equal @shift.end_time, new_shift.end_time
    assert_equal true, new_shift.is_modified
    assert_equal @employee1.employee_id, new_shift.original_employee_id
  end

  test "should reject shift exchange request and keep original shift" do
    # 否認前の状態確認
    assert_equal 'pending', @shift_exchange.status
    assert_equal @employee1.employee_id, @shift.employee_id

    # 否認処理を実行
    post :reject, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # リダイレクト確認
    assert_redirected_to shift_approvals_path

    # 否認後の状態確認
    @shift_exchange.reload
    assert_equal 'rejected', @shift_exchange.status
    
    # 元のシフトが残っていることを確認
    @shift.reload
    assert_equal @employee1.employee_id, @shift.employee_id
    
    # 新しいシフトが作成されていないことを確認
    assert_equal 0, Shift.where(employee_id: @employee2.employee_id).count
  end

  test "should handle multiple exchange requests correctly when one is approved" do
    # 別の承認者を作成
    @employee3 = Employee.create!(
      employee_id: "3",
      role: "employee"
    )
    
    # 同じシフトに対する別のリクエストを作成
    @shift_exchange2 = ShiftExchange.create!(
      request_id: "test_request_456",
      requester_id: @employee1.employee_id,
      approver_id: @employee3.employee_id, # 別の承認者
      shift_id: @shift.id, # 同じシフトを使用
      status: 'pending'
    )

    # 最初のリクエストを承認
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # 承認されたリクエストの状態確認
    @shift_exchange.reload
    assert_equal 'approved', @shift_exchange.status

    # 他のリクエストが自動的に拒否されていることを確認
    @shift_exchange2.reload
    assert_equal 'rejected', @shift_exchange2.status
  end

  test "should not allow approval by unauthorized user" do
    # 別のユーザーでログイン
    @employee3 = Employee.create!(
      employee_id: "3",
      role: "employee"
    )
    @controller.session[:employee_id] = @employee3.employee_id

    # 承認処理を実行（権限なし）
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # エラーが発生することを確認
    assert_redirected_to shift_approvals_path
    assert_equal "このリクエストを承認する権限がありません", flash[:error]
    
    # リクエストの状態が変わっていないことを確認
    @shift_exchange.reload
    assert_equal 'pending', @shift_exchange.status
  end

  test "should handle approval when shift is already deleted" do
    # 関連するShiftExchangeのshift_idをnilに設定（外部キー制約を回避）
    ShiftExchange.where(shift_id: @shift.id).update_all(shift_id: nil)
    # シフトを事前に削除
    @shift.destroy!

    # 承認処理を実行
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # エラーが発生することを確認
    assert_redirected_to shift_approvals_path
    assert_equal "シフトが削除されているため、承認できません", flash[:error]
  end

  test "should merge shifts when approver has existing shift" do
    # 承認者の既存シフトを作成（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("20:00")
    )
    
    # 申請者のシフトを20:00-23:00に変更
    @shift.update!(
      start_time: Time.zone.parse("20:00"),
      end_time: Time.zone.parse("23:00")
    )

    # 承認前の状態確認
    assert_equal 1, Shift.where(employee_id: @employee2.employee_id).count
    assert_equal '18:00', existing_shift.start_time.strftime('%H:%M')
    assert_equal '20:00', existing_shift.end_time.strftime('%H:%M')

    # 承認処理を実行
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # リダイレクト確認
    assert_redirected_to shift_approvals_path

    # 承認後の状態確認
    @shift_exchange.reload
    assert_equal 'approved', @shift_exchange.status
    
    # 元のシフトが削除されていることを確認
    assert_nil Shift.find_by(id: @shift.id)
    
    # 承認者のシフトが18:00-23:00にマージされていることを確認
    merged_shift = Shift.find_by(employee_id: @employee2.employee_id)
    assert_not_nil merged_shift
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
    assert_equal @employee1.employee_id, merged_shift.original_employee_id
    
    # 承認者のシフトが1つだけであることを確認
    assert_equal 1, Shift.where(employee_id: @employee2.employee_id).count
  end

  test "should merge shifts when new shift is earlier than existing shift" do
    # 承認者の既存シフトを作成（20:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("20:00"),
      end_time: Time.zone.parse("23:00")
    )
    
    # 申請者のシフトを18:00-20:00に変更
    @shift.update!(
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("20:00")
    )

    # 承認処理を実行
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # 承認者のシフトが18:00-23:00にマージされていることを確認
    merged_shift = Shift.find_by(employee_id: @employee2.employee_id)
    assert_not_nil merged_shift
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
  end

  test "should merge shifts when shifts overlap" do
    # 承認者の既存シフトを作成（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("20:00")
    )
    
    # 申請者のシフトを19:00-22:00に変更（重複あり）
    @shift.update!(
      start_time: Time.zone.parse("19:00"),
      end_time: Time.zone.parse("22:00")
    )

    # 承認処理を実行
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # 承認者のシフトが18:00-22:00にマージされていることを確認
    merged_shift = Shift.find_by(employee_id: @employee2.employee_id)
    assert_not_nil merged_shift
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '22:00', merged_shift.end_time.strftime('%H:%M')
  end

  test "should not merge when new shift is fully contained in existing shift" do
    # 承認者の既存シフトを作成（18:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: Date.current,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("23:00")
    )
    
    # 申請者のシフトを20:00-22:00に変更（既存シフトに完全に含まれる）
    @shift.update!(
      start_time: Time.zone.parse("20:00"),
      end_time: Time.zone.parse("22:00")
    )

    # 承認処理を実行
    post :approve, params: {
      request_id: @shift_exchange.request_id,
      request_type: 'exchange'
    }

    # 承認者のシフトが変更されていないことを確認
    merged_shift = Shift.find_by(employee_id: @employee2.employee_id)
    assert_not_nil merged_shift
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
  end
end
