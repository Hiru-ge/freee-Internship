# API仕様書

## 概要

勤怠管理システムのAPI仕様書です。このシステムはRuby on Rails 8.0.2で構築されており、RESTful APIを提供しています。

## ベースURL

- 開発環境: `http://localhost:3000`
- 本番環境: `https://your-app-name.herokuapp.com`

## 認証

### セッション認証
- ログイン後にセッションCookieで認証状態を維持
- 未認証の場合はログインページにリダイレクト
- **セッションタイムアウト**: 24時間（Phase 6-1で実装）
- **CSRF保護**: 有効（Phase 6-1で強化）

### セキュリティ機能
- **入力値検証**: 全API関数で厳格な入力値検証（Phase 6-2で実装）
- **権限チェック**: 全API関数で権限検証（Phase 6-2で実装）
- **外部キー制約**: データベースレベルでの参照整合性保証（Phase 6-3で実装）

## エンドポイント一覧

### 認証関連

#### POST /auth/login
ログイン処理

**リクエスト**
```json
{
  "employee_id": "string",
  "password": "string"
}
```

**レスポンス**
- 成功時: 302リダイレクト（ダッシュボードへ）
- 失敗時: ログインページにエラーメッセージ表示

#### POST /auth/logout
ログアウト処理

**レスポンス**
- 302リダイレクト（ログインページへ）

#### GET /auth/initial_password
初回パスワード設定画面

#### POST /auth/initial_password
初回パスワード設定処理

**リクエスト**
```json
{
  "employee_id": "string",
  "password": "string",
  "password_confirmation": "string"
}
```

#### GET /auth/password_change
パスワード変更画面

#### POST /auth/password_change
パスワード変更処理

**リクエスト**
```json
{
  "current_password": "string",
  "password": "string",
  "password_confirmation": "string"
}
```

### シフト管理

#### GET /shifts
シフト一覧表示

**レスポンス**
- HTML: 月間シフト表
- パラメータ: `month` (YYYY-MM形式)

#### GET /shift_exchanges/new
シフト交代依頼画面

#### POST /shift_exchanges
シフト交代依頼作成

**リクエスト**
```json
{
  "shift_exchange": {
    "shift_id": "integer",
    "requester_id": "string",
    "requested_to_id": "string",
    "reason": "string"
  }
}
```

#### GET /shift_additions/new
シフト追加依頼画面

#### POST /shift_additions
シフト追加依頼作成

**リクエスト**
```json
{
  "shift_addition": {
    "shift_date": "date",
    "start_time": "time",
    "end_time": "time",
    "requester_id": "string",
    "reason": "string"
  }
}
```

### シフト承認

#### GET /shift_approvals
シフト承認一覧

**レスポンス**
- HTML: 承認待ちのシフト依頼一覧

#### POST /shift_approvals/approve
シフト承認処理

**リクエスト**
```json
{
  "request_id": "string",
  "request_type": "string", // "exchange" or "addition"
  "employee_id": "string"
}
```

#### POST /shift_approvals/reject
シフト否認処理

**リクエスト**
```json
{
  "request_id": "string",
  "request_type": "string", // "exchange" or "addition"
  "employee_id": "string"
}
```

### 勤怠管理

#### GET /attendances
勤怠一覧表示

**レスポンス**
- HTML: 月間勤怠記録

#### POST /attendances/clock_in
出勤打刻

#### POST /attendances/clock_out
退勤打刻

#### POST /attendances/break_start
休憩開始打刻

#### POST /attendances/break_end
休憩終了打刻

### 給与管理

#### GET /wages
給与情報表示

**レスポンス**
- HTML: 103万の壁ゲージと給与情報

### 従業員管理

#### GET /employees
従業員一覧（管理者のみ）

**レスポンス**
- HTML: 従業員一覧表

## 外部API連携

### freee API

#### 従業員情報取得
```ruby
FreeeApiService.get_employee_info(employee_id)
```

#### 全従業員情報取得
```ruby
FreeeApiService.get_all_employees
```

#### 給与情報取得
```ruby
FreeeApiService.get_employee_salary(employee_id, year, month)
```

## エラーハンドリング

### HTTPステータスコード

- `200 OK`: 正常処理
- `302 Found`: リダイレクト
- `400 Bad Request`: リクエストエラー
- `401 Unauthorized`: 認証エラー
- `403 Forbidden`: 権限エラー
- `404 Not Found`: リソースが見つからない
- `422 Unprocessable Entity`: バリデーションエラー
- `500 Internal Server Error`: サーバーエラー

### エラーレスポンス形式

```json
{
  "error": "エラーメッセージ",
  "details": "詳細情報（オプション）"
}
```

## セキュリティ

### CSRF保護
- すべてのPOST/PUT/DELETEリクエストでCSRFトークンが必要
- `X-CSRF-Token`ヘッダーまたはフォームパラメータで送信

### パスワードセキュリティ
- bcryptによるハッシュ化
- 最小8文字、英数字混合推奨

### セッション管理
- セッションタイムアウト: 24時間
- ログアウト時のセッション破棄

## レート制限

現在、レート制限は実装されていません。本番環境では適切なレート制限の実装を推奨します。

## バージョニング

現在のAPIバージョン: v1

URLパスにバージョンを含める予定はありませんが、将来の拡張性を考慮して設計されています。
