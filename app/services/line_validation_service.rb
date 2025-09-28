# frozen_string_literal: true

class LineValidationService
  def initialize; end

  # ===== 日付検証 =====

  # シフト日付の検証
  def validate_shift_date(date_text)
    date = Date.parse(date_text)
    if date < Date.current
      tomorrow = (Date.current + 1).strftime("%Y-%m-%d")
      return { error: "過去の日付は指定できません。\n日付を入力してください（例：#{tomorrow}）" }
    end

    { date: date }
  rescue ArgumentError
    tomorrow = (Date.current + 1).strftime("%Y-%m-%d")
    { error: "正しい日付形式で入力してください。\n例：#{tomorrow}" }
  end

  # 月/日形式の日付検証
  def validate_month_day_format(date_string)
    # 月/日形式のパターンマッチング
    if date_string.match?(/^\d{1,2}\/\d{1,2}$/)
      month, day = date_string.split("/").map(&:to_i)

      # 月の範囲チェック
      if month < 1 || month > 12
        return { valid: false, error: "月は1から12の間で入力してください。" }
      end

      # 日の範囲チェック
      if day < 1 || day > 31
        return { valid: false, error: "日は1から31の間で入力してください。" }
      end

      # 現在の年を使用して日付を作成
      current_year = Date.current.year
      begin
        date = Date.new(current_year, month, day)

        # 過去の日付チェック
        if date < Date.current
          # 来年の日付として再試行
          date = Date.new(current_year + 1, month, day)
        end

        { valid: true, date: date }
      rescue ArgumentError
        { valid: false, error: "無効な日付です。正しい日付を入力してください。" }
      end
    else
      { valid: false, error: "正しい日付形式で入力してください。\n例: 9/20 または 09/20" }
    end
  end

  # 日付の検証とフォーマット
  def validate_and_format_date(date_string)
    return { valid: false, error: "日付が入力されていません。" } if date_string.blank?

    begin
      # 様々な日付形式に対応
      date = case date_string
             when /^\d{4}-\d{2}-\d{2}$/
               Date.parse(date_string)
             when %r{^\d{2}/\d{2}$}
               current_year = Date.current.year
               Date.parse("#{current_year}/#{date_string}")
             when %r{^\d{1,2}/\d{1,2}$}
               current_year = Date.current.year
               Date.parse("#{current_year}/#{date_string}")
             else
               Date.parse(date_string)
             end

      # 過去の日付は許可しない
      return { valid: false, error: "過去の日付は指定できません。" } if date < Date.current

      { valid: true, date: date }
    rescue ArgumentError
      { valid: false, error: "正しい日付形式で入力してください。\n例: 2024-01-15 または 1/15" }
    end
  end

  # 完全な日付形式の検証
  def validate_full_date_format(date_string)
    # 既存のvalidate_and_format_dateを使用
    result = validate_and_format_date(date_string)
    if result[:valid]
      { valid: true, date: result[:date] }
    else
      { valid: false, error: result[:error] }
    end
  end

  # 日付範囲の検証
  def validate_date_range(start_date, end_date)
    return { error: "開始日は終了日より前である必要があります。" } if start_date > end_date

    return { error: "終了日は今日以降である必要があります。" } if end_date < Date.current

    { valid: true }
  end

  # ===== 時間検証 =====

  # シフト時間の検証
  def validate_shift_time(time_text)
    # 時間形式の検証（HH:MM-HH:MM）
    return { error: "時間の形式が正しくありません。\n例：09:00-18:00" } unless time_text.match?(/^\d{2}:\d{2}-\d{2}:\d{2}$/)

    begin
      start_time_str, end_time_str = time_text.split("-")
      start_time = Time.parse(start_time_str)
      end_time = Time.parse(end_time_str)

      return { error: "終了時間は開始時間より後である必要があります。" } if end_time <= start_time

      { start_time: start_time, end_time: end_time }
    rescue ArgumentError
      { error: "正しい時間形式で入力してください。\n例：09:00-18:00" }
    end
  end

  # 時間の検証とフォーマット
  def validate_and_format_time(time_string)
    return { valid: false, error: "時間が入力されていません。" } if time_string.blank?

    begin
      # 時間範囲の形式をチェック (例: 9:00-17:00)
      if time_string.match?(/^\d{1,2}:\d{2}-\d{1,2}:\d{2}$/)
        start_time_str, end_time_str = time_string.split("-")
        start_time = Time.parse(start_time_str)
        end_time = Time.parse(end_time_str)

        # 終了時間が開始時間より後であることを確認
        return { valid: false, error: "終了時間は開始時間より後にしてください。" } if end_time <= start_time

        { valid: true, start_time: start_time, end_time: end_time }
      else
        { valid: false, error: "正しい時間形式で入力してください。\n例: 9:00-17:00" }
      end
    rescue ArgumentError
      { valid: false, error: "正しい時間形式で入力してください。\n例: 9:00-17:00" }
    end
  end

  # 時間範囲の検証
  def validate_time_range(start_time, end_time)
    return { error: "終了時間は開始時間より後である必要があります。" } if end_time <= start_time

    # 24時間を超えるシフトは不可
    return { error: "シフト時間は24時間以内である必要があります。" } if (end_time - start_time) > 24.hours

    { valid: true }
  end

  # ===== 従業員検証 =====

  # 従業員IDフォーマットの検証
  def valid_employee_id_format?(employee_id)
    employee_id.is_a?(String) && employee_id.match?(/^\d+$/)
  end

  # 従業員名の検証
  def validate_employee_name(name)
    return { error: "従業員名を入力してください。" } if name.blank?

    return { error: "従業員名が長すぎます。50文字以内で入力してください。" } if name.length > 50

    return { error: "従業員名に使用できない文字が含まれています。" } if name.match?(/[^\p{Hiragana}\p{Katakana}\p{Han}a-zA-Z\s]/)

    { valid: true }
  end

  # 従業員選択の検証
  def validate_employee_selection(employee_name, _available_employees)
    return { valid: false, error: "従業員名が入力されていません。" } if employee_name.blank?

    matches = LineUtilityService.new.find_employees_by_name(employee_name)

    if matches.empty?
      { valid: false, error: generate_employee_not_found_message(employee_name) }
    elsif matches.length > 1
      { valid: false, error: "multiple_matches", matches: matches }
    else
      { valid: true, employee: matches.first }
    end
  end

  # 従業員選択の解析
  def parse_employee_selection(message_text)
    # カンマ区切りで分割
    selections = message_text.split(",").map(&:strip)
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

  # ===== 認証検証 =====

  # 認証コードの検証
  def validate_verification_code(code)
    return { error: "認証コードを入力してください。" } if code.blank?

    return { error: "認証コードは6桁の数字で入力してください。" } unless code.match?(/^\d{6}$/)

    { valid: true }
  end

  # 認証コードの検証（文字列版）
  def validate_verification_code_string(code_string)
    return { valid: false, error: "認証コードが入力されていません。" } if code_string.blank?

    if code_string.match?(/^\d{6}$/)
      { valid: true, code: code_string }
    else
      { valid: false, error: "6桁の数字で入力してください。" }
    end
  end

  # ===== シフト重複検証 =====

  # シフト重複の検証
  def validate_shift_overlap(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
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

  # シフト重複の検証（静的メソッド版）
  def self.validate_shift_overlap(employee_id, date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: date
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
  def validate_multiple_employee_shifts(employee_ids, date, start_time, end_time)
    available_employees = []
    overlapping_employees = []

    employee_ids.each do |employee_id|
      overlap_result = validate_shift_overlap(employee_id, date, start_time, end_time)

      employee = Employee.find_by(employee_id: employee_id)
      if overlap_result[:has_overlap]
        if employee
          overlapping_employees << {
            employee: employee,
            overlap_info: overlap_result
          }
        end
      elsif employee
        available_employees << employee
      end
    end

    {
      available_employees: available_employees,
      overlapping_employees: overlapping_employees
    }
  end

  # 複数従業員のシフト重複検証（静的メソッド版）
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

  # ===== 数値・選択検証 =====

  # 数値入力の検証
  def validate_numeric_input(input, min: nil, max: nil)
    return { error: "数値を入力してください。" } if input.blank?

    begin
      number = input.to_i

      return { error: "#{min}以上の数値を入力してください。" } if min && number < min

      return { error: "#{max}以下の数値を入力してください。" } if max && number > max

      { valid: true, value: number }
    rescue ArgumentError
      { error: "有効な数値を入力してください。" }
    end
  end

  # 番号選択の検証
  def validate_number_selection(number_string, max_number)
    return { valid: false, error: "番号が入力されていません。" } if number_string.blank?

    begin
      number = number_string.to_i
      if number < 1 || number > max_number
        { valid: false, error: "1から#{max_number}の間の番号を入力してください。" }
      else
        { valid: true, value: number }
      end
    rescue ArgumentError
      { valid: false, error: "正しい番号を入力してください。" }
    end
  end

  # 選択肢の検証
  def validate_selection(selection, options)
    return { error: "選択肢を入力してください。" } if selection.blank?

    if selection.match?(/^\d+$/)
      index = selection.to_i
      return { error: "1から#{options.length}の数字を入力してください。" } if index < 1 || index > options.length

      { valid: true, index: index - 1, value: options[index - 1] }
    else
      # 文字列での選択
      matching_options = options.select { |option| option.to_s.include?(selection) }

      if matching_options.empty?
        { error: "該当する選択肢が見つかりません。" }
      elsif matching_options.length > 1
        { error: "複数の選択肢が該当します。より具体的に入力してください。" }
      else
        { valid: true, value: matching_options.first }
      end
    end
  end

  # 確認入力の検証
  def validate_confirmation_input(input)
    case input.downcase
    when "はい", "yes", "y", "ok", "承認"
      { valid: true, confirmed: true }
    when "いいえ", "no", "n", "キャンセル", "否認"
      { valid: true, confirmed: false }
    else
      { error: "「はい」または「いいえ」で回答してください。" }
    end
  end

  # ===== その他検証 =====

  # リクエストIDの検証
  def validate_request_id(request_id)
    return { error: "リクエストIDが指定されていません。" } if request_id.blank?

    return { error: "無効なリクエストIDです。" } unless request_id.match?(/^[A-Z_]+_\d{8}_\d{6}_[a-f0-9]{8}$/)

    { valid: true }
  end

  # メッセージテキストの検証
  def validate_message_text(text)
    return { error: "メッセージが空です。" } if text.blank?

    return { error: "メッセージが長すぎます。2000文字以内で入力してください。" } if text.length > 2000

    { valid: true }
  end

  # ===== メッセージ生成 =====

  # 複数従業員マッチ時のメッセージ生成
  def generate_multiple_employee_selection_message(employee_name, matches)
    message = "「#{employee_name}」に該当する従業員が複数見つかりました。\n\n"
    message += "該当する従業員の番号を入力してください:\n\n"

    matches.each_with_index do |employee, index|
      display_name = employee[:display_name] || employee["display_name"]
      employee_id = employee[:id] || employee["id"]
      message += "#{index + 1}. #{display_name} (ID: #{employee_id})\n"
    end

    message += "\n番号を入力してください:"
    message
  end

  # 従業員が見つからない場合のメッセージ生成
  def generate_employee_not_found_message(employee_name)
    "「#{employee_name}」に該当する従業員が見つかりませんでした。\n\nフルネームでも部分入力でも検索できます。\n再度従業員名を入力してください:"
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
