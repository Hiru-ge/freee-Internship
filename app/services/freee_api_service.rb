# frozen_string_literal: true

class FreeeApiService
  include HTTParty

  base_uri "https://api.freee.co.jp"

  # キャッシュ設定
  CACHE_DURATION = 5.minutes
  RATE_LIMIT_DELAY = 1.second

  def initialize(access_token, company_id)
    @access_token = access_token
    @company_id = company_id.to_s # 文字列に変換
    @options = {
      headers: {
        "Authorization" => "Bearer #{@access_token}",
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
    }
    @cache = {}
    @last_api_call = nil
  end

  # 従業員一覧取得（シフト管理用）
  def get_employees
    cache_key = "employees_#{@company_id}"

    # キャッシュチェック
    if (cached_data = get_cached_data(cache_key))
      return cached_data
    end

    begin
      # レート制限チェック
      enforce_rate_limit

      url = "/hr/api/v1/companies/#{@company_id}/employees?limit=100&with_no_payroll_calculation=true"
      response = self.class.get(url, @options)

      unless response.success?
        Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        return []
      end

      body = response.parsed_response
      employees = body.is_a?(Array) ? body : body["employees"]
      employees ||= []

      # シフト管理に必要な情報のみを返す（ID順でソート）
      result = employees.sort_by { |emp| emp["id"] }.map do |emp|
        {
          id: emp["id"].to_s,
          display_name: emp["display_name"],
          email: emp["email"]
        }
      end

      # キャッシュに保存
      set_cached_data(cache_key, result)
      result
    rescue StandardError => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"
      []
    end
  end

  # GAS時代のgetEmployeesを再現（全情報を返す）
  def get_employees_full
    url = "/hr/api/v1/companies/#{@company_id}/employees?limit=100&with_no_payroll_calculation=true"
    response = self.class.get(url, @options)

    unless response.success?
      Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
      Rails.logger.error "Response body: #{response.body}"
      return []
    end

    body = response.parsed_response
    employees = body.is_a?(Array) ? body : body["employees"]
    employees ||= []

    # GAS時代と同じように、IDでソートして全情報を返す
    employees.sort_by { |emp| emp["id"] }
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    Rails.logger.error "Error class: #{e.class}"
    Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"
    []
  end

  # 全従業員情報取得
  def get_all_employees
    cache_key = "all_employees_#{@company_id}"

    # キャッシュチェック
    if (cached_data = get_cached_data(cache_key))
      return cached_data
    end

    begin
      all = []
      limit = 50
      offset = 0

      loop do
        # レート制限チェック
        enforce_rate_limit

        url = "/hr/api/v1/companies/#{@company_id}/employees?limit=#{limit}&offset=#{offset}&with_no_payroll_calculation=true"
        response = self.class.get(url, @options)

        unless response.success?
          Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
          Rails.logger.error "Response body: #{response.body}"
          # 401/403は権限・トークンエラーとして即時中断
          break
        end

        body = response.parsed_response
        page = body.is_a?(Array) ? body : body["employees"]
        page ||= []

        all.concat(page)

        # ページング判定（件数がlimit未満なら終端）
        break if page.size < limit

        offset += limit
      end

      # IDでソートして返却
      result = all.sort_by { |emp| emp["id"] }

      # キャッシュに保存
      set_cached_data(cache_key, result)
      result
    rescue StandardError => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      []
    end
  end

  # 特定従業員情報取得
  def get_employee_info(employee_id)
    cache_key = "employee_info_#{employee_id}_#{@company_id}"

    # キャッシュチェック
    if (cached_data = get_cached_data(cache_key))
      return cached_data
    end

    begin
      # レート制限チェック
      enforce_rate_limit

      now = Time.current
      response = self.class.get(
        "/hr/api/v1/employees/#{employee_id}?company_id=#{@company_id}&year=#{now.year}&month=#{now.month}",
        @options
      )

      if response.success?
        result = response.parsed_response["employee"]
        # キャッシュに保存
        set_cached_data(cache_key, result)
        result
      else
        Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      nil
    end
  end

  # 従業員の勤怠データ取得
  def get_time_clocks(employee_id, from_date = nil, to_date = nil)
    url = "/hr/api/v1/employees/#{employee_id}/time_clocks?company_id=#{@company_id}"

    url += "&from_date=#{from_date}&to_date=#{to_date}" if from_date && to_date
    response = self.class.get(url, @options)

    if response.success?
      parsed = response.parsed_response
      if parsed.is_a?(Array)
        # freee APIは直接配列を返す
        parsed
      elsif parsed.is_a?(Hash) && parsed["time_clocks"]
        parsed["time_clocks"] || []
      else
        Rails.logger.warn "Unexpected response format: #{parsed.class}"
        []
      end
    else
      Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
      Rails.logger.error "Response body: #{response.body}"
      []
    end
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    Rails.logger.error "Error class: #{e.class}"
    Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join('\n')}"
    []
  end

  # 基本時給取得
  def get_hourly_wage(employee_id)
    now = Time.current
    response = self.class.get(
      "/hr/api/v1/employees/#{employee_id}/basic_pay_rule?company_id=#{@company_id}&year=#{now.year}&month=#{now.month}",
      @options
    )

    if response.success?
      pay_rule = response.parsed_response["employee_basic_pay_rule"]
      if pay_rule && pay_rule["pay_amount"]&.positive?
        pay_rule["pay_amount"]
      else
        1000 # デフォルト時給
      end
    else
      Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
      1000 # デフォルト時給
    end
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    1000 # デフォルト時給
  end

  # 事業所名取得
  def get_company_name
    response = self.class.get("/api/1/companies/#{@company_id}", @options)

    if response.success?
      response.parsed_response["company"]["display_name"]
    else
      Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
      "不明な事業所"
    end
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    "不明な事業所"
  end

  # 勤怠打刻登録
  def create_work_record(employee_id, form_data)
    payload = {
      company_id: @company_id,
      type: form_data[:target_type],
      date: form_data[:target_date],
      datetime: "#{form_data[:target_date]} #{form_data[:target_time]}"
    }

    response = self.class.post(
      "/hr/api/v1/employees/#{employee_id}/time_clocks",
      @options.merge(body: payload.to_json)
    )

    if response.success?
      "登録しました"
    else
      error_message = response.parsed_response["message"] || "登録に失敗しました"
      Rails.logger.error "freee API Error: #{response.code} - #{error_message}"
      error_message
    end
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    "登録に失敗しました"
  end

  # 月次勤怠データ取得
  def get_time_clocks_for_month(employee_id, year_month)
    # year_month形式: "2024-01"
    year, month = year_month.split("-")
    from_date = "#{year}-#{month}-01"
    # 月末日を取得
    last_day = Date.new(year.to_i, month.to_i, -1).day
    to_date = "#{year}-#{month}-#{last_day}"

    url = "/hr/api/v1/employees/#{employee_id}/time_clocks?company_id=#{@company_id}&from_date=#{from_date}&to_date=#{to_date}"

    response = self.class.get(url, @options)

    if response.success?
      parsed = response.parsed_response
      time_clocks = if parsed.is_a?(Array)
                      # freee APIは直接配列を返す
                      parsed
                    elsif parsed.is_a?(Hash) && parsed["time_clocks"]
                      parsed["time_clocks"] || []
                    else
                      []
                    end

      # GAS時代の形式に合わせて変換
      time_clocks.map do |clock|
        {
          type: clock["type"] == "clock_in" ? "出勤" : "退勤",
          date: clock["datetime"] ? Time.parse(clock["datetime"]).strftime("%Y-%m-%d %H:%M") : ""
        }
      end
    else
      Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
      []
    end
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    []
  end

  private

  # 従業員情報をRails用の形式に変換
  def format_employee_for_rails(freee_employee)
    {
      employee_id: freee_employee["id"].to_s,
      name: freee_employee["display_name"],
      email: freee_employee["email"],
      role: determine_role(freee_employee["display_name"])
    }
  end

  # 従業員の役割を判定（環境変数から取得）
  def determine_role(display_name)
    # 環境変数からオーナーIDを取得
    owner_id = ENV["OWNER_EMPLOYEE_ID"]
    return "employee" unless owner_id

    # freee APIからオーナーの従業員情報を取得
    owner_info = get_employee_info(owner_id)
    return "employee" unless owner_info

    display_name == owner_info["display_name"] ? "owner" : "employee"
  rescue StandardError => e
    Rails.logger.error "役割判定エラー: #{e.message}"
    "employee"
  end

  # キャッシュからデータを取得
  def get_cached_data(cache_key)
    cached_entry = @cache[cache_key]
    return nil unless cached_entry

    if cached_entry[:expires_at] > Time.current
      cached_entry[:data]
    else
      @cache.delete(cache_key)
      nil
    end
  end

  # キャッシュにデータを保存
  def set_cached_data(cache_key, data)
    @cache[cache_key] = {
      data: data,
      expires_at: Time.current + CACHE_DURATION
    }
  end

  # レート制限の強制
  def enforce_rate_limit
    return unless @last_api_call

    time_since_last_call = Time.current - @last_api_call
    if time_since_last_call < RATE_LIMIT_DELAY
      sleep_time = RATE_LIMIT_DELAY - time_since_last_call
      sleep(sleep_time)
    end
  ensure
    @last_api_call = Time.current
  end
end
