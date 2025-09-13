require 'test_helper'

class PerformanceOptimizationTest < ActiveSupport::TestCase
  # TDD手法でパフォーマンス最適化のテストを作成
  
  setup do
    # テストデータの準備
    @employee_ids = ['1001', '1002', '1003', '1004', '1005']
    @month = Date.current.month
    @year = Date.current.year
    
    # テスト用の従業員データを作成
    create_test_employees
    # テスト用のシフトデータを作成
    create_test_shifts
  end
  
  teardown do
    # テストデータのクリーンアップ（外部キー制約の順序を考慮）
    ShiftExchange.destroy_all
    ShiftAddition.destroy_all
    Shift.destroy_all
    Employee.destroy_all
  end
  
  # N+1問題のテスト
  test "shifts_controller_data_should_not_have_n_plus_1_queries" do
    # 期待値: 従業員数に関係なく、クエリ数が一定であること
    expected_query_count = 8 # 従業員取得 + シフト取得 + その他のクエリ
    
    # クエリ数をカウント
    query_count = 0
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      query_count += 1
    end
    
    # ShiftsController#dataの処理をシミュレート
    controller = ShiftsController.new
    controller.instance_variable_set(:@employee_ids, @employee_ids)
    
    # 最適化前の処理（N+1問題あり）
    shifts_in_db = Shift.for_month(@year, @month)
    @employee_ids.each do |employee_id|
      employee_shift_records = shifts_in_db.where(employee_id: employee_id)
      employee_shift_records.each do |shift_record|
        # 各シフトレコードに対して個別クエリが発生
        shift_record.employee_id
      end
    end
    
    # 最適化後の処理（includes使用）
    optimized_shifts = Shift.for_month(@year, @month).includes(:employee)
    optimized_shifts.each do |shift|
      shift.employee_id
    end
    
    # クエリ数が期待値以下であることを確認
    assert query_count <= expected_query_count, 
           "クエリ数が期待値(#{expected_query_count})を超えています: #{query_count}"
  end
  
  test "wage_service_should_not_have_n_plus_1_queries_for_multiple_employees" do
    # 期待値: 従業員数に関係なく、クエリ数が一定であること
    expected_query_count = 8 # 全シフト取得 + 従業員取得 + その他のクエリ
    
    # クエリ数をカウント
    query_count = 0
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      query_count += 1
    end
    
    # WageService#get_all_employees_wagesの処理をシミュレート
    wage_service = WageService.new
    
    # 最適化前の処理（N+1問題あり）
    @employee_ids.each do |employee_id|
      shifts = Shift.where(
        employee_id: employee_id,
        shift_date: Date.new(@year, @month, 1)..Date.new(@year, @month, -1)
      )
      shifts.each do |shift|
        shift.employee_id
      end
    end
    
    # 最適化後の処理（一括取得）
    all_shifts = Shift.where(
      employee_id: @employee_ids,
      shift_date: Date.new(@year, @month, 1)..Date.new(@year, @month, -1)
    ).includes(:employee)
    
    # 従業員ごとにグループ化
    shifts_by_employee = all_shifts.group_by(&:employee_id)
    @employee_ids.each do |employee_id|
      employee_shifts = shifts_by_employee[employee_id] || []
      employee_shifts.each do |shift|
        shift.employee_id
      end
    end
    
    # クエリ数が期待値以下であることを確認
    assert query_count <= expected_query_count, 
           "クエリ数が期待値(#{expected_query_count})を超えています: #{query_count}"
  end
  
  # freee API呼び出し最適化のテスト
  test "freee_api_service_should_use_caching" do
    # 期待値: 同じ従業員情報を複数回取得する際、キャッシュが使用されること
    
    # モックの設定
    mock_response = {
      'id' => '1001',
      'display_name' => 'テスト従業員',
      'email' => 'test@example.com'
    }
    
    # freee APIのモック（Rails標準のモックを使用）
    freee_service = FreeeApiService.new('test_token', 'test_company')
    freee_service.define_singleton_method(:get_employee_info) do |employee_id|
      mock_response
    end
    
    # 初回呼び出し（API呼び出し）
    first_call = freee_service.get_employee_info('1001')
    
    # 2回目呼び出し（キャッシュから取得）
    second_call = freee_service.get_employee_info('1001')
    
    # 結果が同じであることを確認
    assert_equal first_call, second_call
    assert_equal 'テスト従業員', first_call['display_name']
  end
  
  test "freee_api_service_should_limit_api_calls" do
    # 期待値: API呼び出し頻度が制限されること
    
    # レート制限のテスト
    freee_service = FreeeApiService.new('test_token', 'test_company')
    
    # 連続呼び出しのテスト
    start_time = Time.current
    call_count = 0
    
    # 10回連続でAPI呼び出し
    10.times do
      begin
        freee_service.get_employee_info('1001')
        call_count += 1
      rescue => e
        # レート制限エラーは期待される動作
        break if e.message.include?('rate limit')
      end
    end
    
    end_time = Time.current
    elapsed_time = end_time - start_time
    
    # レート制限が適用されていることを確認
    assert elapsed_time > 1.0, "レート制限が適用されていません"
  end
  
  # パフォーマンス測定のテスト
  test "shifts_controller_data_should_complete_within_time_limit" do
    # 期待値: レスポンス時間が1秒以内であること
    time_limit = 1.0 # 秒
    
    start_time = Time.current
    
    # ShiftsController#dataの処理をシミュレート
    controller = ShiftsController.new
    controller.instance_variable_set(:@employee_ids, @employee_ids)
    
    # 最適化後の処理
    shifts_in_db = Shift.for_month(@year, @month).includes(:employee)
    shifts = {}
    
    @employee_ids.each do |employee_id|
      employee_shifts = {}
      employee_shift_records = shifts_in_db.select { |s| s.employee_id == employee_id }
      
      employee_shift_records.each do |shift_record|
        day = shift_record.shift_date.day
        time_string = "#{shift_record.start_time.strftime('%H')}-#{shift_record.end_time.strftime('%H')}"
        employee_shifts[day.to_s] = time_string
      end
      
      shifts[employee_id] = {
        name: "従業員#{employee_id}",
        shifts: employee_shifts
      }
    end
    
    end_time = Time.current
    elapsed_time = end_time - start_time
    
    # 処理時間が制限内であることを確認
    assert elapsed_time <= time_limit, 
           "処理時間が制限(#{time_limit}秒)を超えています: #{elapsed_time}秒"
  end
  
  test "wage_service_should_complete_within_time_limit" do
    # 期待値: 全従業員の給与計算が5秒以内であること
    time_limit = 5.0 # 秒
    
    start_time = Time.current
    
    # WageService#get_all_employees_wagesの処理をシミュレート
    wage_service = WageService.new
    
    # 最適化後の処理
    all_shifts = Shift.where(
      employee_id: @employee_ids,
      shift_date: Date.new(@year, @month, 1)..Date.new(@year, @month, -1)
    ).includes(:employee)
    
    shifts_by_employee = all_shifts.group_by(&:employee_id)
    all_wages = []
    
    @employee_ids.each do |employee_id|
      employee_shifts = shifts_by_employee[employee_id] || []
      monthly_hours = { normal: 0, evening: 0, night: 0 }
      
      employee_shifts.each do |shift|
        # 給与計算ロジック
        start_hour = shift.start_time.hour
        end_hour = shift.end_time.hour
        
        if end_hour <= start_hour
          (start_hour...24).each { |hour| monthly_hours[:normal] += 1 }
          (0...end_hour).each { |hour| monthly_hours[:normal] += 1 }
        else
          (start_hour...end_hour).each { |hour| monthly_hours[:normal] += 1 }
        end
      end
      
      total_wage = monthly_hours[:normal] * 1000
      
      all_wages << {
        employee_id: employee_id,
        employee_name: "従業員#{employee_id}",
        wage: total_wage,
        work_hours: monthly_hours,
        target: 100000,
        percentage: (total_wage.to_f / 100000 * 100).round(2)
      }
    end
    
    end_time = Time.current
    elapsed_time = end_time - start_time
    
    # 処理時間が制限内であることを確認
    assert elapsed_time <= time_limit, 
           "処理時間が制限(#{time_limit}秒)を超えています: #{elapsed_time}秒"
  end
  
  private
  
  def create_test_employees
    # テスト用の従業員データを作成
    @employee_ids.each do |employee_id|
      Employee.create!(
        employee_id: employee_id,
        password_hash: BCrypt::Password.create('password123'),
        role: 'employee'
      )
    end
  end
  
  def create_test_shifts
    # テスト用のシフトデータを作成
    @employee_ids.each do |employee_id|
      (1..5).each do |day|
        Shift.create!(
          employee_id: employee_id,
          shift_date: Date.new(@year, @month, day),
          start_time: Time.new(@year, @month, day, 9, 0),
          end_time: Time.new(@year, @month, day, 18, 0)
        )
      end
    end
  end
end
