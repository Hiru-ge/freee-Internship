# 勤怠管理システム (Attendance Management System)

勤怠管理・シフト管理・給与管理を行うRailsアプリケーションです。

## 概要

このシステムは、従業員の勤怠管理、シフト管理、給与状況確認を行うWebアプリケーションです。GAS（Google Apps Script）からRuby on Railsに完全移行しました。

## 主な機能

- **認証システム**: パスワード認証、初回パスワード設定
- **シフト管理**: シフトの確認、交代依頼、追加依頼
- **勤怠管理**: 打刻、勤怠状況確認
- **給与管理**: 103万の壁ゲージ表示、時間帯別時給計算
- **freee API連携**: 従業員情報・給与データの取得・表示
- **メール通知**: シフト交代・追加依頼の通知

## 技術スタック

- **Backend**: Ruby on Rails 8.0.2
- **Database**: PostgreSQL
- **Bot**: LINE Bot API
- **External APIs**: freee API, Google Sheets API
- **Deployment**: Heroku

## セットアップ

### 前提条件

- Ruby 3.3.0以上
- PostgreSQL
- LINE Bot アカウント
- freee API アカウント

### インストール

1. リポジトリのクローン
```bash
git clone <repository-url>
cd freee-Internship
```

2. 依存関係のインストール
```bash
bundle install
```

3. 環境変数の設定
```bash
# .envファイルを作成
touch .env
```

以下の内容を`.env`ファイルに記述してください：
```bash
# freee API設定
FREEE_ACCESS_TOKEN=your_freee_access_token_here
FREEE_COMPANY_ID=your_freee_company_id_here

# Gmail SMTP設定
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here

# アプリケーション設定
RAILS_ENV=development
```

4. データベースの作成とマイグレーション
```bash
rails db:create
rails db:migrate
```

5. サーバーの起動
```bash
rails server
```

## 環境変数

以下の環境変数を`.env`ファイルに設定してください：

### 認証システム用
- `FREEE_ACCESS_TOKEN`: freee API アクセストークン
- `FREEE_COMPANY_ID`: freee API 会社ID
- `GMAIL_USERNAME`: Gmail送信用のメールアドレス
- `GMAIL_APP_PASSWORD`: Gmail送信用のアプリパスワード

### LINE Bot用（将来実装予定）
- `LINE_CHANNEL_SECRET`: LINE Bot チャンネルシークレット
- `LINE_CHANNEL_TOKEN`: LINE Bot チャンネルトークン

### Google Sheets用（将来実装予定）
- `GOOGLE_SHEETS_CREDENTIALS_PATH`: Google Sheets API認証情報のパス
- `GOOGLE_SHEETS_SPREADSHEET_ID`: Google Sheets スプレッドシートID

## デプロイ

Herokuへのデプロイ手順：

1. Heroku CLIのインストール
2. Herokuアプリの作成
3. 環境変数の設定
4. デプロイの実行

```bash
heroku create your-app-name
heroku config:set LINE_CHANNEL_SECRET=your_secret
heroku config:set LINE_CHANNEL_TOKEN=your_token
# その他の環境変数も設定
git push heroku main
```

## 開発状況

- ✅ Rails移行完了
- ✅ 基本的なWebhookエンドポイント実装完了
- 🔄 既存機能の移行準備中

詳細な実装状況は `docs/` ディレクトリ内のドキュメントを参照してください。

## ライセンス

MIT License
