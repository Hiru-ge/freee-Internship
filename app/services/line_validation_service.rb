class LineValidationService
  def initialize
  end

  # シフト日付の検証
  def validate_shift_date(date_text)
    begin
      date = Date.parse(date_text)
      if date < Date.current
        tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
        return { error: "過去の日付は指定できません。\n日付を入力してください（例：#{tomorrow}）" }
      end
      
      { date: date }
    rescue ArgumentError
      tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
      { error: "正しい日付形式で入力してください。\n例：#{tomorrow}" }
    end
  end

  # シフト時間の検証
  def validate_shift_time(time_text)
    # 時間形式の検証（HH:MM-HH:MM）
    unless time_text.match?(/^\d{2}:\d{2}-\d{2}:\d{2}$/)
      return { error: "時間の形式が正しくありません。\n例：09:00-18:00" }
    end

    begin
      start_time_str, end_time_str = time_text.split('-')
      start_time = Time.parse(start_time_str)
      end_time = Time.parse(end_time_str)
      
      if end_time <= start_time
        return { error: "終了時間は開始時間より後である必要があります。" }
      end
      
      { start_time: start_time, end_time: end_time }
    rescue ArgumentError
      { error: "正しい時間形式で入力してください。\n例：09:00-18:00" }
    end
  end

  # 従業員IDフォーマットの検証
  def valid_employee_id_format?(employee_id)
    employee_id.is_a?(String) && employee_id.match?(/^\d+$/)
  end

  # 従業員名の検証
  def validate_employee_name(name)
    return { error: "従業員名を入力してください。" } if name.blank?
    
    if name.length > 50
      return { error: "従業員名が長すぎます。50文字以内で入力してください。" }
    end
    
    if name.match?(/[^\p{Hiragana}\p{Katakana}\p{Han}a-zA-Z\s]/)
      return { error: "従業員名に使用できない文字が含まれています。" }
    end
    
    { valid: true }
  end

  # 認証コードの検証
  def validate_verification_code(code)
    return { error: "認証コードを入力してください。" } if code.blank?
    
    unless code.match?(/^\d{6}$/)
      return { error: "認証コードは6桁の数字で入力してください。" }
    end
    
    { valid: true }
  end

  # 従業員選択の解析
  def parse_employee_selection(message_text)
    # カンマ区切りで分割
    selections = message_text.split(',').map(&:strip)
    employee_ids = []
    ambiguous_names = []
    not_found_names = []
    
    selections.each do |selection|
      if selection.match?(/^\d+$/)
        # 数値の場合は従業員IDとして扱う
        employee_ids << selection.to_i
      else
        # 文字列の場合は従業員名として検索
        matches = find_employees_by_name(selection)
        if matches.empty?
          not_found_names << selection
        elsif matches.length > 1
          ambiguous_names << selection
        else
          employee_ids << matches.first.employee_id
        end
      end
    end
    
    {
      employee_ids: employee_ids,
      ambiguous_names: ambiguous_names,
      not_found_names: not_found_names
    }
  end

  # 従業員名で検索
  def find_employees_by_name(name)
    LineUtilityService.new.find_employees_by_name(name)
  end


  # シフト重複の検証
  def validate_shift_overlap(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      date: date
    )
    
    overlapping_shifts = existing_shifts.select do |shift|
      # 時間の重複チェック
      (start_time < shift.end_time) && (end_time > shift.start_time)
    end
    
    if overlapping_shifts.any?
      overlap_info = overlapping_shifts.map do |shift|
        "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}"
      end
      
      {
        has_overlap: true,
        overlapping_times: overlap_info,
        message: "指定時間に既存のシフトが重複しています: #{overlap_info.join(', ')}"
      }
    else
      { has_overlap: false }
    end
  end

  # 複数従業員のシフト重複検証
  def validate_multiple_employee_shifts(employee_ids, date, start_time, end_time)
    available_employees = []
    overlapping_employees = []
    
    employee_ids.each do |employee_id|
      overlap_result = validate_shift_overlap(employee_id, date, start_time, end_time)
      
      if overlap_result[:has_overlap]
        employee = Employee.find_by(employee_id: employee_id)
        overlapping_employees << {
          employee: employee,
          overlap_info: overlap_result
        } if employee
      else
        employee = Employee.find_by(employee_id: employee_id)
        available_employees << employee if employee
      end
    end
    
    {
      available_employees: available_employees,
      overlapping_employees: overlapping_employees
    }
  end

  # 日付範囲の検証
  def validate_date_range(start_date, end_date)
    if start_date > end_date
      return { error: "開始日は終了日より前である必要があります。" }
    end
    
    if end_date < Date.current
      return { error: "終了日は今日以降である必要があります。" }
    end
    
    { valid: true }
  end

  # 時間範囲の検証
  def validate_time_range(start_time, end_time)
    if end_time <= start_time
      return { error: "終了時間は開始時間より後である必要があります。" }
    end
    
    # 24時間を超えるシフトは不可
    if (end_time - start_time) > 24.hours
      return { error: "シフト時間は24時間以内である必要があります。" }
    end
    
    { valid: true }
  end

  # リクエストIDの検証
  def validate_request_id(request_id)
    return { error: "リクエストIDが指定されていません。" } if request_id.blank?
    
    unless request_id.match?(/^[A-Z_]+_\d{8}_\d{6}_[a-f0-9]{8}$/)
      return { error: "無効なリクエストIDです。" }
    end
    
    { valid: true }
  end

  # メッセージテキストの検証
  def validate_message_text(text)
    return { error: "メッセージが空です。" } if text.blank?
    
    if text.length > 2000
      return { error: "メッセージが長すぎます。2000文字以内で入力してください。" }
    end
    
    { valid: true }
  end

  # 数値入力の検証
  def validate_numeric_input(input, min: nil, max: nil)
    return { error: "数値を入力してください。" } if input.blank?
    
    begin
      number = input.to_i
      
      if min && number < min
        return { error: "#{min}以上の数値を入力してください。" }
      end
      
      if max && number > max
        return { error: "#{max}以下の数値を入力してください。" }
      end
      
      { valid: true, value: number }
    rescue ArgumentError
      { error: "有効な数値を入力してください。" }
    end
  end

  # 選択肢の検証
  def validate_selection(selection, options)
    return { error: "選択肢を入力してください。" } if selection.blank?
    
    if selection.match?(/^\d+$/)
      index = selection.to_i
      if index < 1 || index > options.length
        return { error: "1から#{options.length}の数字を入力してください。" }
      end
      
      { valid: true, index: index - 1, value: options[index - 1] }
    else
      # 文字列での選択
      matching_options = options.select { |option| option.to_s.include?(selection) }
      
      if matching_options.empty?
        return { error: "該当する選択肢が見つかりません。" }
      elsif matching_options.length > 1
        return { error: "複数の選択肢が該当します。より具体的に入力してください。" }
      else
        { valid: true, value: matching_options.first }
      end
    end
  end

  # 確認入力の検証
  def validate_confirmation_input(input)
    case input.downcase
    when 'はい', 'yes', 'y', 'ok', '承認'
      { valid: true, confirmed: true }
    when 'いいえ', 'no', 'n', 'キャンセル', '否認'
      { valid: true, confirmed: false }
    else
      { error: "「はい」または「いいえ」で回答してください。" }
    end
  end

  private

  # ログ出力
  def log_validation_error(field, value, error)
    Rails.logger.warn "[LineValidationService] Validation failed for #{field}: #{value} - #{error}"
  end

  def log_validation_success(field, value)
    Rails.logger.debug "[LineValidationService] Validation passed for #{field}: #{value}"
  end
end
