require 'test_helper'

class ShiftMergeServiceTest < ActiveSupport::TestCase
  def setup
    @employee1 = Employee.create!(
      employee_id: "1",
      role: "employee"
    )
    @employee2 = Employee.create!(
      employee_id: "2",
      role: "employee"
    )
    @shift_date = Date.current
  end

  test "should merge shifts correctly when new shift is later" do
    # 既存シフト（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # 新しいシフト（20:00-23:00）
    new_shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # マージ実行
    merged_shift = ShiftMergeService.merge_shifts(existing_shift, new_shift)
    
    # 結果確認
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
  end

  test "should merge shifts correctly when new shift is earlier" do
    # 既存シフト（20:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # 新しいシフト（18:00-20:00）
    new_shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # マージ実行
    merged_shift = ShiftMergeService.merge_shifts(existing_shift, new_shift)
    
    # 結果確認
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
  end

  test "should merge shifts correctly when shifts overlap" do
    # 既存シフト（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # 新しいシフト（19:00-22:00）
    new_shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    # マージ実行
    merged_shift = ShiftMergeService.merge_shifts(existing_shift, new_shift)
    
    # 結果確認
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '22:00', merged_shift.end_time.strftime('%H:%M')
  end

  test "should return new shift when existing shift is nil" do
    new_shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # マージ実行
    merged_shift = ShiftMergeService.merge_shifts(nil, new_shift)
    
    # 結果確認
    assert_equal new_shift, merged_shift
  end

  test "should detect when new shift is fully contained in existing shift" do
    # 既存シフト（18:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # 新しいシフト（20:00-22:00）
    new_shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    # 完全に含まれているかチェック
    assert ShiftMergeService.shift_fully_contained?(existing_shift, new_shift)
  end

  test "should detect when new shift is not fully contained in existing shift" do
    # 既存シフト（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # 新しいシフト（19:00-22:00）
    new_shift = Shift.new(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    # 完全に含まれていないかチェック
    assert_not ShiftMergeService.shift_fully_contained?(existing_shift, new_shift)
  end

  test "should process shift exchange approval with existing shift" do
    # 承認者の既存シフト（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # 申請者のシフト（20:00-23:00）
    requester_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # シフト交代承認処理
    merged_shift = ShiftMergeService.process_shift_exchange_approval(@employee2.employee_id, requester_shift)
    
    # 結果確認
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
    assert_equal @employee1.employee_id, merged_shift.original_employee_id
  end

  test "should process shift exchange approval without existing shift" do
    # 申請者のシフト（20:00-23:00）
    requester_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # シフト交代承認処理
    merged_shift = ShiftMergeService.process_shift_exchange_approval(@employee2.employee_id, requester_shift)
    
    # 結果確認
    assert_not_nil merged_shift
    assert_equal @employee2.employee_id, merged_shift.employee_id
    assert_equal '20:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
    assert_equal @employee1.employee_id, merged_shift.original_employee_id
  end

  test "should not modify existing shift when new shift is fully contained" do
    # 承認者の既存シフト（18:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee2.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # 申請者のシフト（20:00-22:00）
    requester_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('22:00')
    )
    
    # シフト交代承認処理
    merged_shift = ShiftMergeService.process_shift_exchange_approval(@employee2.employee_id, requester_shift)
    
    # 結果確認（既存シフトが変更されていない）
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
  end

  # シフト追加承認時の連結処理テスト
  test "should process shift addition approval with existing shift - merge when connected" do
    # 既存シフト（20:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # 追加するシフト（18:00-20:00）
    new_shift_data = {
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    }
    
    # シフト追加承認処理
    merged_shift = ShiftMergeService.process_shift_addition_approval(@employee1.employee_id, new_shift_data)
    
    # 結果確認（18:00-23:00に連結される）
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
  end

  test "should process shift addition approval with existing shift - merge when overlapping" do
    # 既存シフト（18:00-20:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    )
    
    # 追加するシフト（19:00-22:00）
    new_shift_data = {
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('19:00'),
      end_time: Time.zone.parse('22:00')
    }
    
    # シフト追加承認処理
    merged_shift = ShiftMergeService.process_shift_addition_approval(@employee1.employee_id, new_shift_data)
    
    # 結果確認（18:00-22:00に連結される）
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '22:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
  end

  test "should process shift addition approval without existing shift" do
    # 追加するシフト（18:00-20:00）
    new_shift_data = {
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('20:00')
    }
    
    # シフト追加承認処理
    merged_shift = ShiftMergeService.process_shift_addition_approval(@employee1.employee_id, new_shift_data)
    
    # 結果確認（新規作成される）
    assert_not_nil merged_shift
    assert_equal @employee1.employee_id, merged_shift.employee_id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '20:00', merged_shift.end_time.strftime('%H:%M')
    assert_equal true, merged_shift.is_modified
  end

  test "should not modify existing shift when new shift is fully contained in addition" do
    # 既存シフト（18:00-23:00）
    existing_shift = Shift.create!(
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('18:00'),
      end_time: Time.zone.parse('23:00')
    )
    
    # 追加するシフト（20:00-22:00）
    new_shift_data = {
      employee_id: @employee1.employee_id,
      shift_date: @shift_date,
      start_time: Time.zone.parse('20:00'),
      end_time: Time.zone.parse('22:00')
    }
    
    # シフト追加承認処理
    merged_shift = ShiftMergeService.process_shift_addition_approval(@employee1.employee_id, new_shift_data)
    
    # 結果確認（既存シフトが変更されていない）
    assert_equal existing_shift.id, merged_shift.id
    assert_equal '18:00', merged_shift.start_time.strftime('%H:%M')
    assert_equal '23:00', merged_shift.end_time.strftime('%H:%M')
  end
end
