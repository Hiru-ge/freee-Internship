class FreeeApiService
  include HTTParty

  base_uri "https://api.freee.co.jp"

  CACHE_DURATION = 5.minutes
  RATE_LIMIT_DELAY = 1.second

  def initialize(access_token, company_id)
    @access_token = access_token
    @company_id = company_id.to_s
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
  def get_employees
    cache_key = "employees_#{@company_id}"
    if (cached_data = get_cached_data(cache_key))
      return cached_data
    end

    begin

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
      result = employees.sort_by { |emp| emp["id"] }.map do |emp|
        {
          id: emp["id"].to_s,
          display_name: emp["display_name"],
          email: emp["email"]
        }
      end
      set_cached_data(cache_key, result)
      result
    rescue StandardError => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"
      []
    end
  end
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
    employees.sort_by { |emp| emp["id"] }
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    Rails.logger.error "Error class: #{e.class}"
    Rails.logger.error "Error backtrace: #{e.backtrace.join('\n')}"
    []
  end
  def get_all_employees
    cache_key = "all_employees_#{@company_id}"
    if (cached_data = get_cached_data(cache_key))
      return cached_data
    end

    begin
      all = []
      limit = 50
      offset = 0

      loop do

        enforce_rate_limit

        url = "/hr/api/v1/companies/#{@company_id}/employees?limit=#{limit}&offset=#{offset}&with_no_payroll_calculation=true"
        response = self.class.get(url, @options)

        unless response.success?
          Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
          Rails.logger.error "Response body: #{response.body}"

          break
        end

        body = response.parsed_response
        page = body.is_a?(Array) ? body : body["employees"]
        page ||= []

        all.concat(page)
        break if page.size < limit

        offset += limit
      end
      result = all.sort_by { |emp| emp["id"] }
      set_cached_data(cache_key, result)
      result
    rescue StandardError => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      []
    end
  end
  def get_employee_info(employee_id)
    cache_key = "employee_info_#{employee_id}_#{@company_id}"
    if (cached_data = get_cached_data(cache_key))
      return cached_data
    end

    begin

      enforce_rate_limit

      now = Time.current
      response = self.class.get(
        "/hr/api/v1/employees/#{employee_id}?company_id=#{@company_id}&year=#{now.year}&month=#{now.month}",
        @options
      )

      if response.success?
        result = response.parsed_response["employee"]

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
  def get_time_clocks(employee_id, from_date = nil, to_date = nil)
    url = "/hr/api/v1/employees/#{employee_id}/time_clocks?company_id=#{@company_id}"

    url += "&from_date=#{from_date}&to_date=#{to_date}" if from_date && to_date
    response = self.class.get(url, @options)

    if response.success?
      parsed = response.parsed_response
      if parsed.is_a?(Array)

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
        1000
      end
    else
      Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
      1000
    end
  rescue StandardError => e
    Rails.logger.error "freee API接続エラー: #{e.message}"
    1000
  end
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
  def get_time_clocks_for_month(employee_id, year_month)

    year, month = year_month.split("-")
    from_date = "#{year}-#{month}-01"

    last_day = Date.new(year.to_i, month.to_i, -1).day
    to_date = "#{year}-#{month}-#{last_day}"

    url = "/hr/api/v1/employees/#{employee_id}/time_clocks?company_id=#{@company_id}&from_date=#{from_date}&to_date=#{to_date}"

    response = self.class.get(url, @options)

    if response.success?
      parsed = response.parsed_response
      time_clocks = if parsed.is_a?(Array)

                      parsed
                    elsif parsed.is_a?(Hash) && parsed["time_clocks"]
                      parsed["time_clocks"] || []
                    else
                      []
                    end
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
  def format_employee_for_rails(freee_employee)
    {
      employee_id: freee_employee["id"].to_s,
      name: freee_employee["display_name"],
      email: freee_employee["email"],
      role: determine_role(freee_employee["display_name"])
    }
  end
  def determine_role(display_name)

    owner_id = ENV["OWNER_EMPLOYEE_ID"]
    return "employee" unless owner_id
    owner_info = get_employee_info(owner_id)
    return "employee" unless owner_info

    display_name == owner_info["display_name"] ? "owner" : "employee"
  rescue StandardError => e
    Rails.logger.error "役割判定エラー: #{e.message}"
    "employee"
  end
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
  def set_cached_data(cache_key, data)
    @cache[cache_key] = {
      data: data,
      expires_at: Time.current + CACHE_DURATION
    }
  end
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
