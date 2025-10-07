class LineShiftDisplayService < LineBaseService
  def initialize
    super
  end
  def handle_shift_command(event)
    # 1. 認証チェック（LineBaseServiceの共通処理）
    auth_result = check_line_authentication(event)
    return auth_result[:message] unless auth_result[:success]

    # 2. 従業員情報の取得
    line_user_id = extract_user_id(event)
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 3. シフトデータの取得と表示
    result = Shift.get_employee_shifts(employee.employee_id)

    if result[:success]
      Shift.format_employee_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end
  def handle_all_shifts_command(event)
    # 1. 認証チェック（LineBaseServiceの共通処理）
    auth_result = check_line_authentication(event)
    return auth_result[:message] unless auth_result[:success]
    result = Shift.get_all_employee_shifts

    if result[:success]
      format_all_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end

  private

  def format_all_shifts_for_line(all_shifts)
    return "今月のシフト情報はありません。" if all_shifts.empty?

    message = "📅 全従業員のシフト\n\n"
    all_shifts.each do |shift_data|
      day_of_week = %w[日 月 火 水 木 金 土][shift_data[:date].wday]
      message += "#{shift_data[:employee_name]}: #{shift_data[:date].strftime('%m/%d')} (#{day_of_week}) #{shift_data[:start_time]}-#{shift_data[:end_time]}\n"
    end

    message
  end
end
