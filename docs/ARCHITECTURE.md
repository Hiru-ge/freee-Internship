# アーキテクチャドキュメント

## 概要
勤怠管理システムのアーキテクチャとディレクトリ構造について説明します。

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

### サービス層
```
app/services/
├── auth_service.rb                # 認証サービス
├── attendance_service.rb          # 勤怠管理サービス
├── shift_display_service.rb       # シフト表示サービス
├── shift_exchange_service.rb      # シフト交代サービス
├── wage_service.rb                # 給与管理サービス
└── freee_api_service.rb           # Freee API連携サービス
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

### 1. 責任の分離
- **コントローラー**: リクエスト処理とレスポンス生成
- **サービス**: ビジネスロジック
- **モデル**: データアクセスとバリデーション

### 2. RESTful設計
- リソース指向のURL設計
- HTTPメソッドの適切な使用
- ステートレスな設計

### 3. モジュール化
- 共通機能はConcernsに分離
- サービス層でのビジネスロジック分離
- 再利用可能なコンポーネント設計

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
