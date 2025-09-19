# frozen_string_literal: true

class LineDateValidationService
  def self.validate_month_day_format(date_string)
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

  def self.validate_full_date_format(date_string)
    # 既存のLineValidationManagerServiceを使用
    result = LineValidationManagerService.validate_and_format_date(date_string)
    if result[:valid]
      { valid: true, date: result[:date] }
    else
      { valid: false, error: result[:error] }
    end
  end
end
