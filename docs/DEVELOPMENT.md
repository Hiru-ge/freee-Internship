# 開発者向けガイド

## 開発環境のセットアップ

### 前提条件
- Ruby 3.2.2
- Rails 8.0.2
- SQLite3
- Node.js (JavaScript依存関係用)
- LINE Bot開発環境（LINE Developers Console）
- freee APIアクセストークン

### セットアップ手順
```bash
# リポジトリのクローン
git clone <repository-url>
cd freee-Internship

# 依存関係のインストール
bundle install

# 環境変数の設定
cp .env.example .env
# .envファイルを編集して必要な環境変数を設定

# データベースのセットアップ
rails db:create
rails db:migrate
rails db:seed

# テストの実行
bundle exec rails test
```

### 環境変数の設定
以下の環境変数を設定してください：

```bash
# freee API設定
FREEE_ACCESS_TOKEN=your_freee_access_token
FREEE_COMPANY_ID=your_company_id

# LINE Bot設定
LINE_CHANNEL_ACCESS_TOKEN=your_line_channel_access_token
LINE_CHANNEL_SECRET=your_line_channel_secret

# メール設定
GMAIL_USERNAME=your_gmail_username
GMAIL_PASSWORD=your_gmail_password

# アクセス制限設定
ALLOWED_EMAIL_DOMAINS=@freee.co.jp
ALLOWED_EMAILS=admin@freee.co.jp

# オーナー権限設定
OWNER_EMPLOYEE_ID=your_owner_employee_id

# APIキー設定
API_KEY=your_api_key_for_github_actions
```

## 開発ガイドライン

### コーディング規約
- Ruby: 標準的なRubyコーディング規約に従う
- Rails: Railsの規約に従う
- インデント: 2スペース
- 文字エンコーディング: UTF-8

### ディレクトリ構造の理解

#### アーキテクチャの理解
本システムは**モデル中心設計（Fat Model, Skinny Controller）**を採用しています：

```
app/
├── controllers/                   # 薄層コントローラー（HTTP処理のみ）
│   ├── concerns/                  # 共通機能（認証・エラーハンドリング等）
│   └── *.rb                       # 各機能別コントローラー
├── models/                        # 厚層モデル（ビジネスロジック集約）
│   ├── concerns/                  # 共通機能（ShiftBase等）
│   └── *.rb                       # 各エンティティモデル
├── services/                      # 外部API連携特化
│   ├── freee_api_service.rb       # Freee API連携
│   ├── email_notification_service.rb # メール通知
│   └── line_*.rb                  # LINE Bot関連サービス
└── views/                         # ビューファイル
    └── shifts/                    # シフト関連ビューの統合ディレクトリ
        ├── index.html.erb         # シフト表示
        ├── approvals_index.html.erb # シフト承認一覧
        ├── additions_new.html.erb   # シフト追加依頼フォーム
        ├── deletions_new.html.erb   # シフト削除依頼フォーム
        └── exchanges_new.html.erb   # シフト交代依頼フォーム
```

#### コントローラーの責任分離
- **ApplicationController**: 基底コントローラー（認証・エラーハンドリング）
- **ShiftDisplayController**: シフトの表示機能のみ
- **ShiftApprovalsController**: シフトの承認機能のみ
- **WebhookController**: LINE Bot Webhook処理
- 各コントローラーは単一責任の原則に従う

### 新しい機能の追加

#### 1. 新しいシフト関連機能を追加する場合
```bash
# 1. コントローラーを作成
rails generate controller ShiftNewFeature

# 2. ルートを追加（config/routes.rb）
get "shift/new_feature", to: "shift_new_feature#index"

# 3. ビューファイルを app/views/shifts/ に配置
# app/views/shifts/new_feature.html.erb

# 4. テストを作成
# test/controllers/shift_new_feature_controller_test.rb
```

#### 2. LINE Bot機能の追加
```bash
# 1. 新しいLINEサービスを作成
# app/services/line_new_feature_service.rb

# 2. LineBaseServiceを継承
class LineNewFeatureService < LineBaseService
  # 実装
end

# 3. LineBaseServiceにコマンドを追加
# 4. テストを作成
```

#### 3. 既存機能の修正
- 既存のコントローラーを修正する場合は、責任範囲を超えないよう注意
- ビジネスロジックはモデル層に配置
- 外部API連携はサービス層に配置
- ビューファイルは `app/views/shifts/` に配置
- テストの更新を忘れずに

#### 4. JavaScript機能の追加
- 新しいJS機能は適切なファイルに追加
- 認証関連: `app/javascript/auth.js`
- シフト関連: `app/javascript/shift_*.js`
- 共通機能: `app/javascript/common.js`
- インラインJSの使用は禁止

### テストの実行

#### 全テストの実行
```bash
bundle exec rails test
```

#### 特定のテストの実行
```bash
# コントローラーテスト
bundle exec rails test test/controllers/

# サービステスト
bundle exec rails test test/services/

# 統合テスト
bundle exec rails test test/integration/
```

#### テストカバレッジの確認
```bash
# 詳細なテスト結果
bundle exec rails test -v
```

### デバッグ

#### ログの確認
```bash
# 開発環境のログ
tail -f log/development.log

# テスト環境のログ
tail -f log/test.log
```

#### コンソールでのデバッグ
```bash
# Railsコンソール
rails console

# テスト環境でのコンソール
rails console -e test
```

### よくある問題と解決方法

#### 1. ビューファイルが見つからない
- コントローラー名とビューディレクトリ名が一致しているか確認
- `render` メソッドで明示的にパスを指定する

#### 2. ルートが見つからない
- `config/routes.rb` でルートが正しく定義されているか確認
- `rails routes` コマンドでルート一覧を確認

#### 3. テストが失敗する
- テストの期待値が実際の動作と一致しているか確認
- 認証状態やセッションの設定を確認

#### 4. JavaScript機能が動作しない
- インラインJSの使用を避け、適切なJSファイルに実装
- `importmap.rb` に新しいJSファイルを追加
- ブラウザの開発者ツールでエラーを確認

### パフォーマンス

#### データベースクエリの最適化
- N+1クエリ問題の回避
- `includes` や `joins` の適切な使用
- インデックスの適切な設定

#### メモリ使用量の最適化
- 大量データの処理時は `find_each` を使用
- 不要なオブジェクトの生成を避ける

### セキュリティ

#### 入力値検証
- すべてのユーザー入力に対して検証を実施
- SQLインジェクション対策
- XSS対策
- パラメータ改ざん防止

#### 認証・認可
- 適切な権限チェックの実装
- セッション管理の適切な実装
- メール認証によるアクセス制限
- LINE Bot認証の実装

#### 外部API連携
- 署名検証（LINE Bot Webhook）
- APIキー認証（GitHub Actions）
- レート制限の実装

### デプロイ

#### 本番環境へのデプロイ
```bash
# 本番環境でのテスト
RAILS_ENV=production bundle exec rails test

# データベースマイグレーション
RAILS_ENV=production bundle exec rails db:migrate

# アセットのプリコンパイル
RAILS_ENV=production bundle exec rails assets:precompile
```

#### Fly.ioデプロイ
```bash
# Fly.io CLIのインストール
curl -L https://fly.io/install.sh | sh

# アプリケーションのデプロイ
flyctl deploy

# 環境変数の設定
flyctl secrets set FREEE_ACCESS_TOKEN=your_token
flyctl secrets set LINE_CHANNEL_ACCESS_TOKEN=your_token
# その他の環境変数も同様に設定
```

## トラブルシューティング

### よくあるエラー

#### 1. `NameError: uninitialized constant`
- クラス名のタイポ
- 必要なファイルのrequire忘れ

#### 2. `ActionView::MissingTemplate`
- ビューファイルのパスが間違っている
- ビューファイルが存在しない

#### 3. `ActiveRecord::RecordNotFound`
- データベースにレコードが存在しない
- IDの指定が間違っている

#### 4. JavaScript関連エラー
- `ReferenceError: function is not defined`
  - インラインJSの使用を避け、適切なJSファイルに実装
- `Uncaught TypeError: Cannot read property`
  - DOM要素の存在確認を追加
- `Failed to load resource`
  - `importmap.rb` に新しいJSファイルを追加

#### 5. LINE Bot関連エラー
- `Signature verification failed`
  - LINE_CHANNEL_SECRETの設定を確認
- `Invalid reply token`
  - リプライトークンの有効期限を確認
- `User not found`
  - 従業員認証の状態を確認

#### 6. freee API関連エラー
- `Unauthorized`
  - FREEE_ACCESS_TOKENの有効性を確認
- `Rate limit exceeded`
  - API呼び出し頻度を調整
- `Company not found`
  - FREEE_COMPANY_IDの設定を確認

### サポート
問題が解決しない場合は、以下の情報を含めて報告してください：
- エラーメッセージ
- 実行したコマンド
- 環境情報（Ruby、Railsのバージョン）
- 関連するコード
