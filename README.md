# 勤怠管理システム (Attendance Management System)

LINE Bot経由で勤怠管理を行えるRailsアプリケーションです。

## 概要

このシステムは、LINE Botを介して従業員の勤怠管理、シフト管理、給与状況確認を行うWebアプリケーションです。

## 主な機能

- **LINE認証**: LINEユーザーと従業員IDの紐付け
- **シフト管理**: シフトの確認、交代依頼
- **勤怠管理**: 打刻、勤怠状況確認
- **給与管理**: 103万の壁ゲージ表示
- **freee API連携**: 給与データの取得・表示

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
cp config/env.example .env
# .envファイルを編集して必要な値を設定
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

以下の環境変数を設定してください：

- `LINE_CHANNEL_SECRET`: LINE Bot チャンネルシークレット
- `LINE_CHANNEL_TOKEN`: LINE Bot チャンネルトークン
- `FREEE_CLIENT_ID`: freee API クライアントID
- `FREEE_CLIENT_SECRET`: freee API クライアントシークレット
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
