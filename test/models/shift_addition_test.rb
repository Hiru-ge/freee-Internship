# frozen_string_literal: true

require "test_helper"

class ShiftAdditionTest < ActiveSupport::TestCase
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
    @employee3 = Employee.create!(
      employee_id: "test_employee_3",
      role: "employee"
    )
  end

  def teardown
    # テストデータのクリーンアップ（外部キー制約を考慮した順序）
    # 外部キー制約を一時的に無効化してクリーンアップ
    ActiveRecord::Base.connection.disable_referential_integrity do
      ShiftAddition.delete_all
      Shift.delete_all
      Employee.where(employee_id: ["test_employee_1", "test_employee_2", "test_employee_3"]).delete_all
    end
  end

  # ===== バリデーションテスト =====

  test "有効なShiftAdditionの作成" do
    future_date = Date.current + 1.day
    shift_addition = ShiftAddition.new(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    assert shift_addition.valid?
  end

  test "必須項目のバリデーション" do
    shift_addition = ShiftAddition.new

    assert_not shift_addition.valid?
    assert shift_addition.errors[:request_id].present?
    assert shift_addition.errors[:target_employee_id].present?
    assert shift_addition.errors[:shift_date].present?
    assert shift_addition.errors[:start_time].present?
    assert shift_addition.errors[:end_time].present?
    # statusはデフォルト値があるため、バリデーションエラーは発生しない
  end

  test "終了時間が開始時間より後でない場合のバリデーション" do
    future_date = Date.current + 1.day
    shift_addition = ShiftAddition.new(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("18:00"),
      end_time: Time.zone.parse("09:00"),
      status: "pending"
    )

    assert_not shift_addition.valid?
    assert_includes shift_addition.errors[:end_time], "終了時間は開始時間より後である必要があります"
  end

  # ===== クラスメソッドテスト =====

  test "create_request_for - 正常なリクエスト作成" do
    future_date = Date.current + 1.day

    result = ShiftAddition.create_request_for(
      requester_id: @employee1.employee_id,
      target_employee_ids: [@employee2.employee_id],
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "09:00",
      end_time: "18:00"
    )

    assert_instance_of ShiftAddition::RequestResult, result
    assert_equal 1, result.requests.count
    assert_includes result.success_message, "シフト追加リクエストを送信しました"

    created_request = result.requests.first
    assert_equal @employee1.employee_id, created_request.requester_id
    assert_equal @employee2.employee_id, created_request.target_employee_id
    assert_equal "pending", created_request.status
  end

  test "create_request_for - 必須項目不足でのエラー" do
    assert_raises(ShiftAddition::ValidationError, "必須項目が不足しています") do
      ShiftAddition.create_request_for(
        requester_id: "",
        target_employee_ids: [@employee2.employee_id],
        shift_date: "",
        start_time: "09:00",
        end_time: "18:00"
      )
    end
  end

  test "create_request_for - 対象従業員未選択でのエラー" do
    future_date = Date.current + 1.day

    assert_raises(ShiftAddition::ValidationError, "対象従業員を選択してください") do
      ShiftAddition.create_request_for(
        requester_id: @employee1.employee_id,
        target_employee_ids: [],
        shift_date: future_date.strftime("%Y-%m-%d"),
        start_time: "09:00",
        end_time: "18:00"
      )
    end
  end

  test "create_request_for - 過去の日付でのエラー" do
    past_date = Date.current - 1.day

    assert_raises(ShiftAddition::ValidationError, "過去の日付は指定できません") do
      ShiftAddition.create_request_for(
        requester_id: @employee1.employee_id,
        target_employee_ids: [@employee2.employee_id],
        shift_date: past_date.strftime("%Y-%m-%d"),
        start_time: "09:00",
        end_time: "18:00"
      )
    end
  end

  test "create_request_for - 複数の対象従業員でのリクエスト作成" do
    future_date = Date.current + 1.day

    result = ShiftAddition.create_request_for(
      requester_id: @employee1.employee_id,
      target_employee_ids: [@employee2.employee_id, @employee3.employee_id],
      shift_date: future_date.strftime("%Y-%m-%d"),
      start_time: "10:00",
      end_time: "18:00"
    )

    # 複数の対象従業員に対してリクエストが作成される
    assert_equal 2, result.requests.count
    target_employees = result.requests.map(&:target_employee_id)
    assert_includes target_employees, @employee2.employee_id
    assert_includes target_employees, @employee3.employee_id
    assert_includes result.success_message, "シフト追加リクエストを送信しました"
  end

  # ===== インスタンスメソッドテスト =====

  test "approve_by! - 正常な承認処理" do
    future_date = Date.current + 1.day
    shift_addition = ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    message = shift_addition.approve_by!(@employee2.employee_id)

    assert_equal "approved", shift_addition.reload.status
    assert_not_nil shift_addition.responded_at
    assert_equal "シフト追加を承認しました", message

    # シフトが作成されていることを確認
    assert Shift.exists?(
      employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00")
    )
  end

  test "approve_by! - 権限なしでのエラー" do
    future_date = Date.current + 1.day
    shift_addition = ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    assert_raises(ShiftAddition::AuthorizationError, "このリクエストを承認する権限がありません") do
      shift_addition.approve_by!(@employee3.employee_id)
    end
  end

  test "reject_by! - 正常な拒否処理" do
    future_date = Date.current + 1.day
    shift_addition = ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    message = shift_addition.reject_by!(@employee2.employee_id)

    assert_equal "rejected", shift_addition.reload.status
    assert_not_nil shift_addition.responded_at
    assert_equal "シフト追加を拒否しました", message
  end

  # ===== スコープテスト =====

  test "スコープの動作確認" do
    future_date = Date.current + 1.day

    pending_request = ShiftAddition.create!(
      request_id: "ADDITION_001",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee2.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: "pending"
    )

    approved_request = ShiftAddition.create!(
      request_id: "ADDITION_002",
      requester_id: @employee1.employee_id,
      target_employee_id: @employee3.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("10:00"),
      end_time: Time.zone.parse("19:00"),
      status: "approved"
    )

    assert_includes ShiftAddition.pending, pending_request
    assert_not_includes ShiftAddition.pending, approved_request

    assert_includes ShiftAddition.approved, approved_request
    assert_not_includes ShiftAddition.approved, pending_request

    assert_includes ShiftAddition.for_employee(@employee2.employee_id), pending_request
    assert_not_includes ShiftAddition.for_employee(@employee2.employee_id), approved_request
  end
end
