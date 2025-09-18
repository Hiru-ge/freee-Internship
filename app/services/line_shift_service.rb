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
    
    # 今日から1ヶ月後までのシフトを取得
    start_date = Date.current
    end_date = start_date + 1.month
    
    shifts = Shift.where(
      employee_id: employee.employee_id,
      shift_date: start_date..end_date
    ).order(:shift_date, :start_time)
    
    if shifts.empty?
      return "今月のシフト情報はありません。"
    end
    
    # シフト情報をフォーマット
    message = "📅 今月のシフト\n\n"
    shifts.each do |shift|
      day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
      message += "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week}) #{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}\n"
    end
    
    message
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
    
    # 全従業員のシフト情報を取得
    employees = Employee.all
    all_shifts = get_group_shift_info(employees)
    
    if all_shifts.empty?
      return "【今月の全員シフト】\n今月のシフト情報はありません。"
    end
    
    # 日付ごとにグループ化
    grouped_shifts = all_shifts.group_by { |shift| shift[:date] }
    
    # シフト情報をフォーマット
    message = "【今月の全員シフト】\n\n"
    grouped_shifts.sort_by { |date, _| date }.each do |date, shifts|
      day_of_week = %w[日 月 火 水 木 金 土][date.wday]
      message += "📅 #{date.strftime('%m/%d')} (#{day_of_week})\n"
      shifts.each do |shift|
        message += "  #{shift[:employee_name]}: #{shift[:start_time]}-#{shift[:end_time]}\n"
      end
      message += "\n"
    end
    
    message
  end

  private

  # 全従業員のシフト情報を取得
  def get_group_shift_info(employees)
    now = Time.current
    start_date = now.beginning_of_month
    end_date = now.end_of_month

    all_shifts = []
    employees.each do |employee|
      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: start_date..end_date
      ).order(:shift_date, :start_time)

      shifts.each do |shift|
        all_shifts << {
          employee_name: employee.display_name,
          date: shift.shift_date,
          start_time: shift.start_time.strftime('%H:%M'),
          end_time: shift.end_time.strftime('%H:%M')
        }
      end
    end
    all_shifts
  end

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
