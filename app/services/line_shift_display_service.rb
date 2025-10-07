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
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_employee_shifts(employee.employee_id)

    if result[:success]
      shift_display_service.format_employee_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end
  def handle_all_shifts_command(event)
    # 1. 認証チェック（LineBaseServiceの共通処理）
    auth_result = check_line_authentication(event)
    return auth_result[:message] unless auth_result[:success]
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_all_employee_shifts

    if result[:success]
      shift_display_service.format_all_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end
end
