# API仕様書

勤怠管理システムのAPI仕様書です。このシステムはRuby on Rails 8.0.2で構築されており、RESTful APIを提供しています。

## ベースURL

- 開発環境: `http://localhost:3000`
- 本番環境: `https://your-app-name.fly.dev`

## タイムゾーン

- **設定**: Asia/Tokyo (JST +09:00)
- **時刻処理**: すべての時刻処理で`Time.current`を使用
- **打刻機能**: 日本時間で正確な時刻記録

## 認証

### セッション認証
- ログイン後にセッションCookieで認証状態を維持
- 未認証の場合はログインページにリダイレクト
- CSRFトークンによる保護

### メール認証
- メールアドレス + 認証コードによる認証
- 認証コードは6桁の数字
- 有効期限: 10分

## エンドポイント一覧

### 認証関連

#### POST /auth/login
メールアドレスでログイン

**リクエスト**
```json
{
  "email": "user@example.com"
}
```

**レスポンス**
```json
{
  "message": "認証コードをメールで送信しました",
  "status": "success"
}
```

#### POST /auth/verify
認証コードで認証完了

**リクエスト**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**レスポンス**
```json
{
  "message": "認証が完了しました",
  "status": "success",
  "user": {
    "id": 1,
    "name": "田中太郎",
    "email": "user@example.com"
  }
}
```

#### DELETE /auth/logout
ログアウト

**レスポンス**
```json
{
  "message": "ログアウトしました",
  "status": "success"
}
```

### シフト管理

#### GET /shifts
シフト一覧取得

**クエリパラメータ**
- `start_date`: 開始日 (YYYY-MM-DD)
- `end_date`: 終了日 (YYYY-MM-DD)
- `employee_id`: 従業員ID (オプション)

**レスポンス**
```json
{
  "shifts": [
    {
      "id": 1,
      "employee_id": 1,
      "employee_name": "田中太郎",
      "date": "2024-01-15",
      "start_time": "09:00",
      "end_time": "17:00",
      "status": "confirmed"
    }
  ]
}
```

#### POST /shifts
シフト作成

**リクエスト**
```json
{
  "employee_id": 1,
  "date": "2024-01-15",
  "start_time": "09:00",
  "end_time": "17:00"
}
```

**レスポンス**
```json
{
  "shift": {
    "id": 1,
    "employee_id": 1,
    "employee_name": "田中太郎",
    "date": "2024-01-15",
    "start_time": "09:00",
    "end_time": "17:00",
    "status": "confirmed"
  },
  "status": "success"
}
```

#### PUT /shifts/:id
シフト更新

**リクエスト**
```json
{
  "start_time": "10:00",
  "end_time": "18:00"
}
```

**レスポンス**
```json
{
  "shift": {
    "id": 1,
    "employee_id": 1,
    "employee_name": "田中太郎",
    "date": "2024-01-15",
    "start_time": "10:00",
    "end_time": "18:00",
    "status": "confirmed"
  },
  "status": "success"
}
```

#### DELETE /shifts/:id
シフト削除

**レスポンス**
```json
{
  "message": "シフトを削除しました",
  "status": "success"
}
```

### シフト交代申請

#### GET /shift_requests
シフト交代申請一覧取得

**クエリパラメータ**
- `status`: ステータス (pending, approved, rejected)
- `employee_id`: 従業員ID (オプション)

**レスポンス**
```json
{
  "requests": [
    {
      "id": 1,
      "requester_id": 1,
      "requester_name": "田中太郎",
      "target_employee_id": 2,
      "target_employee_name": "佐藤花子",
      "shift_id": 1,
      "shift_date": "2024-01-15",
      "status": "pending",
      "created_at": "2024-01-10T09:00:00Z"
    }
  ]
}
```

#### POST /shift_requests
シフト交代申請作成

**リクエスト**
```json
{
  "shift_id": 1,
  "target_employee_id": 2
}
```

**レスポンス**
```json
{
  "request": {
    "id": 1,
    "requester_id": 1,
    "requester_name": "田中太郎",
    "target_employee_id": 2,
    "target_employee_name": "佐藤花子",
    "shift_id": 1,
    "shift_date": "2024-01-15",
    "status": "pending",
    "created_at": "2024-01-10T09:00:00Z"
  },
  "status": "success"
}
```

#### PUT /shift_requests/:id/approve
シフト交代申請承認

**レスポンス**
```json
{
  "message": "申請を承認しました",
  "status": "success"
}
```

#### PUT /shift_requests/:id/reject
シフト交代申請拒否

**リクエスト**
```json
{
  "reason": "スケジュールの都合"
}
```

**レスポンス**
```json
{
  "message": "申請を拒否しました",
  "status": "success"
}
```

### 欠勤申請

#### GET /absence_requests
欠勤申請一覧取得

**クエリパラメータ**
- `status`: ステータス (pending, approved, rejected)
- `employee_id`: 従業員ID (オプション)

**レスポンス**
```json
{
  "requests": [
    {
      "id": 1,
      "employee_id": 1,
      "employee_name": "田中太郎",
      "shift_id": 1,
      "shift_date": "2024-01-15",
      "reason": "体調不良のため",
      "status": "pending",
      "created_at": "2024-01-10T09:00:00Z"
    }
  ]
}
```

#### POST /absence_requests
欠勤申請作成

**リクエスト**
```json
{
  "shift_id": 1,
  "reason": "体調不良のため"
}
```

**レスポンス**
```json
{
  "request": {
    "id": 1,
    "employee_id": 1,
    "employee_name": "田中太郎",
    "shift_id": 1,
    "shift_date": "2024-01-15",
    "reason": "体調不良のため",
    "status": "pending",
    "created_at": "2024-01-10T09:00:00Z"
  },
  "status": "success"
}
```

#### PUT /absence_requests/:id/approve
欠勤申請承認

**レスポンス**
```json
{
  "message": "申請を承認しました",
  "status": "success"
}
```

#### PUT /absence_requests/:id/reject
欠勤申請拒否

**リクエスト**
```json
{
  "reason": "代替要員の確保が困難"
}
```

**レスポンス**
```json
{
  "message": "申請を拒否しました",
  "status": "success"
}
```

### 従業員管理

#### GET /employees
従業員一覧取得

**レスポンス**
```json
{
  "employees": [
    {
      "id": 1,
      "name": "田中太郎",
      "email": "tanaka@example.com",
      "role": "employee",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /employees
従業員作成

**リクエスト**
```json
{
  "name": "田中太郎",
  "email": "tanaka@example.com",
  "role": "employee"
}
```

**レスポンス**
```json
{
  "employee": {
    "id": 1,
    "name": "田中太郎",
    "email": "tanaka@example.com",
    "role": "employee",
    "created_at": "2024-01-01T00:00:00Z"
  },
  "status": "success"
}
```

#### PUT /employees/:id
従業員更新

**リクエスト**
```json
{
  "name": "田中太郎（更新）",
  "role": "manager"
}
```

**レスポンス**
```json
{
  "employee": {
    "id": 1,
    "name": "田中太郎（更新）",
    "email": "tanaka@example.com",
    "role": "manager",
    "updated_at": "2024-01-15T10:00:00Z"
  },
  "status": "success"
}
```

#### DELETE /employees/:id
従業員削除

**レスポンス**
```json
{
  "message": "従業員を削除しました",
  "status": "success"
}
```

## エラーレスポンス

### 400 Bad Request
```json
{
  "error": "Bad Request",
  "message": "リクエストパラメータが不正です",
  "details": {
    "field": "email",
    "message": "メールアドレスの形式が正しくありません"
  }
}
```

### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "message": "認証が必要です"
}
```

### 403 Forbidden
```json
{
  "error": "Forbidden",
  "message": "この操作を実行する権限がありません"
}
```

### 404 Not Found
```json
{
  "error": "Not Found",
  "message": "リソースが見つかりません"
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Unprocessable Entity",
  "message": "バリデーションエラー",
  "details": {
    "field": "start_time",
    "message": "開始時間は終了時間より前である必要があります"
  }
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "サーバー内部エラーが発生しました"
}
```

## レスポンス形式

### 成功レスポンス
```json
{
  "status": "success",
  "data": {
    // レスポンスデータ
  },
  "message": "操作が正常に完了しました"
}
```

### エラーレスポンス
```json
{
  "status": "error",
  "error": "Error Type",
  "message": "エラーメッセージ",
  "details": {
    // エラー詳細
  }
}
```

## レート制限

- **制限**: 1000リクエスト/時間
- **ヘッダー**:
  - `X-RateLimit-Limit`: 制限値
  - `X-RateLimit-Remaining`: 残りリクエスト数
  - `X-RateLimit-Reset`: リセット時刻

## バージョニング

- **現在のバージョン**: v1
- **ヘッダー**: `Accept: application/vnd.api+json; version=1`

## Freee API統合

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

### 従業員情報取得

#### エンドポイント
```
GET /employees
```

#### リクエスト例
```ruby
# Freee APIから従業員情報を取得
response = HTTParty.get(
  'https://api.freee.co.jp/hr/api/v1/employees',
  headers: {
    'Authorization' => "Bearer #{access_token}",
    'Content-Type' => 'application/json'
  }
)
```

#### レスポンス例
```json
{
  "employees": [
    {
      "id": 1,
      "num": "EMP001",
      "display_name": "田中太郎",
      "first_name": "太郎",
      "last_name": "田中",
      "email": "tanaka@example.com",
      "employee_number": "001",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 従業員情報同期

#### 同期処理
```ruby
class FreeeEmployeeSyncService
  def self.sync_employees
    employees = fetch_freee_employees

    employees.each do |freee_employee|
      employee = Employee.find_or_initialize_by(freee_id: freee_employee['id'])
      employee.update!(
        name: freee_employee['display_name'],
        email: freee_employee['email'],
        employee_number: freee_employee['employee_number']
      )
    end
  end

  private

  def self.fetch_freee_employees
    # Freee APIから従業員情報を取得
  end
end
```

### エラーハンドリング

#### Freee API エラー
```ruby
class FreeeApiError < StandardError
  attr_reader :status, :message

  def initialize(status, message)
    @status = status
    @message = message
    super("Freee API Error: #{status} - #{message}")
  end
end
```

#### エラー処理
```ruby
begin
  response = HTTParty.get(freee_api_url, headers: headers)

  if response.success?
    return JSON.parse(response.body)
  else
    raise FreeeApiError.new(response.code, response.message)
  end
rescue FreeeApiError => e
  Rails.logger.error "Freee API Error: #{e.message}"
  raise e
rescue => e
  Rails.logger.error "Unexpected error: #{e.message}"
  raise StandardError, "従業員情報の取得に失敗しました"
end
```

## テスト

### API テスト例

#### 認証テスト
```ruby
RSpec.describe "Authentication API" do
  describe "POST /auth/login" do
    it "メールアドレスでログインできる" do
      post "/auth/login", params: { email: "test@example.com" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("success")
    end
  end

  describe "POST /auth/verify" do
    it "認証コードで認証完了できる" do
      # 認証コード送信
      post "/auth/login", params: { email: "test@example.com" }

      # 認証コードで認証
      post "/auth/verify", params: {
        email: "test@example.com",
        code: "123456"
      }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("success")
    end
  end
end
```

#### シフト管理テスト
```ruby
RSpec.describe "Shift Management API" do
  describe "GET /shifts" do
    it "シフト一覧を取得できる" do
      get "/shifts", params: {
        start_date: "2024-01-01",
        end_date: "2024-01-31"
      }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["shifts"]).to be_an(Array)
    end
  end

  describe "POST /shifts" do
    it "シフトを作成できる" do
      post "/shifts", params: {
        employee_id: 1,
        date: "2024-01-15",
        start_time: "09:00",
        end_time: "17:00"
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["status"]).to eq("success")
    end
  end
end
```

## セキュリティ

### CSRF保護
- すべてのPOST/PUT/DELETEリクエストでCSRFトークン必須
- Rails標準のCSRF保護機能を使用

### 認証
- セッションベースの認証
- 認証コードによる二段階認証
- セッションタイムアウト: 30分

### 権限管理
- ロールベースのアクセス制御
- 管理者権限と一般従業員権限
- リソースレベルでの権限チェック

### データ保護
- 個人情報の暗号化
- ログからの機密情報除外
- HTTPS通信の強制
