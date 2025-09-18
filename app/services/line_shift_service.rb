class LineShiftService
  def initialize
  end

  # シフトコマンドの処理
  def handle_shift_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # 従業員情報を取得
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    
    # 共通サービスを使用してシフトデータを取得
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_employee_shifts(employee.employee_id)
    
    if result[:success]
      shift_display_service.format_employee_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end

  # 全員シフトコマンドの処理
  def handle_all_shifts_command(event)
    line_user_id = extract_user_id(event)
    
    # 認証チェック
    unless employee_already_linked?(line_user_id)
      if group_message?(event)
        return "認証が必要です。個人チャットで「認証」と入力して認証を行ってください。"
      else
        return "認証が必要です。「認証」と入力して認証を行ってください。"
      end
    end
    
    # 共通サービスを使用して全従業員のシフトデータを取得
    shift_display_service = ShiftDisplayService.new
    result = shift_display_service.get_all_employee_shifts
    
    if result[:success]
      shift_display_service.format_all_shifts_for_line(result[:data])
    else
      "シフトデータの取得に失敗しました。"
    end
  end

  private


  # ユーティリティメソッド
  def extract_user_id(event)
    event['source']['userId']
  end

  def group_message?(event)
    event['source']['type'] == 'group'
  end

  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  def find_employee_by_line_id(line_id)
    Employee.find_by(line_id: line_id)
  end
end
