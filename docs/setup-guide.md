# セットアップガイド

## 概要

勤怠管理システムの開発環境構築から本番環境デプロイまでの詳細な手順を説明します。

## 前提条件

### 必要なソフトウェア

- **Ruby**: 3.3.0以上
- **Rails**: 8.0.2
- **PostgreSQL**: 12以上
- **Node.js**: 18以上（アセットパイプライン用）
- **Git**: 2.0以上

### 必要なアカウント

- **freee API**: 従業員・給与データ取得用
- **Gmail**: メール送信用
- **Heroku**: 本番環境デプロイ用（オプション）

## 開発環境セットアップ

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd freee-Internship
```

### 2. Ruby環境の確認

```bash
ruby --version
# => ruby 3.3.0p0 (2023-12-25 revision 5124f9ac75) [x86_64-linux]
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

#### PostgreSQLのインストール

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

**macOS (Homebrew):**
```bash
brew install postgresql
brew services start postgresql
```

**Windows:**
[PostgreSQL公式サイト](https://www.postgresql.org/download/windows/)からインストーラーをダウンロード

#### データベースの作成

```bash
# PostgreSQLに接続
sudo -u postgres psql

# データベースとユーザーの作成
CREATE DATABASE freee_internship_development;
CREATE DATABASE freee_internship_test;
CREATE USER freee_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE freee_internship_development TO freee_user;
GRANT ALL PRIVILEGES ON DATABASE freee_internship_test TO freee_user;
\q
```

### 5. 環境変数の設定

`.env`ファイルを作成：

```bash
touch .env
```

以下の内容を記述：

```bash
# データベース設定
DATABASE_URL=postgresql://freee_user:your_password@localhost/freee_internship_development

# freee API設定
FREEE_ACCESS_TOKEN=your_freee_access_token_here
FREEE_COMPANY_ID=your_freee_company_id_here

# Gmail SMTP設定
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here

# アプリケーション設定
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base_here

# セキュリティ設定
RAILS_MASTER_KEY=your_master_key_here
```

### 6. データベースの初期化

```bash
# データベースの作成
rails db:create

# マイグレーションの実行
rails db:migrate

# シードデータの投入（オプション）
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

## 本番環境デプロイ（Heroku）

### 1. Heroku CLIのインストール

**Ubuntu/Debian:**
```bash
curl https://cli-assets.heroku.com/install.sh | sh
```

**macOS:**
```bash
brew tap heroku/brew && brew install heroku
```

**Windows:**
[Heroku CLI公式サイト](https://devcenter.heroku.com/articles/heroku-cli)からインストーラーをダウンロード

### 2. Herokuアプリの作成

```bash
# Herokuにログイン
heroku login

# アプリの作成
heroku create your-app-name

# PostgreSQLアドオンの追加
heroku addons:create heroku-postgresql:hobby-dev
```

### 3. 環境変数の設定

```bash
# 環境変数の設定
heroku config:set FREEE_ACCESS_TOKEN=your_freee_access_token
heroku config:set FREEE_COMPANY_ID=your_freee_company_id
heroku config:set GMAIL_USERNAME=your_gmail_address@gmail.com
heroku config:set GMAIL_APP_PASSWORD=your_gmail_app_password
heroku config:set RAILS_ENV=production
heroku config:set SECRET_KEY_BASE=your_secret_key_base
```

### 4. デプロイの実行

```bash
# 本番環境へのデプロイ
git push heroku main

# データベースマイグレーション
heroku run rails db:migrate

# アプリの起動確認
heroku open
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. データベース接続エラー

```bash
# PostgreSQLサービスの確認
sudo systemctl status postgresql

# サービスの開始
sudo systemctl start postgresql
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

# Herokuログの確認
heroku logs --tail
```

### 3. バックアップ

```bash
# データベースバックアップ
pg_dump freee_internship_development > backup.sql

# Herokuバックアップ
heroku pg:backups:capture
```

このガイドに従ってセットアップを行うことで、勤怠管理システムを正常に動作させることができます。
