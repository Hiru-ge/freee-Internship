# システムアーキテクチャ

## 概要
勤怠管理システムのアーキテクチャとディレクトリ構造について説明します。
本システムは**モデル中心設計（Fat Model, Skinny Controller）**を採用し、Rails Wayに完全準拠しています。

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
├── wages_controller.rb            # 給与管理機能
└── concerns/                      # 共通機能
    ├── authentication.rb          # 認証関連
    ├── input_validation.rb        # 入力値検証
    ├── error_handler.rb           # エラーハンドリング
    └── freee_api_helper.rb        # Freee API連携
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
└── line_*.rb                     # LINE Bot関連サービス（5個）
    ├── line_base_service.rb      # LINE基盤サービス
    ├── line_shift_addition_service.rb
    ├── line_shift_exchange_service.rb
    ├── line_shift_deletion_service.rb
    ├── line_shift_display_service.rb
    └── line_webhook_service.rb
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
- `POST /attendance/clock_in` - 出勤
- `POST /attendance/clock_out` - 退勤
- `GET /attendance/status` - 勤怠状況

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

## 設計原則

### 1. モデル中心設計（Fat Model, Skinny Controller）
- **コントローラー**: HTTP処理・レスポンス制御のみ（薄層）
- **モデル**: ビジネスロジック・バリデーション・CRUD処理（厚層）
- **サービス**: 外部API連携・メール送信のみ（特化）

### 2. Rails Way完全準拠
- Convention over Configuration
- DRY原則（Don't Repeat Yourself）
- 単一責任原則（Single Responsibility Principle）

### 3. 責任の明確化
- **単一リソース処理**: モデル層に完全集約
- **外部連携処理**: サービス層に特化
- **共通処理**: Concernで共通化

### 4. RESTful設計
- リソース指向のURL設計
- HTTPメソッドの適切な使用
- ステートレスな設計

### 5. フロントエンド分離
- HTMLとJavaScriptの完全分離
- 機能別のJSファイル構成
- 共通ユーティリティの統合

## セキュリティ

### 認証・認可
- セッションベースの認証
- ロールベースのアクセス制御
- CSRF保護

### 入力値検証
- SQLインジェクション対策
- XSS対策
- 入力値の形式検証

## テスト戦略

### テスト構造
```
test/
├── controllers/                   # コントローラーテスト
├── services/                      # サービステスト
├── integration/                   # 統合テスト
└── support/                       # テストサポート
```

### テストカバレッジ
- 全テスト100%通過
- コントローラー、サービス、統合テストを網羅
- エラーハンドリングのテストも含む
