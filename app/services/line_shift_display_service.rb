class LineShiftDisplayService < LineBaseService
  def initialize
    super
  end
  def handle_shift_command(event)
    line_user_id = extract_user_id(event)
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_employee_shifts(employee.employee_id)

    if result[:success]
      shift_display_service.format_employee_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end
  def handle_all_shifts_command(event)
    line_user_id = extract_user_id(event)
    unless employee_already_linked?(line_user_id)
      return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。" if group_message?(event)

      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_all_employee_shifts

    if result[:success]
      shift_display_service.format_all_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end
end
