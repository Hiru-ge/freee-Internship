# frozen_string_literal: true

require "test_helper"

class LineMessageServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineMessageService.new
    @employee = employees(:employee1)
  end

  test "should generate help message" do
    result = @service.generate_help_message

    assert_includes result, "利用可能なコマンド"
    assert_includes result, "ヘルプ"
    assert_includes result, "認証"
    assert_includes result, "シフト確認"
    assert_includes result, "欠勤申請"
  end

  test "should generate shift deletion flex message" do
    # 未来のシフトを作成
    shifts = [
      Shift.create!(
        employee: @employee,
        shift_date: Date.current + 1,
        start_time: "09:00",
        end_time: "18:00"
      ),
      Shift.create!(
        employee: @employee,
        shift_date: Date.current + 2,
        start_time: "10:00",
        end_time: "19:00"
      )
    ]

    result = @service.generate_shift_deletion_flex_message(shifts)

    # Flex Messageの構造を確認
    assert result.is_a?(Hash)
    assert_equal "flex", result[:type]
    assert_equal "欠勤申請 - シフトを選択してください", result[:altText]

    # カルーセルの構造を確認
    assert result[:contents].is_a?(Hash)
    assert_equal "carousel", result[:contents][:type]
    assert result[:contents][:contents].is_a?(Array)
    assert_equal 2, result[:contents][:contents].length

    # 各バブルの構造を確認
    shifts.each_with_index do |shift, index|
      bubble = result[:contents][:contents][index]
      assert_equal "bubble", bubble[:type]

      # ヘッダーの確認
      assert_equal "🚫 欠勤申請", bubble[:header][:contents][0][:text]
      assert_equal "#FF6B6B", bubble[:header][:backgroundColor]

      # ボディの確認
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      expected_date = "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})"
      assert_equal expected_date, bubble[:body][:contents][0][:text]

      expected_time = "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}"
      assert_equal expected_time, bubble[:body][:contents][1][:text]

      # フッターの確認
      button = bubble[:footer][:contents][0]
      assert_equal "このシフトを欠勤申請", button[:action][:label]
      assert_equal "deletion_shift_#{shift.id}", button[:action][:data]
      assert_equal "#FF6B6B", button[:color]
    end

    # クリーンアップ
    shifts.each(&:destroy)
  end

  test "should generate empty shift deletion flex message for no shifts" do
    result = @service.generate_shift_deletion_flex_message([])

    # Flex Messageの構造を確認
    assert result.is_a?(Hash)
    assert_equal "flex", result[:type]
    assert_equal "欠勤申請 - シフトを選択してください", result[:altText]

    # カルーセルの構造を確認
    assert result[:contents].is_a?(Hash)
    assert_equal "carousel", result[:contents][:type]
    assert result[:contents][:contents].is_a?(Array)
    assert_equal 0, result[:contents][:contents].length
  end

  test "should generate shift flex message for date" do
    # 未来のシフトを作成
    shifts = [
      Shift.create!(
        employee: @employee,
        shift_date: Date.current + 1,
        start_time: "09:00",
        end_time: "18:00"
      )
    ]

    result = @service.generate_shift_flex_message_for_date(shifts)

    # Flex Messageの構造を確認
    assert result.is_a?(Hash)
    assert_equal "flex", result[:type]
    assert_equal "シフト選択", result[:altText]

    # カルーセルの構造を確認
    assert result[:contents].is_a?(Hash)
    assert_equal "carousel", result[:contents][:type]
    assert result[:contents][:contents].is_a?(Array)
    assert_equal 1, result[:contents][:contents].length

    # クリーンアップ
    shifts.each(&:destroy)
  end

  test "should generate pending requests flex message" do
    # 従業員を作成
    requester = Employee.create!(
      employee_id: "999",
      role: "employee"
    )

    approver = Employee.create!(
      employee_id: "998",
      role: "employee"
    )

    # シフトを作成
    shift = Shift.create!(
      employee: requester,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00"
    )

    # シフト交代リクエストを作成
    exchange_request = ShiftExchange.create!(
      request_id: "exchange_test_001",
      requester_id: requester.employee_id,
      approver_id: approver.employee_id,
      shift: shift,
      status: "pending"
    )

    # シフト追加リクエストを作成
    addition_request = ShiftAddition.create!(
      request_id: "addition_test_001",
      requester_id: requester.employee_id,
      target_employee_id: approver.employee_id,
      shift_date: Date.current + 2,
      start_time: "10:00",
      end_time: "19:00",
      status: "pending"
    )

    result = @service.generate_pending_requests_flex_message([exchange_request], [addition_request])

    # Flex Messageの構造を確認
    assert result.is_a?(Hash)
    assert_equal "flex", result[:type]
    assert_equal "承認待ちのリクエスト", result[:altText]

    # カルーセルの構造を確認
    assert result[:contents].is_a?(Hash)
    assert_equal "carousel", result[:contents][:type]
    assert result[:contents][:contents].is_a?(Array)
    assert_equal 2, result[:contents][:contents].length

    # クリーンアップ
    exchange_request.destroy
    addition_request.destroy
    shift.destroy
    requester.destroy
    approver.destroy
  end

  test "should generate text message" do
    text = "テストメッセージ"
    result = @service.generate_text_message(text)

    assert result.is_a?(Hash)
    assert_equal "text", result[:type]
    assert_equal text, result[:text]
  end

  test "should generate error message" do
    error_text = "エラーが発生しました"
    result = @service.generate_error_message(error_text)

    assert result.is_a?(Hash)
    assert_equal "text", result[:type]
    assert_equal "❌ #{error_text}", result[:text]
  end

  test "should generate success message" do
    success_text = "操作が完了しました"
    result = @service.generate_success_message(success_text)

    assert result.is_a?(Hash)
    assert_equal "text", result[:type]
    assert_equal "✅ #{success_text}", result[:text]
  end

  test "should generate shift addition response for approved request" do
    # シフト追加リクエストを作成
    addition_request = ShiftAddition.create!(
      request_id: "addition_test_002",
      requester_id: @employee.employee_id,
      target_employee_id: @employee.employee_id,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00",
      status: "approved"
    )

    result = @service.generate_shift_addition_response(addition_request, "approved")

    assert_includes result, "シフト追加が承認されました"
    assert_includes result, "日付:"
    assert_includes result, "時間:"
    assert_includes result, "対象者:"

    # クリーンアップ
    addition_request.destroy
  end

  test "should generate shift addition response for rejected request" do
    # シフト追加リクエストを作成
    addition_request = ShiftAddition.create!(
      request_id: "addition_test_003",
      requester_id: @employee.employee_id,
      target_employee_id: @employee.employee_id,
      shift_date: Date.current + 1,
      start_time: "09:00",
      end_time: "18:00",
      status: "rejected"
    )

    result = @service.generate_shift_addition_response(addition_request, "rejected")

    assert_includes result, "シフト追加が否認されました"
    assert_includes result, "日付:"
    assert_includes result, "時間:"
    assert_includes result, "対象者:"

    # クリーンアップ
    addition_request.destroy
  end
end
