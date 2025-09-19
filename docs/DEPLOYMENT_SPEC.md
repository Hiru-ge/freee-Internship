# デプロイメント仕様書

勤怠管理システムのデプロイメント手順と運用仕様です。

## 🎯 概要

LINE Bot連携システムの本番環境へのデプロイメントと運用管理の詳細仕様です。

## 🚀 デプロイメント環境

### 本番環境
- **プラットフォーム**: Fly.io
- **アプリケーション**: Ruby on Rails 8.0.2
- **データベース**: PostgreSQL
- **Webサーバー**: Puma
- **プロセス管理**: Fly.io

### ステージング環境
- **プラットフォーム**: Fly.io
- **用途**: 本番リリース前のテスト
- **データ**: 本番データのコピー

## 📋 デプロイメント手順

### 1. 事前準備
```bash
# 依存関係のインストール
bundle install

# データベースマイグレーション
rails db:migrate

# テストの実行
rails test
```

### 2. 環境変数の設定
```bash
# Fly.io での環境変数設定
fly secrets set LINE_CHANNEL_ACCESS_TOKEN=your_token
fly secrets set LINE_CHANNEL_SECRET=your_secret
fly secrets set FREEE_ACCESS_TOKEN=your_token
fly secrets set DATABASE_URL=your_database_url
fly secrets set RAILS_MASTER_KEY=your_master_key
```

### 3. デプロイメント実行
```bash
# 本番環境へのデプロイ
fly deploy

# デプロイメント状況の確認
fly status

# ログの確認
fly logs
```

### 4. デプロイメント後の確認
```bash
# アプリケーションのヘルスチェック
fly status

# データベース接続の確認
fly ssh console
rails console
> ActiveRecord::Base.connection.execute("SELECT 1")

# LINE Bot の動作確認
# 実際にLINE Botにメッセージを送信してテスト
```

## 🔧 設定管理

### 環境変数
```bash
# LINE Bot設定
LINE_CHANNEL_ACCESS_TOKEN=your_channel_access_token
LINE_CHANNEL_SECRET=your_channel_secret

# Freee API設定
FREEE_CLIENT_ID=your_client_id
FREEE_CLIENT_SECRET=your_client_secret
FREEE_ACCESS_TOKEN=your_access_token

# データベース設定
DATABASE_URL=postgresql://user:password@host:port/database

# Rails設定
RAILS_ENV=production
RAILS_MASTER_KEY=your_master_key
SECRET_KEY_BASE=your_secret_key_base

# メール設定
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email
SMTP_PASSWORD=your_password
```

### Fly.io設定
```toml
# fly.toml
app = "your-app-name"
primary_region = "nrt"

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
```

## 📊 監視・ログ

### アプリケーション監視
```ruby
# ヘルスチェックエンドポイント
class HealthController < ApplicationController
  def index
    render json: {
      status: 'ok',
      timestamp: Time.current,
      version: Rails.application.config.version
    }
  end
end
```

### ログ管理
```ruby
# ログ設定
config.log_level = :info
config.log_formatter = ::Logger::Formatter.new

# 構造化ログ
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
```

### 監視項目
- **アプリケーション**: レスポンス時間、エラー率
- **データベース**: 接続数、クエリ時間
- **外部API**: Freee API のレスポンス時間
- **LINE Bot**: メッセージ処理時間

## 🔄 バックアップ・復旧

### データベースバックアップ
```bash
# 日次バックアップ
fly postgres backup create

# バックアップリスト
fly postgres backup list

# バックアップからの復旧
fly postgres backup restore <backup-id>
```

### アプリケーションバックアップ
```bash
# 設定のバックアップ
fly secrets list > secrets_backup.txt

# アプリケーション設定のバックアップ
fly config show > fly_config_backup.toml
```

## 🚨 障害対応

### 障害検知
```ruby
# ヘルスチェック
def health_check
  {
    database: database_healthy?,
    freee_api: freee_api_healthy?,
    line_bot: line_bot_healthy?
  }
end

def database_healthy?
  ActiveRecord::Base.connection.execute("SELECT 1")
  true
rescue
  false
end
```

### 障害対応手順
1. **障害の検知**: 監視システムからのアラート
2. **影響範囲の確認**: どの機能に影響があるか
3. **緊急対応**: 必要に応じてサービス停止
4. **原因調査**: ログの確認と分析
5. **復旧作業**: 修正の適用とデプロイ
6. **事後対応**: 再発防止策の検討

## 📈 パフォーマンス最適化

### データベース最適化
```sql
-- インデックスの追加
CREATE INDEX idx_employees_line_id ON employees(line_id);
CREATE INDEX idx_conversation_states_line_user_id ON conversation_states(line_user_id);
CREATE INDEX idx_shifts_employee_date ON shifts(employee_id, shift_date);
```

### アプリケーション最適化
```ruby
# クエリ最適化
def find_employee_by_line_id(line_id)
  Employee.includes(:shifts).find_by(line_id: line_id)
end

# キャッシュの活用
def fetch_employees
  Rails.cache.fetch("employees", expires_in: 1.hour) do
    FreeeApiService.new.fetch_employees
  end
end
```

## 🔐 セキュリティ

### 本番環境のセキュリティ
- **HTTPS**: 強制HTTPS化
- **環境変数**: 機密情報の環境変数化
- **アクセス制御**: IP制限の設定
- **ログ管理**: 機密情報のログ出力禁止

### セキュリティ監査
```ruby
# セキュリティヘッダーの設定
config.force_ssl = true
config.ssl_options = {
  redirect: { exclude: ->(request) { request.path =~ /health/ } }
}
```

## 📊 運用メトリクス

### パフォーマンスメトリクス
- **レスポンス時間**: 平均200ms以下
- **スループット**: 100リクエスト/秒
- **エラー率**: 1%以下
- **可用性**: 99.9%以上

### ビジネスメトリクス
- **LINE Bot利用者数**: 月次増加率
- **シフト管理機能利用率**: 日次利用数
- **ユーザー満足度**: フィードバック分析

## 🔄 リリース管理

### リリース手順
1. **開発**: 機能開発とテスト
2. **ステージング**: ステージング環境でのテスト
3. **本番リリース**: 本番環境へのデプロイ
4. **監視**: リリース後の監視
5. **ロールバック**: 問題発生時のロールバック

### バージョン管理
```ruby
# バージョン情報
module Application
  VERSION = "1.0.0"
  BUILD_DATE = "2024-12-01"
end
```

## 🧪 テスト環境

### テスト環境の構築
```bash
# テスト環境のデプロイ
fly deploy --config fly.staging.toml

# テストデータの投入
fly ssh console -a staging-app
rails db:seed
```

### テスト実行
```bash
# 統合テストの実行
rails test:integration

# パフォーマンステストの実行
rails test:performance
```

## 📚 運用ドキュメント

### 運用手順書
- **デプロイメント手順**: 本番リリースの手順
- **監視手順**: システム監視の方法
- **障害対応手順**: 障害発生時の対応
- **バックアップ手順**: データバックアップの方法

### 連絡先
- **開発チーム**: dev-team@company.com
- **運用チーム**: ops-team@company.com
- **緊急連絡先**: emergency@company.com

## 🚀 今後の改善計画

### 技術的改善
- **CI/CD**: GitHub Actions の活用 ✅ 完了
- **監視**: より詳細な監視の実装
- **ログ**: 構造化ログの導入
- **メトリクス**: ビジネスメトリクスの収集

### 打刻忘れアラートの自動実行
- **実行方式**: GitHub Actions による定期実行
- **実行頻度**: 毎時0分、15分、30分、45分
- **アラート仕様**:
  - 出勤打刻忘れ: シフト開始時刻を過ぎて1時間以内
  - 退勤打刻忘れ: シフト終了時刻を過ぎて1時間以内
- **実装状況**: ✅ 完了（2025年1月）

### 運用改善
- **自動化**: デプロイメントの自動化
- **監視**: 24時間監視の実装
- **バックアップ**: 自動バックアップの設定
- **復旧**: 災害復旧計画の策定

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
