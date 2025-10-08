# API仕様書

## 概要
勤怠管理システムのAPIエンドポイント仕様について説明します。
本システムはWebアプリケーションとLINE Botの両方に対応した統合APIを提供します。

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

### 認証コード送信
```http
POST /auth/send_verification_code
Content-Type: application/x-www-form-urlencoded

employee_id=3313254
```

**レスポンス**
```json
{
  "success": true,
  "message": "認証コードを送信しました。メールの送信には数分かかる場合があります。"
}
```

### 認証コード検証
```http
POST /auth/verify_code
Content-Type: application/x-www-form-urlencoded

employee_id=3313254&code=123456
```

**レスポンス**
```json
{
  "success": true,
  "message": "認証コードが確認されました"
}
```

### 初期パスワード設定
```http
POST /auth/setup_initial_password
Content-Type: application/x-www-form-urlencoded

employee_id=3313254&password=newpassword&password_confirmation=newpassword
```

**レスポンス**
- 成功: 302 Redirect to `/login`
- 失敗: 200 OK with error message

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

### 勤怠管理ページ
```http
GET /attendance
```

**レスポンス**
- HTML: 勤怠管理ページ
- 認証が必要

### 出勤打刻
```http
POST /attendance/clock_in
```

**レスポンス**
```json
{
  "success": true,
  "message": "出勤打刻が完了しました"
}
```

### 退勤打刻
```http
POST /attendance/clock_out
```

**レスポンス**
```json
{
  "success": true,
  "message": "退勤打刻が完了しました"
}
```

### 打刻状況取得
```http
GET /attendance/clock_status
Accept: application/json
```

**レスポンス**
```json
{
  "can_clock_in": true,
  "can_clock_out": false,
  "message": "出勤打刻が可能です"
}
```

### 勤怠履歴取得
```http
GET /attendance/attendance_history?year=2024&month=12
Accept: application/json
```

**レスポンス**
```json
[
  {
    "type": "出勤",
    "date": "2024-12-19 09:00"
  },
  {
    "type": "退勤",
    "date": "2024-12-19 17:00"
  }
]
```

## 給与管理

### 給与管理ページ
```http
GET /wages
```

**レスポンス**
- HTML: 給与管理ページ
- 認証が必要

### 給与データ取得
```http
GET /wages/data?start_date=2024-12-01&end_date=2024-12-31
Accept: application/json
```

**レスポンス**
```json
{
  "employee_id": "3313254",
  "employee_name": "店長太郎",
  "total": 150000,
  "breakdown": {
    "normal": {
      "hours": 120,
      "rate": 1000,
      "wage": 120000,
      "name": "通常時給"
    },
    "evening": {
      "hours": 20,
      "rate": 1200,
      "wage": 24000,
      "name": "夜間手当"
    },
    "night": {
      "hours": 5,
      "rate": 1500,
      "wage": 7500,
      "name": "深夜手当"
    }
  },
  "work_hours": {
    "normal": 120,
    "evening": 20,
    "night": 5
  },
  "shifts_count": 15
}
```

## LINE Bot API

### Webhook
```http
POST /webhook/callback
Content-Type: application/json
X-Line-Signature: [署名]

{
  "events": [
    {
      "type": "message",
      "replyToken": "replyToken",
      "source": {
        "userId": "userId"
      },
      "message": {
        "type": "text",
        "text": "シフト確認"
      }
    }
  ]
}
```

**レスポンス**
- 200 OK: 処理完了
- 400 Bad Request: 署名検証失敗

### 打刻リマインダー
```http
POST /clock_reminder/trigger
X-API-Key: [APIキー]
```

**レスポンス**
```json
{
  "success": true,
  "message": "打刻リマインダーを送信しました"
}
```

## エラーレスポンス

### 認証エラー
```json
{
  "success": false,
  "message": "認証が必要です"
}
```

### 権限エラー
```json
{
  "success": false,
  "message": "権限がありません"
}
```

### バリデーションエラー
```json
{
  "success": false,
  "message": "入力値が不正です",
  "details": {
    "employee_id": ["必須項目です"],
    "password": ["8文字以上で入力してください"]
  }
}
```

### システムエラー
```json
{
  "success": false,
  "message": "システムエラーが発生しました。しばらく時間をおいてから再度お試しください。"
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

### メール認証
- アクセス制限用のメールアドレス認証
- 認証コードによる一時的なアクセス許可

### LINE Bot認証
- 従業員アカウントとLINEアカウントの紐付け
- 認証コードによる認証プロセス

### 権限レベル
- **オーナー**: 全機能にアクセス可能
- **従業員**: 自分のデータのみアクセス可能

### CSRF保護
- すべてのPOSTリクエストでCSRFトークンが必要
- `X-CSRF-Token` ヘッダーまたはフォームパラメータで送信

## レート制限
- ログイン試行: 5回/分
- API呼び出し: 100回/分
- Freee API呼び出し: 1秒間隔
- 超過時は429 Too Many Requestsを返す

## バージョニング
- 現在のAPIバージョン: v1
- 将来の変更時は新しいエンドポイントを作成
- 既存エンドポイントの破壊的変更は避ける
