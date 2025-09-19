# API統合仕様書

勤怠管理システムとFreee APIの統合仕様です。

## 🎯 概要

勤怠管理システムがFreee APIと連携して従業員情報を取得・管理するための仕様です。

## 🔗 Freee API統合

### 基本情報
- **API**: Freee API v1
- **認証**: OAuth 2.0
- **エンドポイント**: https://api.freee.co.jp/hr/api/v1/
- **レート制限**: 1000リクエスト/時間

### 認証設定
```ruby
# 環境変数
FREEE_CLIENT_ID=your_client_id
FREEE_CLIENT_SECRET=your_client_secret
FREEE_REDIRECT_URI=your_redirect_uri
FREEE_ACCESS_TOKEN=your_access_token
```

## 👥 従業員情報取得

### エンドポイント
```
GET /employees
```

### リクエスト例
```ruby
def fetch_employees
  response = HTTParty.get(
    'https://api.freee.co.jp/hr/api/v1/employees',
    headers: {
      'Authorization' => "Bearer #{ENV['FREEE_ACCESS_TOKEN']}",
      'Content-Type' => 'application/json'
    }
  )

  if response.success?
    JSON.parse(response.body)
  else
    handle_api_error(response)
  end
end
```

### レスポンス例
```json
{
  "employees": [
    {
      "id": 123456,
      "num": "EMP001",
      "display_name": "田中太郎",
      "first_name": "太郎",
      "last_name": "田中",
      "first_name_kana": "タロウ",
      "last_name_kana": "タナカ",
      "email": "tanaka@example.com",
      "status": "active",
      "role": "employee"
    }
  ]
}
```

### データマッピング
```ruby
def map_employee_data(freee_employee)
  {
    employee_id: freee_employee['num'],
    name: freee_employee['display_name'],
    email: freee_employee['email'],
    role: determine_role(freee_employee['role']),
    status: freee_employee['status']
  }
end
```

## 🔍 従業員検索

### 検索ロジック
```ruby
def search_employees_by_name(name)
  employees = fetch_employees
  normalized_name = normalize_name(name)

  employees['employees'].select do |employee|
    normalized_display_name = normalize_name(employee['display_name'])
    normalized_display_name.include?(normalized_name)
  end
end

def normalize_name(name)
  name.to_s
      .tr('ァ-ン', 'ぁ-ん')  # カタカナ → ひらがな
      .gsub(/\s+/, '')       # スペース除去
      .downcase
end
```

### 検索例
```
入力: "タナカ タロウ"
正規化: "たなか たろう"
検索: "たなかたろう" で部分一致検索
結果: 田中太郎 (display_name: "田中太郎")
```

## 📊 シフト情報取得

### エンドポイント
```
GET /work_records
```

### リクエスト例
```ruby
def fetch_work_records(employee_id, start_date, end_date)
  response = HTTParty.get(
    'https://api.freee.co.jp/hr/api/v1/work_records',
    headers: {
      'Authorization' => "Bearer #{ENV['FREEE_ACCESS_TOKEN']}",
      'Content-Type' => 'application/json'
    },
    query: {
      employee_id: employee_id,
      start_date: start_date,
      end_date: end_date
    }
  )

  if response.success?
    JSON.parse(response.body)
  else
    handle_api_error(response)
  end
end
```

### レスポンス例
```json
{
  "work_records": [
    {
      "id": 789012,
      "employee_id": 123456,
      "date": "2024-12-25",
      "start_time": "09:00",
      "end_time": "17:00",
      "break_time": 60,
      "work_type": "normal"
    }
  ]
}
```

## 🔄 データ同期

### 同期処理
```ruby
def sync_employees
  freee_employees = fetch_employees

  freee_employees['employees'].each do |freee_employee|
    employee_data = map_employee_data(freee_employee)

    employee = Employee.find_or_initialize_by(
      employee_id: employee_data[:employee_id]
    )

    employee.update!(
      name: employee_data[:name],
      email: employee_data[:email],
      role: employee_data[:role]
    )
  end
end
```

### 同期スケジュール
- **従業員情報**: 毎日午前6時
- **シフト情報**: 毎日午前7時
- **手動同期**: 管理者による手動実行

## 🛡️ エラーハンドリング

### API エラー
```ruby
def handle_api_error(response)
  case response.code
  when 401
    raise "認証エラー: アクセストークンが無効です"
  when 403
    raise "権限エラー: アクセス権限がありません"
  when 429
    raise "レート制限: リクエスト制限に達しました"
  when 500
    raise "サーバーエラー: Freee APIでエラーが発生しました"
  else
    raise "API エラー: #{response.code} - #{response.body}"
  end
end
```

### リトライ処理
```ruby
def fetch_with_retry(max_retries = 3)
  retries = 0

  begin
    yield
  rescue => e
    retries += 1
    if retries <= max_retries
      sleep(2 ** retries)  # 指数バックオフ
      retry
    else
      raise e
    end
  end
end
```

## 📝 ログ・監視

### ログ出力
```ruby
def log_api_call(endpoint, response)
  Rails.logger.info "Freee API Call: #{endpoint}"
  Rails.logger.info "Response Code: #{response.code}"
  Rails.logger.info "Response Time: #{response.total_time}ms"

  if response.code >= 400
    Rails.logger.error "API Error: #{response.body}"
  end
end
```

### 監視項目
- API レスポンス時間
- エラー発生率
- レート制限の発生
- データ同期の成功率

## 🔧 設定管理

### 環境変数
```bash
# Freee API設定
FREEE_CLIENT_ID=your_client_id
FREEE_CLIENT_SECRET=your_client_secret
FREEE_REDIRECT_URI=your_redirect_uri
FREEE_ACCESS_TOKEN=your_access_token

# API設定
FREEE_API_BASE_URL=https://api.freee.co.jp/hr/api/v1
FREEE_API_TIMEOUT=30
FREEE_API_RETRY_COUNT=3
```

### 設定クラス
```ruby
class FreeeApiConfig
  def self.base_url
    ENV['FREEE_API_BASE_URL'] || 'https://api.freee.co.jp/hr/api/v1'
  end

  def self.timeout
    ENV['FREEE_API_TIMEOUT']&.to_i || 30
  end

  def self.retry_count
    ENV['FREEE_API_RETRY_COUNT']&.to_i || 3
  end
end
```

## 🧪 テスト仕様

### 単体テスト
```ruby
describe FreeeApiService do
  describe '#fetch_employees' do
    it '従業員情報を正常に取得できる' do
      stub_request(:get, "https://api.freee.co.jp/hr/api/v1/employees")
        .to_return(
          status: 200,
          body: { employees: [] }.to_json
        )

      result = FreeeApiService.new.fetch_employees
      expect(result).to be_a(Hash)
    end

    it 'API エラー時に適切なエラーを発生させる' do
      stub_request(:get, "https://api.freee.co.jp/hr/api/v1/employees")
        .to_return(status: 401)

      expect {
        FreeeApiService.new.fetch_employees
      }.to raise_error(/認証エラー/)
    end
  end
end
```

### 統合テスト
```ruby
describe 'Freee API Integration' do
  it '従業員情報の同期が正常に動作する' do
    # モックデータの準備
    freee_response = {
      employees: [
        {
          id: 123456,
          num: 'EMP001',
          display_name: '田中太郎',
          email: 'tanaka@example.com'
        }
      ]
    }

    stub_request(:get, "https://api.freee.co.jp/hr/api/v1/employees")
      .to_return(status: 200, body: freee_response.to_json)

    # 同期実行
    FreeeApiService.new.sync_employees

    # データベースの確認
    employee = Employee.find_by(employee_id: 'EMP001')
    expect(employee.name).to eq('田中太郎')
  end
end
```

## 🚀 今後の拡張予定

### 機能拡張
- リアルタイム同期
- バッチ処理の最適化
- データの差分同期
- エラーハンドリングの強化

### パフォーマンス改善
- キャッシュ機能の追加
- 並列処理の実装
- レスポンス時間の最適化

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
