# メールシステム仕様書

## 概要

勤怠管理システムのメール機能は、GAS時代の機能を完全に再現し、シフト管理と認証に関する自動メール送信を提供します。

## アーキテクチャ

### 主要コンポーネント

1. **Mailer Classes**
   - `AuthMailer`: 認証関連メール
   - `ShiftMailer`: シフト関連メール
   - `ClockReminderMailer`: 打刻リマインダーメール

2. **Service Classes**
   - `EmailNotificationService`: メール送信の一元管理
   - `ClockReminderService`: 打刻リマインダー処理
   - `FreeeApiService`: 従業員情報取得

3. **Background Jobs**
   - `ClockReminderJob`: 打刻リマインダーのバックグラウンド処理

## メール送信機能

### 1. 認証関連メール

#### パスワードリセット認証コード
- **送信タイミング**: パスワードリセット申請時
- **送信先**: 申請者のメールアドレス
- **内容**: 6桁の認証コード（10分間有効）

#### 初回パスワード設定認証コード
- **送信タイミング**: 初回ログイン時
- **送信先**: 従業員のメールアドレス
- **内容**: 6桁の認証コード（10分間有効）

### 2. シフト関連メール

#### シフト交代依頼メール
- **送信タイミング**: シフト交代リクエスト作成時
- **送信先**: 承認者のメールアドレス
- **内容**: 申請者名、対象日時、承認URL

#### シフト交代承認メール
- **送信タイミング**: シフト交代リクエスト承認時
- **送信先**: 申請者のメールアドレス
- **内容**: 承認者名、対象日時、シフト表更新通知

#### シフト交代否認メール
- **送信タイミング**: シフト交代リクエスト否認時
- **送信先**: 申請者のメールアドレス
- **内容**: 否認通知

#### シフト追加依頼メール
- **送信タイミング**: シフト追加リクエスト作成時
- **送信先**: 対象従業員のメールアドレス
- **内容**: 対象日時、承認URL

#### シフト追加承認メール
- **送信タイミング**: シフト追加リクエスト承認時
- **送信先**: オーナーのメールアドレス
- **内容**: 承認者名、対象日時、シフト表更新通知

#### シフト追加否認メール
- **送信タイミング**: シフト追加リクエスト否認時
- **送信先**: オーナーのメールアドレス
- **内容**: 否認通知

### 3. 打刻リマインダーメール

#### 出勤打刻リマインダー
- **送信タイミング**: シフト開始時刻から1時間後
- **送信条件**: 出勤打刻が記録されていない
- **送信先**: 従業員のメールアドレス
- **内容**: 出勤打刻忘れの通知

#### 退勤打刻リマインダー
- **送信タイミング**: シフト終了時刻から2時間後、以降15分間隔
- **送信条件**: 退勤打刻が記録されていない
- **送信先**: 従業員のメールアドレス
- **内容**: 退勤打刻忘れの通知

## 技術仕様

### メール送信設定

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'gmail.com',
  user_name: ENV['GMAIL_USERNAME'],
  password: ENV['GMAIL_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

### 従業員情報取得

メールアドレスはfreee APIから動的に取得します：

```ruby
# GAS時代のgetEmployeesを再現
def get_employees_full
  # /hr/api/v1/companies/{company_id}/employees エンドポイントを使用
  # 全従業員情報（メールアドレス含む）を取得
end
```

### エラーハンドリング

- メール送信失敗時はログに記録
- 従業員情報取得失敗時は処理をスキップ
- メールアドレスが存在しない場合は送信をスキップ

## メールテンプレート

### 共通スタイル

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>勤怠管理システム</title>
  <style>
    /* レスポンシブ対応のメールスタイル */
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>タイトル</h1>
      <h2>勤怠管理システム</h2>
    </div>
    <div class="content">
      <!-- メール本文 -->
    </div>
    <div class="footer">
      <!-- フッター情報 -->
    </div>
  </div>
</body>
</html>
```

### 日付フォーマット

```erb
<!-- 日付文字列をDateオブジェクトに変換してフォーマット -->
<%= Date.parse(@shift_date).strftime('%m月%d日') %> <%= @start_time %>～<%= @end_time %>
```

## 運用設定

### バックグラウンドジョブ

打刻リマインダーは定期的に実行される必要があります：

```ruby
# whenever gemを使用したスケジュール設定
every 15.minutes do
  runner "ClockReminderJob.perform_later('clock_out')"
end

every 1.hour do
  runner "ClockReminderJob.perform_later('clock_in')"
end
```

### 環境変数

```bash
# Gmail SMTP設定
GMAIL_USERNAME=your-email@gmail.com
GMAIL_PASSWORD=your-app-password

# freee API設定
FREEE_ACCESS_TOKEN=your-access-token
FREEE_COMPANY_ID=your-company-id
```

## トラブルシューティング

### よくある問題

1. **メールが送信されない**
   - Gmail SMTP設定を確認
   - アプリパスワードが正しく設定されているか確認

2. **従業員情報が取得できない**
   - freee APIトークンの有効性を確認
   - 会社IDが正しく設定されているか確認

3. **メールテンプレートエラー**
   - 日付フォーマットの確認
   - 変数の存在確認

### ログ確認

```bash
# メール送信ログの確認
tail -f log/development.log | grep "メール"

# エラーログの確認
tail -f log/development.log | grep "ERROR"
```

## 今後の拡張予定

1. **103万の壁ゲージアラート**
   - 月次勤務時間が103万を超える場合のアラート

2. **メール配信統計**
   - 送信成功率の監視
   - 配信状況のダッシュボード

3. **メールテンプレートのカスタマイズ**
   - 会社ロゴの追加
   - ブランドカラーの適用
