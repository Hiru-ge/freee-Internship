# Fly.io デプロイガイド

## 概要

Rails 8.0.2アプリケーションをFly.ioの無料枠でデプロイするための完全ガイドです。

## 前提条件

- Fly.ioアカウント（無料）
- `flyctl` CLI ツール
- Git リポジトリ

## 1. 初期設定

### 1.1 Fly.io CLI のインストール

```bash
curl -L https://fly.io/install.sh | sh
export PATH="$PATH:$HOME/.fly/bin"
```

### 1.2 認証

```bash
fly auth login
```

## 2. アプリケーション設定

### 2.1 データベース設定（SQLite使用）

**config/database.yml**:
```yaml
production:
  primary: &primary_production
    adapter: sqlite3
    database: <%= Rails.root.join("db", "production.sqlite3") %>
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    timeout: 5000
  cache:
    <<: *primary_production
    database: <%= Rails.root.join("db", "production_cache.sqlite3") %>
    migrations_paths: db/cache_migrate
  queue:
    <<: *primary_production
    database: <%= Rails.root.join("db", "production_queue.sqlite3") %>
    migrations_paths: db/queue_migrate
  cable:
    <<: *primary_production
    database: <%= Rails.root.join("db", "production_cable.sqlite3") %>
    migrations_paths: db/cable_migrate

test:
  adapter: sqlite3
  database: <%= Rails.root.join("db", "test.sqlite3") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
```

### 2.2 Gemfile の更新

```ruby
# PostgreSQL（開発用）
gem "pg", "~> 1.1"

# SQLite（本番用 - 無料枠対応）
gem "sqlite3", "~> 2.1"
```

### 2.3 Dockerfile の設定

```dockerfile
# ベースイメージ
FROM ruby:3.2.2-slim

# システムパッケージのインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 作業ディレクトリ
WORKDIR /rails

# ビルド用パッケージのインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config sqlite3 libsqlite3-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Gemfile のコピーとインストール
COPY Gemfile Gemfile.lock ./
RUN bundle install

# アプリケーションコードのコピー
COPY . .

# アセットのプリコンパイル
RUN bundle exec rails assets:precompile

# ユーザー設定
RUN groupadd --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails
USER 1000:1000

# エントリーポイント
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# ポート公開と起動コマンド
EXPOSE 3000
CMD ["./bin/rails", "server"]
```

## 3. Fly.io 設定

### 3.1 fly.toml の作成

```toml
app = "your-app-name"
primary_region = "nrt"

[build]

[env]
  RAILS_ENV = "production"
  RAILS_SERVE_STATIC_FILES = "true"
  RAILS_LOG_TO_STDOUT = "true"
  DISABLE_DATABASE_ENVIRONMENT_CHECK = "1"
  PORT = "3000"

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    timeout = "5s"
    path = "/"

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256

# 自動マイグレーションは無効化（手動実行）
# [deploy]
#   release_command = "bundle exec rails db:migrate"
```

## 4. 重要なポイント

### 4.1 ポート設定の重要性

**❌ 間違った設定**:
```toml
internal_port = 80
PORT = "80"
```
→ 権限エラー: `Permission denied - bind(2) for "0.0.0.0" port 80`

**✅ 正しい設定**:
```toml
internal_port = 3000
PORT = "3000"
```
→ 正常動作

### 4.2 シードデータの設定

**db/seeds.rb**:
```ruby
require 'bcrypt'

# 従業員レコードの作成（冪等性を保つ）
employee_ids = ["3313254", "3316116", "3316120", "3317741"]

employee_ids.each do |employee_id|
  unless Employee.exists?(employee_id: employee_id)
    Employee.create!(
      employee_id: employee_id,
      password_hash: BCrypt::Password.create("password123"),
      role: employee_id == "3313254" ? "owner" : "employee"
    )
  end
end
```

### 4.3 環境変数の管理

**本番環境で必要な環境変数**:
```bash
# freee API設定
fly secrets set FREEE_ACCESS_TOKEN=your_token
fly secrets set FREEE_COMPANY_ID=your_company_id

# Gmail SMTP設定
fly secrets set GMAIL_USERNAME=your_email
fly secrets set GMAIL_APP_PASSWORD=your_app_password

# LINE Bot設定（使用する場合）
fly secrets set LINE_CHANNEL_SECRET=your_line_secret
fly secrets set LINE_CHANNEL_TOKEN=your_line_token

# Rails設定
fly secrets set RAILS_MASTER_KEY=your_master_key
```

**環境変数の設定手順**:
1. ローカルの`.env`ファイルから実際の値を取得
2. `fly secrets set`コマンドで設定
3. `fly apps restart`でアプリケーションを再起動

**設定確認**:
```bash
# 設定された環境変数の確認
fly secrets list -a your-app-name

# アプリケーションの再起動
fly apps restart your-app-name
```

**環境変数のトラブルシューティング**:

**問題**: freee APIで401 Unauthorizedエラーが発生
```bash
freee API Error: 401 - Unauthorized
Response body: {"status_code":401,"errors":[{"type":"unauthorized","messages":["認証に失敗しました。"]}]}
```

**解決手順**:
1. **環境変数の確認**:
   ```bash
   fly secrets list -a your-app-name
   ```

2. **アプリケーション内での環境変数確認**:
   ```bash
   fly ssh console -a your-app-name -C "echo \$FREEE_ACCESS_TOKEN"
   ```

3. **環境変数の再設定**:
   ```bash
   fly secrets set FREEE_ACCESS_TOKEN=your_actual_token -a your-app-name
   fly secrets set FREEE_COMPANY_ID=your_actual_company_id -a your-app-name
   ```

4. **自動再起動の確認**:
   - `fly secrets set`コマンドは自動的にアプリケーションを再起動します
   - ログで「Updating existing machines」メッセージを確認

**注意点**:
- 環境変数設定後は自動的にアプリケーションが再起動されます
- freee APIのアクセストークンは有効期限があるため、定期的な更新が必要
- 環境変数が空の場合は、設定が正しく反映されていない可能性があります

## 5. デプロイ手順

### 5.1 初回デプロイ

```bash
# アプリケーションの作成
fly apps create your-app-name

# デプロイ
fly deploy
```

### 5.2 データベースの初期化

```bash
# マイグレーション実行
fly ssh console -C "bundle exec rails db:migrate"

# シードデータ投入
fly ssh console -C "bundle exec rails db:seed"
```

### 5.3 継続的デプロイ

```bash
# コード変更後
git add .
git commit -m "Update application"
git push origin main

# Fly.ioが自動的にデプロイを実行
```

## 6. トラブルシューティング

### 6.1 よくある問題

**問題**: `Permission denied - bind(2) for "0.0.0.0" port 80`
**解決**: ポート3000を使用する

**問題**: `ActiveRecord::RecordInvalid: Validation failed: Employee must exist`
**解決**: シードデータで従業員レコードを事前作成

**問題**: `Zeitwerk::NameError: expected file to define constant`
**解決**: 空のファイルを削除または適切なクラス定義を追加

**問題**: `freee API Error: 401 - Unauthorized`
**解決**: 環境変数の再設定とアプリケーション再起動
```bash
# 環境変数の確認
fly secrets list -a your-app-name

# 環境変数の再設定
fly secrets set FREEE_ACCESS_TOKEN=your_token -a your-app-name
fly secrets set FREEE_COMPANY_ID=your_company_id -a your-app-name

# 自動再起動が実行される（手動再起動は不要）
```

**問題**: 環境変数が空になっている
**解決**: `fly secrets set`コマンドで再設定
```bash
# アプリケーション内での環境変数確認
fly ssh console -a your-app-name -C "echo \$FREEE_ACCESS_TOKEN"

# 空の場合は再設定
fly secrets set FREEE_ACCESS_TOKEN=your_actual_token -a your-app-name
```

### 6.2 ログの確認

```bash
# リアルタイムログ
fly logs -a your-app-name

# 特定のマシンのログ
fly logs -a your-app-name --region hkg
```

### 6.3 マシンの管理

```bash
# マシン一覧
fly machines list -a your-app-name

# マシンの起動
fly machines start <machine-id> -a your-app-name

# マシンの停止
fly machines stop <machine-id> -a your-app-name
```

## 7. パフォーマンス最適化

### 7.1 無料枠での制限

- **CPU**: 1 shared CPU
- **メモリ**: 256MB
- **ストレージ**: 1GB
- **ネットワーク**: 160GB/月

### 7.2 最適化のポイント

1. **アセットのプリコンパイル**: 本番環境で実行
2. **SQLiteの使用**: PostgreSQLより軽量
3. **auto_stop_machines**: アイドル時の自動停止
4. **min_machines_running = 0**: 必要時のみ起動

## 8. セキュリティ

### 8.1 環境変数の管理

```bash
# 機密情報は secrets で管理
fly secrets set DATABASE_URL=your_database_url
fly secrets set SECRET_KEY_BASE=your_secret_key
```

### 8.2 HTTPS の強制

```toml
[http_service]
  force_https = true
```

## 9. 監視とメンテナンス

### 9.1 ヘルスチェック

```toml
[[http_service.checks]]
  grace_period = "10s"
  interval = "30s"
  method = "GET"
  timeout = "5s"
  path = "/"
```

### 9.2 ログの監視

```bash
# エラーログの確認
fly logs -a your-app-name | grep ERROR

# アクセスログの確認
fly logs -a your-app-name | grep "GET\|POST"
```

## 10. 成功のポイント

1. **シンプルな設定**: 複雑な設定を避け、標準的な構成を使用
2. **ポート3000の使用**: 権限問題を回避
3. **SQLiteの活用**: 無料枠での制約に対応
4. **冪等なシードデータ**: 再デプロイ時のエラーを防止
5. **段階的なデプロイ**: 問題の切り分けを容易にする
6. **環境変数の適切な管理**: `fly secrets`でセキュアに管理
7. **環境変数の定期的な確認**: API認証エラーの早期発見
8. **自動再起動の理解**: `fly secrets set`は自動的にアプリを再起動

## 11. 参考リンク

- [Fly.io Documentation](https://fly.io/docs/)
- [Rails on Fly.io](https://fly.io/docs/rails/)
- [Fly.io Pricing](https://fly.io/pricing/)

---

**最終更新**: 2025年9月14日
**バージョン**: Rails 8.0.2, Ruby 3.2.2
