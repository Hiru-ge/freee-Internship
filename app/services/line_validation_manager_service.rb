# frozen_string_literal: true

class LineValidationManagerService
  # 日付の検証とフォーマット
  def self.validate_and_format_date(date_string)
    return { valid: false, error: "日付が入力されていません。" } if date_string.blank?
    
    begin
      # 様々な日付形式に対応
      date = case date_string
      when /^\d{4}-\d{2}-\d{2}$/
        Date.parse(date_string)
      when /^\d{2}\/\d{2}$/
        current_year = Date.current.year
        Date.parse("#{current_year}/#{date_string}")
      when /^\d{1,2}\/\d{1,2}$/
        current_year = Date.current.year
        Date.parse("#{current_year}/#{date_string}")
      else
        Date.parse(date_string)
      end
      
      # 過去の日付は許可しない
      if date < Date.current
        return { valid: false, error: "過去の日付は指定できません。" }
      end
      
      { valid: true, date: date }
    rescue ArgumentError
      { valid: false, error: "正しい日付形式で入力してください。\n例: 2024-01-15 または 1/15" }
    end
  end

  # 時間の検証とフォーマット
  def self.validate_and_format_time(time_string)
    return { valid: false, error: "時間が入力されていません。" } if time_string.blank?
    
    begin
      # 時間範囲の形式をチェック (例: 9:00-17:00)
      if time_string.match?(/^\d{1,2}:\d{2}-\d{1,2}:\d{2}$/)
        start_time_str, end_time_str = time_string.split('-')
        start_time = Time.parse(start_time_str)
        end_time = Time.parse(end_time_str)
        
        # 終了時間が開始時間より後であることを確認
        if end_time <= start_time
          return { valid: false, error: "終了時間は開始時間より後にしてください。" }
        end
        
        { valid: true, start_time: start_time, end_time: end_time }
      else
        { valid: false, error: "正しい時間形式で入力してください。\n例: 9:00-17:00" }
      end
    rescue ArgumentError
      { valid: false, error: "正しい時間形式で入力してください。\n例: 9:00-17:00" }
    end
  end

  # 従業員選択の検証
  def self.validate_employee_selection(employee_name, available_employees)
    return { valid: false, error: "従業員名が入力されていません。" } if employee_name.blank?
    
    matches = LineUtilityService.new.find_employees_by_name(employee_name)
    
    if matches.empty?
      { valid: false, error: LineMessageGeneratorService.generate_employee_not_found_message(employee_name) }
    elsif matches.length > 1
      { valid: false, error: "multiple_matches", matches: matches }
    else
      { valid: true, employee: matches.first }
    end
  end

  # 番号選択の検証
  def self.validate_number_selection(number_string, max_number)
    return { valid: false, error: "番号が入力されていません。" } if number_string.blank?
    
    begin
      number = number_string.to_i
      if number < 1 || number > max_number
        { valid: false, error: "1から#{max_number}の間の番号を入力してください。" }
      else
        { valid: false, error: "invalid_number" }
      end
    rescue ArgumentError
      { valid: false, error: "正しい番号を入力してください。" }
    end
  end

  # シフト重複の検証
  def self.validate_shift_overlap(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      date: date
    )
    
    overlapping_shift = existing_shifts.find do |shift|
      # 時間の重複をチェック
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
    
    if overlapping_shift
      { valid: false, error: "指定された時間に既にシフトが存在します。" }
    else
      { valid: true }
    end
  end

  # 複数従業員のシフト重複検証
  def self.validate_multiple_employee_shifts(employee_ids, date, start_time, end_time)
    conflicts = []
    
    employee_ids.each do |employee_id|
      result = validate_shift_overlap(employee_id, date, start_time, end_time)
      unless result[:valid]
        employee = Employee.find(employee_id)
        conflicts << "#{employee.display_name}さん"
      end
    end
    
    if conflicts.any?
      { valid: false, error: "以下の従業員のシフトと重複します: #{conflicts.join(', ')}" }
    else
      { valid: true }
    end
  end

  # 日付範囲の検証
  def self.validate_date_range(start_date, end_date)
    if start_date > end_date
      { valid: false, error: "開始日は終了日より前にしてください。" }
    else
      { valid: true }
    end
  end

  # 時間範囲の検証
  def self.validate_time_range(start_time, end_time)
    if end_time <= start_time
      { valid: false, error: "終了時間は開始時間より後にしてください。" }
    else
      { valid: true }
    end
  end

  # 認証コードの検証
  def self.validate_verification_code(code_string)
    return { valid: false, error: "認証コードが入力されていません。" } if code_string.blank?
    
    if code_string.match?(/^\d{6}$/)
      { valid: true, code: code_string }
    else
      { valid: false, error: "6桁の数字で入力してください。" }
    end
  end

  # 従業員名の検証
  def self.validate_employee_name(name)
    return { valid: false, error: "従業員名が入力されていません。" } if name.blank?
    
    if name.length < 2
      { valid: false, error: "従業員名は2文字以上で入力してください。" }
    else
      { valid: true, name: name.strip }
    end
  end
end
