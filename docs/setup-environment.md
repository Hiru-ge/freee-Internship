# 環境変数設定ドキュメント

## 概要

勤怠管理システムの環境変数設定について説明します。機密情報はすべて環境変数で管理し、セキュリティを確保しています。

## 必要な環境変数

### 認証システム用

#### freee API設定
```bash
FREEE_ACCESS_TOKEN=your_freee_access_token_here
FREEE_COMPANY_ID=your_freee_company_id_here
```

**取得方法:**
1. freee API管理画面にログイン
2. アクセストークンを生成
3. 会社IDを確認

#### Gmail SMTP設定
```bash
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here
```

**取得方法:**
1. Googleアカウントの2段階認証を有効化
2. アプリパスワードを生成
3. 16文字のアプリパスワードを取得

### アプリケーション設定
```bash
RAILS_ENV=development
```

## 環境別設定

### 開発環境 (.env)
```bash
# freee API設定
FREEE_ACCESS_TOKEN=szv1X73Daf_xy9eM8zAw5ZNhg9O4egOQ5GuD_jH5rz8
FREEE_COMPANY_ID=12127317

# Gmail SMTP設定
GMAIL_USERNAME=okita2710@gmail.com
GMAIL_APP_PASSWORD=gbpbelkzcnrvjhao

# アプリケーション設定
RAILS_ENV=development
```

### 本番環境
```bash
# Herokuの場合
heroku config:set FREEE_ACCESS_TOKEN=your_production_token
heroku config:set FREEE_COMPANY_ID=your_production_company_id
heroku config:set GMAIL_USERNAME=your_production_email
heroku config:set GMAIL_APP_PASSWORD=your_production_app_password
heroku config:set RAILS_ENV=production
```

## 設定ファイル

### config/freee_api.yml
```yaml
development:
  access_token: <%= ENV['FREEE_ACCESS_TOKEN'] %>
  company_id: <%= ENV['FREEE_COMPANY_ID'] %>

test:
  access_token: <%= ENV['FREEE_ACCESS_TOKEN'] %>
  company_id: <%= ENV['FREEE_COMPANY_ID'] %>

production:
  access_token: <%= ENV['FREEE_ACCESS_TOKEN'] %>
  company_id: <%= ENV['FREEE_COMPANY_ID'] %>
```

### config/environments/development.rb
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'gmail.com',
  user_name: ENV['GMAIL_USERNAME'],
  password: ENV['GMAIL_APP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

## セットアップ手順

### 1. .envファイルの作成
```bash
# プロジェクトルートで実行
touch .env
```

### 2. 環境変数の設定
```bash
# .envファイルに以下を記述
cat > .env << EOF
# freee API設定
FREEE_ACCESS_TOKEN=your_freee_access_token_here
FREEE_COMPANY_ID=your_freee_company_id_here

# Gmail SMTP設定
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here

# アプリケーション設定
RAILS_ENV=development
EOF
```

### 3. 動作確認
```bash
# 環境変数が正しく読み込まれているか確認
rails runner "puts ENV['FREEE_ACCESS_TOKEN'] ? 'OK' : 'NG'"
rails runner "puts ENV['GMAIL_USERNAME'] ? 'OK' : 'NG'"
```

## セキュリティ

### .gitignore設定
```gitignore
# Environment variables
.env
.env.local
.env.*.local
```

### 機密情報の管理
- `.env`ファイルはGit管理外
- 機密情報は設定ファイルにハードコードしない
- 本番環境では環境変数を直接設定

### アクセストークンの管理
- freee APIアクセストークンは定期的に更新
- アプリパスワードは必要最小限の権限で設定
- 不要になったトークンは即座に無効化

## トラブルシューティング

### 環境変数が読み込まれない
```bash
# .envファイルの存在確認
ls -la .env

# ファイルの内容確認
cat .env

# Rails環境での確認
rails runner "puts ENV.keys.grep(/FREEE|GMAIL/)"
```

### freee API接続エラー
```bash
# アクセストークンの確認
rails runner "puts ENV['FREEE_ACCESS_TOKEN'] ? '設定済み' : '未設定'"

# API接続テスト
rails runner "svc = FreeeApiService.new(ENV['FREEE_ACCESS_TOKEN'], ENV['FREEE_COMPANY_ID']); puts svc.get_all_employees.size"
```

### メール送信エラー
```bash
# Gmail設定の確認
rails runner "puts ENV['GMAIL_USERNAME'] ? '設定済み' : '未設定'"

# メール送信テスト
rails runner "AuthMailer.password_reset_code('test@example.com', 'テスト', '123456').deliver_now"
```

## 今後の拡張

### LINE Bot用環境変数（将来実装予定）
```bash
LINE_CHANNEL_SECRET=your_line_channel_secret
LINE_CHANNEL_TOKEN=your_line_channel_token
```

### Google Sheets用環境変数（将来実装予定）
```bash
GOOGLE_SHEETS_CREDENTIALS_PATH=path/to/credentials.json
GOOGLE_SHEETS_SPREADSHEET_ID=your_spreadsheet_id
```

## 関連ドキュメント

- [認証システム実装ドキュメント](./authentication-system.md)
- [README.md](../README.md)
- [データベース設計ドキュメント](./database-schema-design.md)
