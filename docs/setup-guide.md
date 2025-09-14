# セットアップガイド

## 概要

勤怠管理システムの開発環境構築から本番環境デプロイまでの詳細な手順を説明します。

## 前提条件

### 必要なソフトウェア

- **Ruby**: 3.2.2以上
- **Rails**: 8.0.2
- **SQLite**: 3.0以上（全環境）
- **Node.js**: 18以上（アセットパイプライン用）
- **Git**: 2.0以上

### 必要なアカウント

- **freee API**: 従業員・給与データ取得用
- **Gmail**: メール送信用
- **Fly.io**: 本番環境デプロイ用（推奨）

## 開発環境セットアップ

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd freee-Internship
```

### 2. Ruby環境の確認

```bash
ruby --version
# => ruby 3.2.2p53 (2023-03-30 revision e51014f9c0) [x86_64-linux]
```

### 3. 依存関係のインストール

```bash
# Bundlerのインストール
gem install bundler

# 依存関係のインストール
bundle install

# Node.js依存関係のインストール（必要に応じて）
npm install
```

### 4. データベースの設定

#### SQLiteのインストール

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install sqlite3 libsqlite3-dev
```

**macOS (Homebrew):**
```bash
brew install sqlite3
```

**Windows:**
[SQLite公式サイト](https://www.sqlite.org/download.html)からインストーラーをダウンロード

#### データベース設定

全環境でSQLiteを使用します（開発・テスト・本番環境統一）。

**config/database.yml**:
```yaml
development:
  adapter: sqlite3
  database: <%= Rails.root.join("db", "development.sqlite3") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

test:
  adapter: sqlite3
  database: <%= Rails.root.join("db", "test.sqlite3") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

production:
  primary: &primary_production
    adapter: sqlite3
    database: <%= Rails.root.join("db", "production.sqlite3") %>
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    timeout: 5000
```

### 5. 環境変数の設定

`.env`ファイルを作成：

```bash
touch .env
```

以下の内容を記述：

```bash
# freee API設定
FREEE_ACCESS_TOKEN=your_freee_access_token_here
FREEE_COMPANY_ID=your_freee_company_id_here

# Gmail SMTP設定
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here

# アプリケーション設定
RAILS_ENV=development
RAILS_MASTER_KEY=your_master_key_here
```

### 環境変数の取得方法

#### freee API設定
1. [freee API管理画面](https://secure.freee.co.jp/oauth/applications)にログイン
2. 新しいアプリケーションを作成
3. アクセストークンを生成
4. 会社IDを確認

#### Gmail SMTP設定
1. Googleアカウントの2段階認証を有効化
2. [アプリパスワード](https://myaccount.google.com/apppasswords)を生成
3. 16文字のアプリパスワードを取得

#### Rails設定
1. `config/master.key`ファイルから`RAILS_MASTER_KEY`を取得
2. または`rails credentials:show`で確認

### 6. データベースの初期化

```bash
# データベースの準備（作成・マイグレーション・シード）
rails db:prepare

# または個別に実行
rails db:create
rails db:migrate
rails db:seed
```

### 7. サーバーの起動

```bash
rails server
```

ブラウザで `http://localhost:3000` にアクセスして動作確認。

## freee API設定

### 1. freeeアカウントの準備

1. [freee](https://secure.freee.co.jp/)にログイン
2. 管理画面でAPI連携を有効化
3. アクセストークンを取得

### 2. API設定の確認

```bash
# RailsコンソールでAPI接続テスト
rails console

# API接続テスト
FreeeApiService.get_all_employees
```

## Gmail設定

### 1. アプリパスワードの作成

1. Googleアカウントのセキュリティ設定にアクセス
2. 2段階認証を有効化
3. アプリパスワードを生成
4. 生成されたパスワードを`.env`ファイルに設定

### 2. SMTP設定の確認

```bash
# Railsコンソールでメール送信テスト
rails console

# テストメール送信
ActionMailer::Base.mail(
  from: ENV['GMAIL_USERNAME'],
  to: 'test@example.com',
  subject: 'Test Email',
  body: 'This is a test email'
).deliver_now
```

## 本番環境デプロイ（Fly.io）

### 1. Fly.io CLIのインストール

**Ubuntu/Debian:**
```bash
curl -L https://fly.io/install.sh | sh
```

**macOS:**
```bash
brew install flyctl
```

**Windows:**
[Fly.io CLI公式サイト](https://fly.io/docs/hands-on/install-flyctl/)からインストーラーをダウンロード

### 2. Fly.ioアプリの作成

```bash
# Fly.ioにログイン
fly auth login

# アプリの作成
fly launch

# PostgreSQLデータベースの作成
fly postgres create --name your-app-db
```

### 3. 環境変数の設定

```bash
# Fly.io CLIで環境変数を設定
fly secrets set RAILS_ENV=production -a your-app-name
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key) -a your-app-name
fly secrets set FREEE_ACCESS_TOKEN=your_freee_access_token -a your-app-name
fly secrets set FREEE_COMPANY_ID=your_freee_company_id -a your-app-name
fly secrets set GMAIL_USERNAME=your_gmail_address@gmail.com -a your-app-name
fly secrets set GMAIL_APP_PASSWORD=your_gmail_app_password -a your-app-name
```

**環境変数の確認**:
```bash
# 設定された環境変数の確認
fly secrets list -a your-app-name

# アプリケーション内での環境変数確認
fly ssh console -a your-app-name -C "echo \$FREEE_ACCESS_TOKEN"
```

### 4. デプロイの実行

```bash
# 本番環境へのデプロイ
fly deploy

# データベースマイグレーション（SQLiteの場合、自動実行される）
fly ssh console -a your-app-name -C "bundle exec rails db:migrate"

# シードデータの投入（自動実行される）
fly ssh console -a your-app-name -C "bundle exec rails db:seed"

# アプリの起動確認
fly open
```

**デプロイ時のシードデータ自動実行**:
`fly.toml`に以下の設定を追加することで、デプロイ時に自動的にシードデータが実行されます：

```toml
[deploy]
  release_command = "bundle exec rails db:seed"
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. データベース接続エラー

```bash
# SQLiteデータベースファイルの確認
ls -la db/

# データベースの再作成
rails db:drop db:create db:migrate
```

#### 2. 依存関係のインストールエラー

```bash
# Bundlerの更新
gem update bundler

# 依存関係の再インストール
bundle install --force
```

#### 3. アセットのコンパイルエラー

```bash
# アセットのプリコンパイル
rails assets:precompile

# キャッシュのクリア
rails tmp:clear
```

#### 4. freee API接続エラー

- アクセストークンの有効性を確認
- 会社IDが正しいか確認
- API制限に達していないか確認

#### 5. メール送信エラー

- Gmailアプリパスワードが正しいか確認
- 2段階認証が有効か確認
- SMTP設定が正しいか確認

#### 6. Fly.ioデプロイエラー

**問題**: `failed to get lease on VM`
```bash
Error: failed to acquire leases: Unrecoverable error: failed to get lease on VM
```

**解決手順**:
1. アプリケーションの削除・再作成
2. 環境変数の再設定
3. デプロイの再実行

```bash
# アプリケーションの削除
fly apps destroy your-app-name --yes

# 新規アプリケーションの作成
fly apps create your-app-name

# 環境変数の再設定
fly secrets set FREEE_ACCESS_TOKEN=your_token -a your-app-name
fly secrets set FREEE_COMPANY_ID=your_company_id -a your-app-name
# その他の環境変数も設定

# デプロイの実行
fly deploy
```

#### 7. 環境変数が空になる問題

**問題**: アプリケーション内で環境変数が空になる

**解決手順**:
```bash
# 環境変数の再設定
fly secrets set FREEE_ACCESS_TOKEN=your_actual_token -a your-app-name

# アプリケーションの再起動
fly apps restart your-app-name
```

## 開発時の注意点

### 1. セキュリティ

- `.env`ファイルをGitにコミットしない
- 本番環境の認証情報を開発環境で使用しない
- 定期的にパスワードを変更する

### 2. データベース

- 本番データを開発環境にコピーしない
- マイグレーション前にバックアップを取る
- テストデータは適切に管理する

### 3. ログ管理

- 本番環境では適切なログレベルを設定
- 機密情報をログに出力しない
- ログローテーションを設定

## パフォーマンス最適化

### 1. データベース

- 適切なインデックスの設定
- N+1クエリの回避
- クエリの最適化

### 2. アセット

- アセットの圧縮
- CDNの利用
- キャッシュの設定

### 3. アプリケーション

- メモリ使用量の監視
- レスポンス時間の測定
- スケーラビリティの考慮

## 監視とメンテナンス

### 1. ヘルスチェック

```bash
# アプリケーションの状態確認
curl http://localhost:3000/health

# データベース接続確認
rails runner "ActiveRecord::Base.connection.execute('SELECT 1')"
```

### 2. ログ監視

```bash
# アプリケーションログの確認
tail -f log/development.log

# Fly.ioログの確認
fly logs -a your-app-name
```

### 3. バックアップ

```bash
# データベースバックアップ（SQLite）
cp db/development.sqlite3 backup_development.sqlite3
cp db/test.sqlite3 backup_test.sqlite3

# Fly.ioバックアップ（SQLiteの場合）
fly ssh console -a your-app-name -C "cp db/production.sqlite3 /tmp/backup.sqlite3"
```

このガイドに従ってセットアップを行うことで、勤怠管理システムを正常に動作させることができます。
