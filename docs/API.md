# API仕様書

## 概要
勤怠管理システムのAPIエンドポイント仕様について説明します。

## 認証

### ログイン
```http
POST /login
Content-Type: application/x-www-form-urlencoded

employee_id=3313254&password=password123
```

**レスポンス**
- 成功: 302 Redirect to `/dashboard`
- 失敗: 200 OK with error message

### ログアウト
```http
POST /logout
```

**レスポンス**
- 302 Redirect to `/login`

## シフト管理

### シフト表示
```http
GET /shifts
Accept: application/json
```

**レスポンス**
```json
{
  "shifts": [
    {
      "id": 1,
      "employee_id": "3313254",
      "shift_date": "2024-12-19",
      "start_time": "09:00",
      "end_time": "17:00"
    }
  ]
}
```

### シフト承認一覧
```http
GET /shift/approvals
```

**レスポンス**
- HTML: シフト承認一覧ページ
- 認証が必要

### シフト承認
```http
POST /shift/approve
Content-Type: application/x-www-form-urlencoded

request_id=123&request_type=exchange
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

### シフト却下
```http
POST /shift/reject
Content-Type: application/x-www-form-urlencoded

request_id=123&request_type=exchange
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

## シフト依頼

### シフト交代依頼フォーム
```http
GET /shift/exchange/new
```

**レスポンス**
- HTML: シフト交代依頼フォーム

### シフト交代依頼作成
```http
POST /shift/exchange
Content-Type: application/x-www-form-urlencoded

shift_id=123&target_employee_id=3316120&reason=体調不良
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

### シフト追加依頼フォーム
```http
GET /shift/addition/new
```

**レスポンス**
- HTML: シフト追加依頼フォーム

### シフト追加依頼作成
```http
POST /shift/addition
Content-Type: application/x-www-form-urlencoded

employee_id=3313254&shift_date=2024-12-20&start_time=09:00&end_time=17:00
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

### シフト削除依頼フォーム
```http
GET /shift/deletion/new
```

**レスポンス**
- HTML: シフト削除依頼フォーム

### シフト削除依頼作成
```http
POST /shift/deletion
Content-Type: application/x-www-form-urlencoded

shift_id=123&reason=体調不良
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

## 勤怠管理

### 出勤
```http
POST /attendance/clock_in
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

### 退勤
```http
POST /attendance/clock_out
```

**レスポンス**
- 成功: 302 Redirect
- 失敗: 400 Bad Request

### 勤怠状況
```http
GET /attendance/status
Accept: application/json
```

**レスポンス**
```json
{
  "status": "working",
  "clock_in_time": "2024-12-19T09:00:00Z",
  "current_time": "2024-12-19T15:30:00Z"
}
```

### 勤怠履歴
```http
GET /attendance/history
Accept: application/json
```

**レスポンス**
```json
{
  "attendance_records": [
    {
      "date": "2024-12-19",
      "clock_in": "09:00",
      "clock_out": "17:00",
      "work_hours": 8.0
    }
  ]
}
```

## 給与管理

### 給与一覧
```http
GET /wages
Accept: application/json
```

**レスポンス**
```json
{
  "employee_wages": [
    {
      "employee_id": "3313254",
      "employee_name": "店長太郎",
      "wage": 150000,
      "target": 1030000,
      "percentage": 14.6
    }
  ]
}
```

### 個人給与情報
```http
GET /wages?employee_id=3313254
Accept: application/json
```

**レスポンス**
```json
{
  "employee_id": "3313254",
  "employee_name": "店長太郎",
  "wage": 150000,
  "target": 1030000,
  "percentage": 14.6
}
```

### 従業員一覧（オーナーのみ）
```http
GET /wages/employees
Accept: application/json
```

**レスポンス**
```json
{
  "employees": [
    {
      "id": "3313254",
      "display_name": "店長太郎",
      "email": "owner@example.com"
    }
  ]
}
```

## エラーレスポンス

### 認証エラー
```json
{
  "error": "認証が必要です"
}
```

### 権限エラー
```json
{
  "error": "権限がありません"
}
```

### バリデーションエラー
```json
{
  "error": "入力値が不正です",
  "details": {
    "employee_id": ["必須項目です"],
    "password": ["8文字以上で入力してください"]
  }
}
```

### システムエラー
```json
{
  "error": "システムエラーが発生しました。しばらく時間をおいてから再度お試しください。"
}
```

## HTTPステータスコード

- `200 OK`: 成功
- `302 Found`: リダイレクト
- `400 Bad Request`: リクエストエラー
- `401 Unauthorized`: 認証エラー
- `403 Forbidden`: 権限エラー
- `404 Not Found`: リソースが見つからない
- `500 Internal Server Error`: サーバーエラー

## 認証・認可

### セッション認証
- ログイン成功時にセッションに `employee_id` を保存
- 各リクエストでセッションの有効性を確認
- セッションタイムアウト: 24時間

### 権限レベル
- **オーナー**: 全機能にアクセス可能
- **従業員**: 自分のデータのみアクセス可能

### CSRF保護
- すべてのPOSTリクエストでCSRFトークンが必要
- `X-CSRF-Token` ヘッダーまたはフォームパラメータで送信

## レート制限
- ログイン試行: 5回/分
- API呼び出し: 100回/分
- 超過時は429 Too Many Requestsを返す

## バージョニング
- 現在のAPIバージョン: v1
- 将来の変更時は新しいエンドポイントを作成
- 既存エンドポイントの破壊的変更は避ける
