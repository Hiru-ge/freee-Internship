class FreeeApiService
  include HTTParty
  base_uri 'https://api.freee.co.jp'

  def initialize(access_token, company_id)
    @access_token = access_token
    @company_id = company_id
    @options = {
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    }
  end

  # 全従業員情報取得
  def get_all_employees
    begin
      all = []
      limit = 50
      offset = 0

      loop do
        url = "/hr/api/v1/companies/#{@company_id}/employees?limit=#{limit}&offset=#{offset}&with_no_payroll_calculation=true"
        response = self.class.get(url, @options)

        unless response.success?
          Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
          Rails.logger.error "Response body: #{response.body}"
          # 401/403は権限・トークンエラーとして即時中断
          break
        end

        body = response.parsed_response
        page = body.is_a?(Array) ? body : body['employees']
        page ||= []

        all.concat(page)

        # ページング判定（件数がlimit未満なら終端）
        break if page.size < limit

        offset += limit
      end

      # IDでソートして返却
      all.sort_by { |emp| emp['id'] }
    rescue => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      []
    end
  end

  # 特定従業員情報取得
  def get_employee_info(employee_id)
    begin
      now = Time.current
      response = self.class.get(
        "/hr/api/v1/employees/#{employee_id}?company_id=#{@company_id}&year=#{now.year}&month=#{now.month}",
        @options
      )
      
      if response.success?
        response.parsed_response['employee']
      else
        Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      nil
    end
  end

  # 従業員の勤怠データ取得
  def get_time_clocks(employee_id, from_date = nil, to_date = nil)
    begin
      url = "/hr/api/v1/employees/#{employee_id}/time_clocks?company_id=#{@company_id}"
      
      if from_date && to_date
        url += "&from_date=#{from_date}&to_date=#{to_date}"
      end
      
      response = self.class.get(url, @options)
      
      if response.success?
        response.parsed_response['time_clocks'] || []
      else
        Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
        Rails.logger.error "Response body: #{response.body}"
        []
      end
    rescue => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      []
    end
  end

  # 基本時給取得
  def get_hourly_wage(employee_id)
    begin
      now = Time.current
      response = self.class.get(
        "/hr/api/v1/employees/#{employee_id}/basic_pay_rule?company_id=#{@company_id}&year=#{now.year}&month=#{now.month}",
        @options
      )
      
      if response.success?
        pay_rule = response.parsed_response['employee_basic_pay_rule']
        if pay_rule && pay_rule['pay_amount'] && pay_rule['pay_amount'] > 0
          pay_rule['pay_amount']
        else
          1000 # デフォルト時給
        end
      else
        Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
        1000 # デフォルト時給
      end
    rescue => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      1000 # デフォルト時給
    end
  end

  # 事業所名取得
  def get_company_name
    begin
      response = self.class.get("/api/1/companies/#{@company_id}", @options)
      
      if response.success?
        response.parsed_response['company']['display_name']
      else
        Rails.logger.error "freee API Error: #{response.code} - #{response.message}"
        "不明な事業所"
      end
    rescue => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      "不明な事業所"
    end
  end

  # 勤怠打刻登録
  def post_work_record(employee_id, target_date, target_time, target_type)
    begin
      payload = {
        company_id: @company_id,
        type: target_type,
        date: 'string',
        datetime: "#{target_date} #{target_time}"
      }
      
      response = self.class.post(
        "/hr/api/v1/employees/#{employee_id}/time_clocks",
        @options.merge(body: payload.to_json)
      )
      
      if response.success?
        { success: true, message: '登録しました' }
      else
        error_message = response.parsed_response['message'] || '登録に失敗しました'
        Rails.logger.error "freee API Error: #{response.code} - #{error_message}"
        { success: false, message: error_message }
      end
    rescue => e
      Rails.logger.error "freee API接続エラー: #{e.message}"
      { success: false, message: '登録に失敗しました' }
    end
  end

  private

  # 従業員情報をRails用の形式に変換
  def format_employee_for_rails(freee_employee)
    {
      employee_id: freee_employee['id'].to_s,
      name: freee_employee['display_name'],
      email: freee_employee['email'],
      role: determine_role(freee_employee['display_name'])
    }
  end

  # 従業員の役割を判定（GAS時代の仕様に合わせる）
  def determine_role(display_name)
    # GAS時代の仕様: 従業員名が「店長 太郎」の場合はオーナー
    display_name == '店長 太郎' ? 'owner' : 'employee'
  end
end
