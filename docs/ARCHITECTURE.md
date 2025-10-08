# システムアーキテクチャ

## 概要
勤怠管理システムのアーキテクチャとディレクトリ構造について説明します。
本システムは**モデル中心設計（Fat Model, Skinny Controller）**を採用し、LINE BotとWebアプリケーションの統合システムとして、Rails Wayに完全準拠しています。

## ディレクトリ構造

### コントローラー層
```
app/controllers/
├── application_controller.rb      # 基底コントローラー
├── auth_controller.rb             # 認証・ログイン機能
├── attendance_controller.rb       # 勤怠管理機能
├── shift_display_controller.rb    # シフト表示機能
├── shift_approvals_controller.rb  # シフト承認機能
├── shift_exchanges_controller.rb  # シフト交代依頼
├── shift_additions_controller.rb  # シフト追加依頼
├── shift_deletions_controller.rb  # シフト削除依頼
├── shift_base_controller.rb       # シフト基底コントローラー
├── wages_controller.rb            # 給与管理機能
├── webhook_controller.rb          # LINE Bot Webhook
├── clock_reminder_controller.rb   # 打刻リマインダー
└── concerns/                      # 共通機能
    ├── authentication.rb          # 認証・認可・セッション管理
    ├── error_handler.rb           # エラーハンドリング
    ├── security.rb                # セキュリティ機能
    ├── freee_api_helper.rb        # Freee API連携
    └── service_response_handler.rb # サービスレスポンス処理
```

### ビュー層
```
app/views/
├── auth/                          # 認証関連ビュー
│   ├── login.html.erb
│   ├── forgot_password.html.erb
│   └── ...
├── dashboard/                     # ダッシュボード
│   ├── index.html.erb
│   └── attendance.html.erb
├── shifts/                        # シフト関連ビュー（統合済み）
│   ├── index.html.erb             # シフト表示
│   ├── approvals_index.html.erb   # シフト承認一覧
│   ├── additions_new.html.erb     # シフト追加依頼
│   ├── deletions_new.html.erb     # シフト削除依頼
│   └── exchanges_new.html.erb     # シフト交代依頼
├── wages/                         # 給与管理ビュー
│   └── index.html.erb
├── layouts/                       # レイアウト
└── shared/                        # 共通ビュー
```

### JavaScript層
```
app/javascript/
├── application.js                 # アプリケーション初期化
├── auth.js                       # 認証関連機能
├── attendance.js                 # 勤怠管理機能
├── common.js                     # 共通ユーティリティ
├── flash_messages.js             # フラッシュメッセージ
├── header.js                     # ヘッダー機能
├── loading_handler.js            # ローディング表示
├── message_handler.js            # メッセージ表示
├── shift_approvals.js            # シフト承認機能
├── shift_display.js              # シフト表示機能
├── shift_exchange.js             # シフト交代機能
└── shift_forms.js                # シフトフォーム機能
```

### サービス層（外部API特化）
```
app/services/
├── base_service.rb                # 基底サービス
├── email_notification_service.rb  # メール通知サービス
├── freee_api_service.rb          # Freee API連携
├── clock_service.rb              # 打刻API連携
├── wage_service.rb               # 給与API連携
└── line_*.rb                     # LINE Bot関連サービス（6個）
    ├── line_base_service.rb      # LINE基盤サービス（認証・状態管理）
    ├── line_webhook_service.rb   # LINE Webhook処理
    ├── line_shift_exchange_service.rb  # シフト交代処理
    ├── line_shift_addition_service.rb  # シフト追加処理
    ├── line_shift_deletion_service.rb  # シフト削除処理
    └── line_shift_display_service.rb   # シフト表示処理
```

## ルーティング構造

### 認証・ログイン
- `GET/POST /login` - ログイン
- `POST /logout` - ログアウト
- `GET/POST /password/initial` - 初回パスワード設定
- `GET/POST /password/forgot` - パスワード忘れ
- `GET/POST /password/reset` - パスワードリセット

### メイン機能
- `GET /dashboard` - ダッシュボード
- `GET /shifts` - シフト表示
- `GET /wages` - 給与管理

### 勤怠管理
- `GET /attendance` - 勤怠管理ページ
- `POST /attendance/clock_in` - 出勤打刻
- `POST /attendance/clock_out` - 退勤打刻
- `GET /attendance/clock_status` - 打刻状況取得
- `GET /attendance/attendance_history` - 勤怠履歴取得

### シフト管理
- `GET /shift/exchange/new` - シフト交代依頼フォーム
- `GET /shift/addition/new` - シフト追加依頼フォーム
- `GET /shift/deletion/new` - シフト削除依頼フォーム
- `POST /shift/exchange` - シフト交代依頼作成
- `POST /shift/addition` - シフト追加依頼作成
- `POST /shift/deletion` - シフト削除依頼作成
- `GET /shift/approvals` - シフト承認一覧
- `POST /shift/approve` - シフト承認
- `POST /shift/reject` - シフト却下

### LINE Bot
- `POST /webhook/callback` - LINE Bot Webhook

### 打刻リマインダー
- `POST /clock_reminder/trigger` - 打刻リマインダー実行（APIキー認証）

## 設計原則

### 1. モデル中心設計（Fat Model, Skinny Controller）
- **コントローラー**: HTTP処理・レスポンス制御のみ（薄層）
- **モデル**: ビジネスロジック・バリデーション・CRUD処理（厚層）
- **サービス**: 外部API連携・LINE Bot処理のみ（特化）

### 2. マルチチャネル対応
- **Webアプリケーション**: ブラウザベースの管理画面
- **LINE Bot**: チャットベースの操作インターフェース
- **統一されたビジネスロジック**: モデル層で共通化

### 3. Rails Way完全準拠
- Convention over Configuration
- DRY原則（Don't Repeat Yourself）
- 単一責任原則（Single Responsibility Principle）

### 4. 責任の明確化
- **単一リソース処理**: モデル層に完全集約
- **外部連携処理**: サービス層に特化
- **共通処理**: Concernで共通化
- **状態管理**: ConversationStateによる対話状態管理

### 5. RESTful設計
- リソース指向のURL設計
- HTTPメソッドの適切な使用
- ステートレスな設計（LINE Bot状態管理を除く）

### 6. フロントエンド分離
- HTMLとJavaScriptの完全分離
- 機能別のJSファイル構成
- 共通ユーティリティの統合
- LINE Bot用Flex Message対応

## セキュリティ

### 認証・認可
- セッションベースの認証（24時間タイムアウト）
- ロールベースのアクセス制御（オーナー・従業員）
- CSRF保護
- メールアドレス認証によるアクセス制限
- LINE Bot認証（従業員アカウントとの紐付け）

### 入力値検証
- SQLインジェクション対策
- XSS対策
- 入力値の形式検証
- パラメータ改ざん防止
- 権限昇格攻撃対策

### セッション管理
- セッションタイムアウト機能
- セッション改ざん検知
- セキュアなセッション管理

## テスト戦略

### テスト構造
```
test/
├── controllers/                   # コントローラーテスト
├── models/                        # モデルテスト
├── services/                      # サービステスト
├── integration/                   # 統合テスト
└── support/                       # テストサポート
```

### テストカバレッジ
- 全テスト100%通過（414テスト）
- コントローラー、モデル、サービス、統合テストを網羅
- エラーハンドリングのテストも含む
- LINE Bot機能のテストも実装済み

### TDD手法
- Red, Green, Refactoringのサイクル
- テストファーストでの開発
- リファクタリング時の安全性確保
