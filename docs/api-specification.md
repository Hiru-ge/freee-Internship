# API仕様書

## 概要

勤怠管理システムのAPI仕様書です。このシステムはRuby on Rails 8.0.2で構築されており、RESTful APIを提供しています。

## ベースURL

- 開発環境: `http://localhost:3000`
- 本番環境: `https://your-app-name.fly.dev`

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

**レスポンス**
- 成功時: 302リダイレクト（承認一覧ページへ）
- 失敗時: エラーメッセージと共にリダイレクト

**処理内容（Phase 9-2.5で修正）**
1. 権限チェック（承認者の確認）
2. シフト交代リクエストの場合：
   - 他の承認者へのリクエストを先に拒否
   - 関連するShiftExchangeのshift_idをnilに設定
   - 元のシフトを削除
   - 新しいシフトを作成（承認者に割り当て）
   - リクエストを承認状態に更新
   - メール通知を送信

**エラーハンドリング**
- シフトが削除済みの場合: "シフトが削除されているため、承認できません"
- 権限なしの場合: "このリクエストを承認する権限がありません"
- リクエスト未発見: "リクエストが見つかりません"

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

**レスポンス**
- 成功時: 302リダイレクト（承認一覧ページへ）
- 失敗時: エラーメッセージと共にリダイレクト

**処理内容（Phase 9-2.5で修正）**
1. 権限チェック（否認者の確認）
2. リクエストを否認状態に更新
3. メール通知を送信

**エラーハンドリング**
- 権限なしの場合: "このリクエストを否認する権限がありません"
- リクエスト未発見: "リクエストが見つかりません"

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

## LINE Bot連携API

### Webhook関連

#### POST /webhooks/line
LINE BotのWebhookエンドポイント

**リクエスト**
```json
{
  "events": [
    {
      "type": "message",
      "replyToken": "string",
      "source": {
        "type": "user|group",
        "userId": "string",
        "groupId": "string"
      },
      "message": {
        "type": "text",
        "text": "string"
      }
    }
  ]
}
```

**レスポンス**
- 成功時: 200 OK
- 失敗時: 400 Bad Request

**認証**
- LINE Botの署名検証を使用
- `X-Line-Signature`ヘッダーで検証

### シフト交代関連

#### シフト交代依頼フロー
1. **シフトカード表示**: `シフト交代`コマンドでFlex Message形式のシフトカードを表示
2. **シフト選択**: Postbackイベントでシフト選択
3. **従業員選択**: 交代先の従業員を選択
4. **リクエスト作成**: ShiftExchangeレコードを作成

#### シフト交代承認フロー
1. **承認待ちリクエスト表示**: `リクエスト確認`コマンドでFlex Message形式の承認待ちリクエストを表示
2. **承認・拒否**: Postbackイベントで承認・拒否処理
3. **シフト更新**: 承認時にシフトを更新
4. **通知送信**: 申請者にプッシュメッセージで通知

#### シフト交代状況確認
- **コマンド**: `交代状況`
- **機能**: 自分のシフト交代リクエストの状況を表示
- **表示内容**: 承認待ち、承認済み、拒否済みの分類表示

### Flex Message仕様

#### シフトカード形式
```json
{
  "type": "flex",
  "altText": "シフト交代依頼 - 交代したいシフトを選択してください",
  "contents": {
    "type": "carousel",
    "contents": [
      {
        "type": "bubble",
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": "シフト交代依頼",
              "weight": "bold",
              "size": "xl",
              "color": "#1DB446"
            },
            {
              "type": "separator",
              "margin": "md"
            },
            {
              "type": "box",
              "layout": "vertical",
              "margin": "md",
              "spacing": "sm",
              "contents": [
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "📅",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "12/25 (水)",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "⏰",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "09:00-18:00",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                }
              ]
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "style": "primary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "交代を依頼",
                "data": "shift_123",
                "displayText": "12/25のシフト交代を依頼します"
              }
            }
          ]
        }
      }
    ]
  }
}
```

#### 承認待ちリクエスト形式
```json
{
  "type": "flex",
  "altText": "承認待ちのシフト交代リクエスト",
  "contents": {
    "type": "carousel",
    "contents": [
      {
        "type": "bubble",
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": "シフト交代承認",
              "weight": "bold",
              "size": "xl",
              "color": "#1DB446"
            },
            {
              "type": "separator",
              "margin": "md"
            },
            {
              "type": "box",
              "layout": "vertical",
              "margin": "md",
              "spacing": "sm",
              "contents": [
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "👤",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "申請者: 田中太郎",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "📅",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "12/25 (水)",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "⏰",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "09:00-18:00",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                }
              ]
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "style": "primary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "承認",
                "data": "approve_123",
                "displayText": "12/25のシフト交代を承認します"
              }
            },
            {
              "type": "button",
              "style": "secondary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "拒否",
                "data": "reject_123",
                "displayText": "12/25のシフト交代を拒否します"
              }
            }
          ]
        }
      }
    ]
  }
}
```

## バージョニング

現在のAPIバージョン: v1

URLパスにバージョンを含める予定はありませんが、将来の拡張性を考慮して設計されています。
