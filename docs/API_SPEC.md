# API仕様書

勤怠管理システムのRESTful API仕様です。

## 🎯 概要

勤怠管理システムが提供するRESTful APIの詳細仕様です。

## 🔗 基本情報

### ベースURL
```
Production: https://your-app.fly.dev
Development: http://localhost:3000
```

### 認証方式
- **メール認証**: メールアドレス + 認証コード
- **セッション管理**: Rails セッション
- **CSRF保護**: CSRFトークン必須

### レスポンス形式
```json
{
  "success": true,
  "data": { ... },
  "message": "Success",
  "errors": []
}
```

## 🔐 認証API

### 1. メール認証コード送信
```http
POST /auth/verify_email
Content-Type: application/json

{
  "email": "user@example.com"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "認証コードを送信しました"
}
```

**エラーレスポンス**:
```json
{
  "success": false,
  "message": "メールアドレスが正しくありません",
  "errors": ["email"]
}
```

### 2. 認証コード検証
```http
POST /auth/verify_code
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "認証が完了しました",
  "data": {
    "employee_id": "EMP001",
    "name": "田中太郎",
    "role": "employee"
  }
}
```

### 3. ログアウト
```http
POST /auth/logout
```

**レスポンス**:
```json
{
  "success": true,
  "message": "ログアウトしました"
}
```

## 📊 ダッシュボードAPI

### 1. ダッシュボード情報取得
```http
GET /dashboard
```

**レスポンス**:
```json
{
  "success": true,
  "data": {
    "employee": {
      "employee_id": "EMP001",
      "name": "田中太郎",
      "role": "employee"
    },
    "clock_status": {
      "can_clock_in": true,
      "can_clock_out": false,
      "message": "出勤打刻が可能です"
    }
  }
}
```

### 2. 出勤打刻
```http
POST /dashboard/clock_in
```

**レスポンス**:
```json
{
  "success": true,
  "message": "出勤打刻が完了しました"
}
```

### 3. 退勤打刻
```http
POST /dashboard/clock_out
```

**レスポンス**:
```json
{
  "success": true,
  "message": "退勤打刻が完了しました"
}
```

### 4. 打刻状態取得
```http
GET /dashboard/clock_status
```

**レスポンス**:
```json
{
  "success": true,
  "data": {
    "can_clock_in": false,
    "can_clock_out": true,
    "message": "退勤打刻が可能です"
  }
}
```

### 5. 勤怠履歴取得
```http
GET /dashboard/attendance_history?year=2024&month=12
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "date": "2024-12-01",
      "clock_in": "09:00",
      "clock_out": "17:00",
      "work_hours": 8.0
    }
  ]
}
```

## 📅 シフト管理API

### 1. シフト一覧取得
```http
GET /shifts?year=2024&month=12
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "employee_id": "EMP001",
      "shift_date": "2024-12-01",
      "start_time": "09:00",
      "end_time": "17:00",
      "employee_name": "田中太郎"
    }
  ]
}
```

### 2. シフト詳細取得
```http
GET /shifts/1
```

**レスポンス**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "employee_id": "EMP001",
    "shift_date": "2024-12-01",
    "start_time": "09:00",
    "end_time": "17:00",
    "employee": {
      "employee_id": "EMP001",
      "name": "田中太郎",
      "role": "employee"
    }
  }
}
```

### 3. シフト作成
```http
POST /shifts
Content-Type: application/json

{
  "employee_id": "EMP001",
  "shift_date": "2024-12-25",
  "start_time": "09:00",
  "end_time": "17:00"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフトを作成しました",
  "data": {
    "id": 2,
    "employee_id": "EMP001",
    "shift_date": "2024-12-25",
    "start_time": "09:00",
    "end_time": "17:00"
  }
}
```

### 4. シフト更新
```http
PUT /shifts/1
Content-Type: application/json

{
  "start_time": "10:00",
  "end_time": "18:00"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフトを更新しました",
  "data": {
    "id": 1,
    "employee_id": "EMP001",
    "shift_date": "2024-12-01",
    "start_time": "10:00",
    "end_time": "18:00"
  }
}
```

### 5. シフト削除
```http
DELETE /shifts/1
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフトを削除しました"
}
```

## 🔄 シフト交代API

### 1. シフト交代依頼一覧取得
```http
GET /shift_exchanges
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "request_id": "REQ001",
      "requester_id": "EMP001",
      "approver_id": "EMP002",
      "shift_id": 1,
      "status": "pending",
      "created_at": "2024-12-01T09:00:00Z",
      "requester_name": "田中太郎",
      "approver_name": "山田花子",
      "shift": {
        "id": 1,
        "shift_date": "2024-12-25",
        "start_time": "09:00",
        "end_time": "17:00"
      }
    }
  ]
}
```

### 2. シフト交代依頼作成
```http
POST /shift_exchanges
Content-Type: application/json

{
  "shift_id": 1,
  "approver_id": "EMP002"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフト交代依頼を送信しました",
  "data": {
    "id": 1,
    "request_id": "REQ001",
    "status": "pending"
  }
}
```

### 3. シフト交代依頼承認
```http
POST /shift_exchanges/1/approve
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフト交代依頼を承認しました"
}
```

### 4. シフト交代依頼拒否
```http
POST /shift_exchanges/1/reject
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフト交代依頼を拒否しました"
}
```

## ➕ シフト追加API

### 1. シフト追加依頼一覧取得
```http
GET /shift_additions
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "request_id": "ADD001",
      "requester_id": "EMP001",
      "approver_id": "EMP002",
      "shift_date": "2024-12-25",
      "start_time": "09:00",
      "end_time": "17:00",
      "target_employee_ids": ["EMP003", "EMP004"],
      "status": "pending",
      "created_at": "2024-12-01T09:00:00Z"
    }
  ]
}
```

### 2. シフト追加依頼作成
```http
POST /shift_additions
Content-Type: application/json

{
  "shift_date": "2024-12-25",
  "start_time": "09:00",
  "end_time": "17:00",
  "target_employee_ids": ["EMP003", "EMP004"]
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフト追加依頼を送信しました",
  "data": {
    "id": 1,
    "request_id": "ADD001",
    "status": "pending"
  }
}
```

### 3. シフト追加依頼承認
```http
POST /shift_additions/1/approve
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフト追加依頼を承認しました"
}
```

### 4. シフト追加依頼拒否
```http
POST /shift_additions/1/reject
```

**レスポンス**:
```json
{
  "success": true,
  "message": "シフト追加依頼を拒否しました"
}
```

## 🚫 欠勤申請API

### 1. 欠勤申請一覧取得
```http
GET /shift_deletions
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "request_id": "DEL001",
      "requester_id": "EMP001",
      "approver_id": "EMP002",
      "shift_id": 1,
      "reason": "体調不良のため",
      "status": "pending",
      "created_at": "2024-12-01T09:00:00Z",
      "shift": {
        "id": 1,
        "shift_date": "2024-12-25",
        "start_time": "09:00",
        "end_time": "17:00"
      }
    }
  ]
}
```

### 2. 欠勤申請作成
```http
POST /shift_deletions
Content-Type: application/json

{
  "shift_id": 1,
  "reason": "体調不良のため"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "欠勤申請を送信しました",
  "data": {
    "id": 1,
    "request_id": "DEL001",
    "status": "pending"
  }
}
```

### 3. 欠勤申請承認
```http
POST /shift_deletions/1/approve
```

**レスポンス**:
```json
{
  "success": true,
  "message": "欠勤申請を承認しました"
}
```

### 4. 欠勤申請拒否
```http
POST /shift_deletions/1/reject
```

**レスポンス**:
```json
{
  "success": true,
  "message": "欠勤申請を拒否しました"
}
```

## 💰 給与管理API

### 1. 給与情報取得
```http
GET /wages?year=2024&month=12
```

**レスポンス**:
```json
{
  "success": true,
  "data": {
    "employee_id": "EMP001",
    "employee_name": "田中太郎",
    "wage": 120000,
    "breakdown": {
      "normal": {
        "hours": 120,
        "rate": 1000,
        "wage": 120000,
        "name": "通常時給"
      },
      "evening": {
        "hours": 0,
        "rate": 1200,
        "wage": 0,
        "name": "夜間手当"
      },
      "night": {
        "hours": 0,
        "rate": 1500,
        "wage": 0,
        "name": "深夜手当"
      }
    },
    "work_hours": {
      "normal": 120,
      "evening": 0,
      "night": 0
    },
    "target": 103000,
    "percentage": 116.5,
    "is_over_limit": true,
    "remaining": 0
  }
}
```

### 2. 全従業員給与情報取得
```http
GET /wages/all?year=2024&month=12
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "employee_id": "EMP001",
      "employee_name": "田中太郎",
      "wage": 120000,
      "percentage": 116.5
    },
    {
      "employee_id": "EMP002",
      "employee_name": "山田花子",
      "wage": 95000,
      "percentage": 92.2
    }
  ]
}
```

## 🔧 アクセス制御API

### 1. アクセス制御画面
```http
GET /access_control
```

**レスポンス**:
```json
{
  "success": true,
  "data": {
    "message": "メールアドレスを入力してください"
  }
}
```

### 2. メールアドレス認証
```http
POST /access_control/verify_email
Content-Type: application/json

{
  "email": "user@example.com"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "認証コードを送信しました"
}
```

### 3. 認証コード検証
```http
POST /access_control/verify_code
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "認証が完了しました",
  "data": {
    "employee_id": "EMP001",
    "name": "田中太郎",
    "role": "employee"
  }
}
```

## 🕐 打刻忘れアラートAPI

### 1. 打刻忘れアラート一覧取得
```http
GET /clock_reminder
```

**レスポンス**:
```json
{
  "success": true,
  "data": [
    {
      "employee_id": "EMP001",
      "employee_name": "田中太郎",
      "type": "clock_out",
      "message": "退勤打刻を忘れています",
      "created_at": "2024-12-01T18:30:00Z"
    }
  ]
}
```

### 2. 打刻忘れアラート送信
```http
POST /clock_reminder/send
Content-Type: application/json

{
  "employee_id": "EMP001",
  "type": "clock_out"
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "打刻忘れアラートを送信しました"
}
```

## 📱 LINE Bot Webhook API

### 1. LINE Bot Webhook
```http
POST /webhook
Content-Type: application/json
X-Line-Signature: <signature>

{
  "events": [
    {
      "type": "message",
      "source": {
        "type": "user",
        "userId": "U1234567890"
      },
      "message": {
        "type": "text",
        "text": "ヘルプ"
      }
    }
  ]
}
```

**レスポンス**:
```json
{
  "success": true,
  "message": "Webhook processed"
}
```

## 🚨 エラーレスポンス

### 共通エラーレスポンス
```json
{
  "success": false,
  "message": "エラーが発生しました",
  "errors": [
    {
      "field": "email",
      "message": "メールアドレスが正しくありません"
    }
  ]
}
```

### HTTPステータスコード
- **200**: 成功
- **201**: 作成成功
- **400**: リクエストエラー
- **401**: 認証エラー
- **403**: 権限エラー
- **404**: リソースが見つからない
- **422**: バリデーションエラー
- **500**: サーバーエラー

## 🔒 セキュリティ

### CSRF保護
```http
POST /shifts
Content-Type: application/json
X-CSRF-Token: <csrf_token>

{
  "employee_id": "EMP001",
  "shift_date": "2024-12-25",
  "start_time": "09:00",
  "end_time": "17:00"
}
```

### 認証ヘッダー
```http
GET /dashboard
Cookie: _session_id=<session_id>
```

## 📊 レート制限

### 制限事項
- **認証API**: 10リクエスト/分
- **一般API**: 100リクエスト/分
- **Webhook**: 1000リクエスト/分

### レート制限ヘッダー
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## 🧪 テスト

### テスト用エンドポイント
```http
GET /test/health
```

**レスポンス**:
```json
{
  "success": true,
  "message": "API is healthy",
  "timestamp": "2024-12-01T09:00:00Z"
}
```

## 🚀 今後の拡張予定

### 機能拡張
- **GraphQL API**: GraphQLエンドポイントの追加
- **WebSocket**: リアルタイム通信
- **バッチAPI**: 一括処理API
- **レポートAPI**: レポート生成API

### 技術的改善
- **APIバージョニング**: バージョン管理
- **OpenAPI**: Swagger仕様書
- **認証強化**: JWT認証
- **監視**: API監視の実装

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
