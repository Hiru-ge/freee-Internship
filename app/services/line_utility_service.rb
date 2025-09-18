class LineUtilityService
  def initialize
  end

  # ユーザーIDの抽出
  def extract_user_id(event)
    event['source']['userId']
  end

  # グループIDの抽出
  def extract_group_id(event)
    return nil unless group_message?(event)
    event['source']['groupId']
  end

  # グループメッセージかどうかの判定
  def group_message?(event)
    event['source']['type'] == 'group'
  end

  # 個人メッセージかどうかの判定
  def individual_message?(event)
    event['source']['type'] == 'user'
  end

  # 従業員が既にリンクされているかチェック
  def employee_already_linked?(line_user_id)
    Employee.exists?(line_id: line_user_id)
  end

  # LINE IDから従業員を検索
  def find_employee_by_line_id(line_id)
    Employee.find_by(line_id: line_id)
  end

  # 認証状態の取得
  def get_authentication_status(line_user_id)
    employee = Employee.find_by(line_id: line_user_id)
    return nil unless employee

    {
      linked: true,
      employee_id: employee.employee_id,
      display_name: employee.display_name,
      role: employee.role
    }
  end

  # freeeから従業員の役職を取得
  def determine_role_from_freee(employee_id)
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      employees = freee_service.get_employees
      employee = employees.find { |emp| (emp[:id] || emp['id']) == employee_id }
      
      return 'employee' unless employee
      
      # freeeの役職情報から判定
      role_info = employee[:role] || employee['role']
      
      case role_info
      when 'admin', 'owner'
        'owner'
      else
        'employee'
      end
    rescue => e
      Rails.logger.error "役職取得エラー: #{e.message}"
      'employee' # デフォルトは従業員
    end
  end

  # リクエストIDの生成
  def generate_request_id(prefix = 'REQ')
    "#{prefix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end

  # シフト交代リクエストIDの生成
  def generate_shift_exchange_request_id
    generate_request_id('EXCHANGE')
  end

  # シフト追加リクエストIDの生成
  def generate_shift_addition_request_id
    generate_request_id('ADDITION')
  end

  # 日付フォーマット
  def format_date(date)
    date.strftime('%m/%d')
  end

  # 時間フォーマット
  def format_time(time)
    time.strftime('%H:%M')
  end

  # 日付と曜日のフォーマット
  def format_date_with_day(date)
    day_of_week = %w[日 月 火 水 木 金 土][date.wday]
    "#{format_date(date)} (#{day_of_week})"
  end

  # 時間範囲のフォーマット
  def format_time_range(start_time, end_time)
    "#{format_time(start_time)}-#{format_time(end_time)}"
  end

  # 従業員名の正規化
  def normalize_employee_name(name)
    name.tr('ァ-ヶ', 'ぁ-ゟ').tr('ー', 'ー')
  end

  # 従業員名の部分一致検索
  def find_employees_by_name(name)
    begin
      freee_service = FreeeApiService.new(
        ENV['FREEE_ACCESS_TOKEN'],
        ENV['FREEE_COMPANY_ID']
      )
      
      employees = freee_service.get_employees
      normalized_name = normalize_employee_name(name)
      
      # 部分一致で検索
      employees.select do |employee|
        display_name = employee[:display_name] || employee['display_name']
        next false unless display_name
        
        normalized_display_name = normalize_employee_name(display_name)
        
        normalized_display_name.include?(normalized_name) || 
        normalized_name.include?(normalized_display_name)
      end
    rescue => e
      Rails.logger.error "従業員検索エラー: #{e.message}"
      []
    end
  end

  # 従業員IDの有効性チェック
  def valid_employee_id_format?(employee_id)
    employee_id.is_a?(String) && employee_id.match?(/^\d+$/)
  end

  # 従業員選択の解析
  def parse_employee_selection(message_text)
    # 数値の場合は従業員IDとして扱う
    if message_text.match?(/^\d+$/)
      employee_id = message_text.to_i
      return { type: :id, value: employee_id } if valid_employee_id_format?(employee_id)
    end
    
    # 文字列の場合は従業員名として扱う
    { type: :name, value: message_text }
  end

  # シフト重複チェック
  def has_shift_overlap?(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      date: date
    )
    
    existing_shifts.any? do |shift|
      # 時間の重複チェック
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
  end

  # 利用可能な従業員と重複している従業員を取得
  def get_available_and_overlapping_employees(employee_ids, date, start_time, end_time)
    available = []
    overlapping = []
    
    employee_ids.each do |employee_id|
      if has_shift_overlap?(employee_id, date, start_time, end_time)
        employee = Employee.find_by(employee_id: employee_id)
        overlapping << employee.display_name if employee
      else
        employee = Employee.find_by(employee_id: employee_id)
        available << employee if employee
      end
    end
    
    { available: available, overlapping: overlapping }
  end

  # エラーメッセージの生成
  def generate_error_message(error_text)
    "❌ #{error_text}"
  end

  # 成功メッセージの生成
  def generate_success_message(success_text)
    "✅ #{success_text}"
  end

  # 警告メッセージの生成
  def generate_warning_message(warning_text)
    "⚠️ #{warning_text}"
  end

  # 情報メッセージの生成
  def generate_info_message(info_text)
    "ℹ️ #{info_text}"
  end

  # 現在の日時を取得
  def current_time
    Time.current
  end

  # 現在の日付を取得
  def current_date
    Date.current
  end

  # 今月の開始日を取得
  def current_month_start
    current_date.beginning_of_month
  end

  # 今月の終了日を取得
  def current_month_end
    current_date.end_of_month
  end

  # 来月の開始日を取得
  def next_month_start
    current_date.next_month.beginning_of_month
  end

  # 来月の終了日を取得
  def next_month_end
    current_date.next_month.end_of_month
  end

  # ログ出力
  def log_info(message)
    Rails.logger.info "[LineUtilityService] #{message}"
  end

  def log_error(message)
    Rails.logger.error "[LineUtilityService] #{message}"
  end

  def log_warn(message)
    Rails.logger.warn "[LineUtilityService] #{message}"
  end

  def log_debug(message)
    Rails.logger.debug "[LineUtilityService] #{message}"
  end
end
