# セットアップガイド

勤怠管理システムの開発環境構築から本番環境デプロイまでの詳細な手順を説明します。

## クイックスタート

```bash
# リポジトリのクローン
git clone <repository-url>
cd freee-Internship

# 依存関係のインストール
bundle install

# データベースのセットアップ
rails db:setup

# サーバーの起動
rails server
```

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

### 1. 依存関係のインストール

```bash
# Bundlerのインストール
gem install bundler

# 依存関係のインストール
bundle install
```

### 2. データベースの設定

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
  adapter: sqlite3
  database: <%= Rails.root.join("db", "production.sqlite3") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
```

### 3. 環境変数の設定

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

# アクセス制限設定
ALLOWED_EMAIL_ADDRESSES=okita2710@gmail.com

# Clock Reminder API設定
CLOCK_REMINDER_API_KEY=your_clock_reminder_api_key_here

# アプリケーション設定
RAILS_ENV=development
RAILS_MASTER_KEY=your_master_key_here
```

### 4. データベースの初期化

```bash
# データベースの準備（作成・マイグレーション・シード）
rails db:prepare

# または個別に実行
rails db:create
rails db:migrate
rails db:seed
```

### 5. サーバーの起動

```bash
rails server
```

ブラウザで `http://localhost:3000` にアクセスして動作確認。

## 🔑 環境変数の取得方法

### freee API設定
1. [freee API管理画面](https://secure.freee.co.jp/oauth/applications)にログイン
2. 新しいアプリケーションを作成
3. アクセストークンを生成
4. 会社IDを確認

### Gmail SMTP設定
1. Googleアカウントの2段階認証を有効化
2. [アプリパスワード](https://myaccount.google.com/apppasswords)を生成
3. 16文字のアプリパスワードを取得

### Rails設定
1. `config/master.key`ファイルから`RAILS_MASTER_KEY`を取得
2. または`rails credentials:show`で確認

## 🧪 動作確認

### freee API接続テスト

```bash
# RailsコンソールでAPI接続テスト
rails console

# API接続テスト
FreeeApiService.get_all_employees
```

### メール送信テスト

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

詳細なデプロイ手順は [DEPLOYMENT.md](DEPLOYMENT.md) を参照してください。

### 基本的なデプロイ手順

```bash
# Fly.io CLIのインストール
curl -L https://fly.io/install.sh | sh

# 認証
fly auth login

# アプリの作成
fly launch

# 環境変数の設定
fly secrets set FREEE_ACCESS_TOKEN=your_token
fly secrets set FREEE_COMPANY_ID=your_company_id
fly secrets set GMAIL_USERNAME=your_email
fly secrets set GMAIL_APP_PASSWORD=your_app_password
fly secrets set ALLOWED_EMAIL_ADDRESSES=okita2710@gmail.com
fly secrets set CLOCK_REMINDER_API_KEY=your_clock_reminder_api_key_here

# デプロイ
fly deploy
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

#### 3. freee API接続エラー

- アクセストークンの有効性を確認
- 会社IDが正しいか確認
- API制限に達していないか確認

#### 4. メール送信エラー

- Gmailアプリパスワードが正しいか確認
- 2段階認証が有効か確認
- SMTP設定が正しいか確認

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

## 🔒 セキュリティ

### 1. 環境変数の管理
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
```

このガイドに従ってセットアップを行うことで、勤怠管理システムを正常に動作させることができます。
