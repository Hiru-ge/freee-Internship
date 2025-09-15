# 勤怠管理システム (Attendance Management System)

勤怠管理・シフト管理・給与管理を行うRailsアプリケーションです。

## 概要

このシステムは、従業員の勤怠管理、シフト管理、給与状況確認を行うWebアプリケーションです。GAS（Google Apps Script）からRuby on Railsに完全移行しました。

## 主な機能

### 認証システム
- **ログイン/ログアウト**: 従業員IDとパスワードによる認証
- **初回パスワード設定**: 新規従業員のパスワード初期設定
- **パスワード変更**: セキュアなパスワード変更機能
- **パスワード忘れ**: メールによるパスワードリセット

### シフト管理
- **シフト確認**: 月間シフト表の表示
- **シフト交代依頼**: 他の従業員への交代依頼
- **シフト追加依頼**: 新しいシフトの追加申請
- **シフト承認**: 管理者によるシフト依頼の承認/否認

### 勤怠管理
- **打刻機能**: 出勤・退勤・休憩の打刻
- **勤怠状況確認**: 日別・月別勤怠記録の表示
- **勤怠統計**: 勤務時間の集計と表示

### 給与管理
- **103万の壁ゲージ**: 年収103万円の壁を視覚的に表示
- **時間帯別時給計算**: 深夜・早朝・休日等の時給計算
- **給与データ表示**: freee APIから取得した給与情報の表示

### freee API連携
- **従業員情報取得**: リアルタイムでの従業員データ同期
- **給与データ取得**: 最新の給与情報の取得
- **組織情報取得**: 部署・役職情報の取得

### LINE Bot連携
- **ヘルプ表示**: 利用可能なコマンドの一覧表示
- **認証機能**: 認証コード生成（準備中）
- **シフト確認**: シフト情報の確認（準備中）
- **勤怠確認**: 勤怠状況の確認（準備中）

### メール通知
- **シフト依頼通知**: シフト交代・追加依頼の自動通知
- **承認結果通知**: シフト承認/否認結果の通知
- **システム通知**: 重要なシステム更新の通知

### セキュリティ機能
- **セッションタイムアウト**: 24時間の自動セッション期限切れ
- **CSRF保護**: クロスサイトリクエストフォージェリ攻撃の防止
- **セキュリティヘッダー**: XSS、クリックジャッキング等の攻撃防止
- **入力値検証**: サーバーサイドでの厳格な入力値チェック

### パフォーマンス最適化
- **N+1問題解決**: データベースクエリの大幅削減
- **API呼び出し最適化**: freee APIの重複呼び出し削減
- **キャッシュ戦略**: 5分間のデータキャッシュ機能
- **レート制限**: API制限への適切な対応

## 技術スタック

- **Backend**: Ruby on Rails 8.0.2
- **Database**: SQLite (全環境)
- **Bot**: LINE Bot API (line-bot-api gem)
- **External APIs**: freee API, Google Sheets API
- **Deployment**: Fly.io (無料枠対応)
- **Testing**: Minitest (TDD approach)

## セットアップ

### 前提条件

- Ruby 3.2.2以上
- SQLite 3.0以上
- LINE Bot アカウント
- freee API アカウント
- Fly.io アカウント (本番デプロイ用)

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

Fly.ioへのデプロイ手順：

1. Fly.io CLIのインストール
2. Fly.ioアプリの作成
3. 環境変数の設定
4. デプロイの実行

```bash
# Fly.io CLIのインストール
curl -L https://fly.io/install.sh | sh

# アプリの作成
fly apps create your-app-name

# 環境変数の設定
fly secrets set FREEE_ACCESS_TOKEN=your_token -a your-app-name
fly secrets set FREEE_COMPANY_ID=your_company_id -a your-app-name
fly secrets set GMAIL_USERNAME=your_email -a your-app-name
fly secrets set GMAIL_APP_PASSWORD=your_app_password -a your-app-name

# デプロイの実行
fly deploy
```

詳細なデプロイ手順は [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) を参照してください。

## 開発状況

- ✅ Rails移行完了
- ✅ 認証システム完全移行
- ✅ シフト管理システム完全移行
- ✅ セキュリティ機能強化完了
- ✅ パフォーマンス最適化完了
- ✅ 勤怠管理システム完全移行
- ✅ 給与管理システム完全移行
- ✅ freee API連携完了
- ✅ メール通知システム完了（Gmail SMTP対応）
- ✅ UI/UXデザイン改善完了
- ✅ Fly.ioデプロイ完了
- ✅ LINE Bot連携基本機能完了（Phase 9-0）

## ドキュメント

- [デプロイガイド](DEPLOYMENT_GUIDE.md) - Fly.ioへのデプロイ手順とトラブルシューティング
- [実装状況](docs/implementation-status.md) - 現在の実装状況と進捗
- [セキュリティ強化](docs/security-enhancement.md) - セキュリティ機能の詳細
- [パフォーマンス最適化](docs/performance-optimization.md) - N+1問題解決とAPI最適化
- [データベース設計](docs/schema-database.md) - データベーススキーマと設計思想
- [API仕様書](docs/api-specification.md) - 外部API連携の仕様
- [セットアップガイド](docs/setup-guide.md) - 開発環境の構築手順
- [LINE Bot連携](docs/line_bot_integration.md) - LINE Bot機能の詳細
- [LINE Bot デプロイ手順](docs/line_bot_deployment.md) - LINE Botのデプロイと設定
- [LINE Bot API仕様](docs/line_bot_api_spec.md) - LINE Bot APIの仕様書

詳細な実装状況は `docs/` ディレクトリ内のドキュメントを参照してください。

## ライセンス

MIT License
