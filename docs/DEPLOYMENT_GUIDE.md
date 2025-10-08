# デプロイガイド

Rails 8.0.2アプリケーションをFly.ioの無料枠でデプロイするための完全ガイドです。

## 概要

勤怠管理システムをFly.ioにデプロイして本番環境で稼働させるための手順を説明します。
本システムはWebアプリケーションとLINE Botの統合システムとして、Fly.ioの無料枠で運用可能です。

**重要**: fly.ioでの動作確認について
- fly.io上では、freeeアクセストークン（6時間で失効）を使用しているため、長時間の動作確認は困難です
- 本格的な動作確認は、引き渡し先が独自のfreee APIトークンを取得してから行ってください

## 前提条件

- Fly.ioアカウント（無料）
- `flyctl` CLI ツール
- Git リポジトリ
- freee APIアカウント
- Gmailアカウント
- LINE Bot開発環境（LINE Developers Console）

## 初期設定

### 1. Fly.io CLI のインストール

#### macOS
```bash
brew install flyctl
```

#### Linux/Windows
```bash
curl -L https://fly.io/install.sh | sh
```

### 2. Fly.io アカウント作成とログイン

```bash
# アカウント作成
flyctl auth signup

# ログイン
flyctl auth login
```

### 3. アプリケーション初期化

```bash
# プロジェクトディレクトリで実行
flyctl launch
```

このコマンドで以下のファイルが生成されます：
- `fly.toml` - Fly.io設定ファイル
- `Dockerfile` - Docker設定ファイル

## 環境設定

### 1. 環境変数の設定

**重要**: 環境変数の設定方法について
- 環境変数は以下の方法で設定できます：
  1. **Fly.io CLI**: `flyctl secrets set` コマンド
  2. **Fly.io Dashboard**: Web UI から設定
  3. **GitHub以外の方法**: 直接的な設定（推奨）

#### 本番環境用環境変数

**必須設定（freee関連）:**
```bash
# freee API設定（必須）
flyctl secrets set FREEE_ACCESS_TOKEN="your_access_token"
flyctl secrets set FREEE_COMPANY_ID="your_company_id"
flyctl secrets set OWNER_EMPLOYEE_ID="your_owner_employee_id"
```

**既に設定済み（変更不要）:**
```bash
# データベース
flyctl secrets set DATABASE_URL="sqlite3:///app/db/production.sqlite3"

# Rails設定
flyctl secrets set RAILS_MASTER_KEY="your_master_key"
flyctl secrets set RAILS_ENV="production"

# メール設定
flyctl secrets set GMAIL_USERNAME="your_email@gmail.com"
flyctl secrets set GMAIL_APP_PASSWORD="your_app_password"

# LINE Bot設定
flyctl secrets set LINE_CHANNEL_SECRET="your_channel_secret"
flyctl secrets set LINE_CHANNEL_ACCESS_TOKEN="your_channel_token"

# アクセス制限設定
flyctl secrets set ALLOWED_EMAIL_DOMAINS="@freee.co.jp"
flyctl secrets set ALLOWED_EMAILS="admin@freee.co.jp"

# APIキー設定
flyctl secrets set API_KEY="your_api_key_for_github_actions"
```

**注意**:
- 上記の「既に設定済み」の環境変数は、引き渡し時に既に設定されているため、変更する必要はありません
- 引き渡し先は「必須設定」の3つの環境変数のみを設定してください

### 2. データベース設定

#### SQLite データベース設定
```bash
# SQLiteデータベースは自動的に作成されます
# 追加の設定は不要です
```

#### データベースマイグレーション
```bash
# 本番環境でマイグレーション実行
flyctl ssh console -a your-app-name
rails db:migrate RAILS_ENV=production
```

## デプロイメント手順

### 1. 初回デプロイ

```bash
# アプリケーションをデプロイ
flyctl deploy

# デプロイ状況を確認
flyctl status
```

### 2. 継続的デプロイ

```bash
# 最新のコードをデプロイ
git push origin main
flyctl deploy
```

### 3. ロールバック

```bash
# 前のバージョンにロールバック
flyctl releases list
flyctl releases rollback <release_id>
```

## 設定ファイル

### fly.toml
```toml
app = "freee-internship"
primary_region = "hkg"

[build]

[env]
  RAILS_ENV = "production"

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256

[[statics]]
  guest_path = "/app/public"
  url_prefix = "/"
```

### Dockerfile
```dockerfile
FROM ruby:3.2.2-alpine

# 必要なパッケージをインストール
RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    nodejs \
    npm \
    tzdata

# 作業ディレクトリを設定
WORKDIR /app

# Gemfileをコピーしてbundle install
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# アプリケーションコードをコピー
COPY . .

# アセットをプリコンパイル
RUN bundle exec rails assets:precompile

# ポートを公開
EXPOSE 3000

# アプリケーションを起動
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

## 運用管理

### 1. ログ確認

```bash
# リアルタイムログ
flyctl logs

# 特定の時間のログ
flyctl logs --since 1h

# エラーログのみ
flyctl logs --level error
```

### 2. アプリケーション状態確認

```bash
# アプリケーション状態
flyctl status

# マシン一覧
flyctl machines list

# マシン詳細
flyctl machines show <machine_id>
```

### 3. SSH接続

```bash
# アプリケーションにSSH接続
flyctl ssh console

# SQLiteデータベースはローカルファイルなので直接アクセス可能
```

### 4. スケーリング

```bash
# マシン数を変更
flyctl scale count 2

# メモリを変更
flyctl scale memory 512

# CPUを変更
flyctl scale vm shared-cpu-2x
```

## 監視とアラート

### 1. ヘルスチェック

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/health', to: 'health#check'
end

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    render json: { status: 'ok', timestamp: Time.current }
  end
end
```

### 2. メトリクス監視

```bash
# メトリクス確認
flyctl metrics

# メモリ使用量
flyctl metrics memory

# CPU使用量
flyctl metrics cpu
```

### 3. アラート設定

```bash
# アラート設定
flyctl alerts create \
  --app your-app-name \
  --type cpu \
  --threshold 80 \
  --duration 5m
```

## バックアップと復旧

### 1. データベースバックアップ

```bash
# SQLiteファイルの手動バックアップ
flyctl ssh console -a your-app-name
cp /app/db/production.sqlite3 /app/backup/production_$(date +%Y%m%d).sqlite3

# バックアップファイルのダウンロード
flyctl ssh sftp get /app/backup/production_$(date +%Y%m%d).sqlite3 ./backup/
```

### 2. アプリケーション設定バックアップ

```bash
# 環境変数一覧
flyctl secrets list

# 設定ファイルバックアップ
flyctl config save
```

## トラブルシューティング

### 1. よくある問題

#### デプロイ失敗
```bash
# ログを確認
flyctl logs --level error

# ビルドログを確認
flyctl logs --build
```

#### アプリケーション起動失敗
```bash
# アプリケーション状態確認
flyctl status

# マシン詳細確認
flyctl machines show <machine_id>
```

#### データベース接続エラー
```bash
# SQLiteファイルの存在確認
flyctl ssh console -a your-app-name
ls -la /app/db/

# データベースファイルの権限確認
chmod 644 /app/db/production.sqlite3
```

### 2. パフォーマンス問題

#### メモリ不足
```bash
# メモリ使用量確認
flyctl metrics memory

# メモリ増量
flyctl scale memory 512
```

#### CPU使用率高い
```bash
# CPU使用量確認
flyctl metrics cpu

# CPU増量
flyctl scale vm shared-cpu-2x
```

### 3. セキュリティ問題

#### SSL証明書エラー
```bash
# SSL証明書確認
flyctl certs list

# 証明書更新
flyctl certs renew
```

## 本番環境仕様

### デプロイメント環境

#### 本番環境
- **プラットフォーム**: Fly.io
- **アプリケーション**: Ruby on Rails 8.0.2
- **データベース**: SQLite
- **Webサーバー**: Puma
- **プロセス管理**: Fly.io

#### ステージング環境
- **プラットフォーム**: Fly.io
- **用途**: 本番リリース前のテスト
- **データベース**: 本番環境とは別のSQLite

### インフラ構成

#### アプリケーション層
- **言語**: Ruby 3.2.2
- **フレームワーク**: Rails 8.0.2
- **Webサーバー**: Puma
- **プロセス数**: 1-3プロセス（負荷に応じて自動スケーリング）

#### データベース層
- **データベース**: SQLite 15
- **接続プール**: 5-20接続
- **バックアップ**: 日次自動バックアップ
- **レプリケーション**: マスター-スレーブ構成

#### 外部サービス
- **メール送信**: Gmail SMTP
- **API連携**: Freee API
- **Bot連携**: LINE Messaging API
- **定期実行**: GitHub Actions（打刻リマインダー）

### セキュリティ設定

#### ネットワークセキュリティ
- **HTTPS**: 強制リダイレクト
- **HSTS**: 有効
- **CORS**: 適切に設定
- **Firewall**: Fly.io標準設定

#### アプリケーションセキュリティ
- **CSRF保護**: 有効
- **XSS保護**: 有効
- **SQLインジェクション対策**: ActiveRecord使用
- **認証**: セッションベース認証 + メール認証
- **LINE Bot認証**: 従業員アカウントとの紐付け
- **APIキー認証**: GitHub Actions用

#### データ保護
- **暗号化**: 転送時・保存時暗号化
- **ログ**: 機密情報除外
- **アクセス制御**: ロールベース

### 監視とログ

#### アプリケーション監視
- **ヘルスチェック**: `/health` エンドポイント
- **メトリクス**: CPU、メモリ、レスポンス時間
- **アラート**: 閾値超過時の通知

#### ログ管理
- **アプリケーションログ**: Rails標準ログ
- **アクセスログ**: Nginxアクセスログ
- **エラーログ**: エラー詳細ログ
- **ログレベル**: 本番環境はINFO以上

### バックアップ戦略

#### データベースバックアップ
- **頻度**: 日次自動バックアップ
- **保持期間**: 30日間
- **復旧時間**: 1時間以内
- **テスト**: 月次復旧テスト

#### アプリケーション設定バックアップ
- **環境変数**: 設定ファイルとして保存
- **設定ファイル**: Gitリポジトリで管理
- **復旧手順**: ドキュメント化

### 災害復旧

#### RTO/RPO
- **RTO**: 4時間以内
- **RPO**: 24時間以内
- **復旧手順**: 手順書整備
- **テスト**: 四半期ごと

#### 復旧手順
1. 障害の特定と影響範囲の確認
2. バックアップからの復旧
3. アプリケーションの再起動
4. 機能テストと動作確認
5. ユーザーへの通知

## コスト最適化

### 1. リソース最適化

```bash
# 最小構成での起動
flyctl scale count 0

# 必要時のみスケールアップ
flyctl scale count 1
```

### 2. 無料枠活用

- **SQLite**: 無料枠内で運用
- **アプリケーション**: 最小構成で運用
- **ストレージ**: 必要最小限

### 3. 監視とアラート

```bash
# コスト監視
flyctl billing

# 使用量確認
flyctl usage
```

## 開発フロー

### 1. 開発環境

```bash
# ローカル開発
rails server

# テスト実行
bundle exec rspec

# コード品質チェック
bundle exec rubocop
```

### 2. ステージング環境

```bash
# ステージング環境にデプロイ
flyctl deploy --app your-app-staging

# ステージング環境でテスト
flyctl ssh console --app your-app-staging
```

### 3. 本番環境

```bash
# 本番環境にデプロイ
flyctl deploy --app your-app-production

# 本番環境の確認
flyctl status --app your-app-production
```

## メンテナンス

### 1. 定期メンテナンス

#### 週次メンテナンス
- ログファイルの確認
- パフォーマンスメトリクスの確認
- セキュリティアップデートの確認

#### 月次メンテナンス
- データベースの最適化
- 依存関係の更新
- バックアップのテスト

#### 四半期メンテナンス
- 災害復旧テスト
- セキュリティ監査
- パフォーマンスチューニング

### 2. 緊急メンテナンス

#### 障害対応
1. 障害の特定と影響範囲の確認
2. 緊急対応チームの招集
3. 復旧作業の実施
4. ユーザーへの通知
5. 事後分析と改善

#### セキュリティインシデント
1. インシデントの特定
2. 影響範囲の調査
3. 緊急対応の実施
4. 関係者への通知
5. 再発防止策の検討
