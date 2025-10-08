# システム依存関係とアーキテクチャ

## 概要

勤怠管理システムの現在のアーキテクチャと各コンポーネント間の依存関係を説明します。
本システムは**モデル中心設計（Fat Model, Skinny Controller）**を採用し、LINE BotとWebアプリケーションの両方に対応した統合システムです。

## アーキテクチャ概要

### 設計原則
- **Fat Model, Skinny Controller**: ビジネスロジックはモデル層に集約
- **サービス層の特化**: 外部API連携とLINE Bot処理のみに限定
- **薄いコントローラ**: HTTP処理とレスポンス制御のみ
- **共通処理のConcern化**: 重複排除とコードの再利用
- **マルチチャネル対応**: WebとLINE Botの統一されたビジネスロジック

### 層構造
```
┌─────────────────────────────────────────────────────────────┐
│                    プレゼンテーション層                      │
│  Web Controllers + LINE Bot Services + Views + JavaScript  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      ビジネスロジック層                      │
│  Models (Fat) + Concerns + Validations + State Management  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      外部連携・通知層                        │
│  Freee API + LINE API + Email Services + Clock Services    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        データ層                             │
│  Database (SQLite3) + ActiveRecord + Conversation States   │
└─────────────────────────────────────────────────────────────┘
```

## コンポーネント依存関係

### 1. コントローラ層（薄層設計）

#### 基底コントローラ
```
ApplicationController
├── ErrorHandler (include) - エラーハンドリング
├── Authentication (include) - 認証・認可・セッション管理
├── Security (include) - セキュリティ機能
├── FreeeApiHelper (include) - Freee API連携ヘルパー
└── ServiceResponseHandler (include) - サービスレスポンス処理
```

#### 機能別コントローラ
```
AuthController
├── ApplicationController (継承)
├── Employee.authenticate_login() - 認証処理
├── Employee.setup_initial_password() - 初期パスワード設定
└── Employee.change_password!() - パスワード変更

AttendanceController
├── ApplicationController (継承)
├── ClockService.new() - 打刻サービス初期化
├── ClockService.clock_in() - 出勤打刻
├── ClockService.clock_out() - 退勤打刻
└── ClockService.get_clock_status() - 打刻状態取得

ShiftDisplayController
├── ApplicationController (継承)
├── Shift.for_employee() - 個人シフト取得
├── Shift.for_month() - 月次シフト取得
├── Shift.get_monthly_shifts() - 全従業員月次シフト
└── Employee.calculate_monthly_wage() - 給与計算

ShiftExchangesController
├── ShiftBaseController (継承)
├── ShiftExchange.create_request_for() - 交代申請作成
├── ShiftExchange.send_notifications!() - 通知送信
└── バリデーション・エラーハンドリング

ShiftAdditionsController
├── ShiftBaseController (継承)
├── ShiftAddition.create_request_for() - 追加申請作成
├── ShiftAddition.send_notifications!() - 通知送信
└── オーナー権限チェック

ShiftDeletionsController
├── ShiftBaseController (継承)
├── ShiftDeletion.create_request_for() - 削除申請作成
├── ShiftDeletion.send_notifications!() - 通知送信
└── 削除可能性チェック

ShiftApprovalsController
├── ShiftBaseController (継承)
├── ShiftExchange.approve_by!() - 交代承認
├── ShiftExchange.reject_by!() - 交代拒否
├── ShiftAddition.approve_by!() - 追加承認
├── ShiftAddition.reject_by!() - 追加拒否
├── ShiftDeletion.approve_by!() - 削除承認
└── ShiftDeletion.reject_by!() - 削除拒否

WagesController
├── ApplicationController (継承)
├── Employee.calculate_wage_for_period() - 期間給与計算
├── Employee.calculate_monthly_hours_from_shifts() - 月次勤務時間
└── Employee.calculate_wage_from_hours() - 時間から給与計算

WebhookController
├── ApplicationController (継承)
├── LineWebhookService.process_webhook_events() - LINEイベント処理
├── LineWebhookService.process_single_webhook_event() - 個別イベント処理
└── LINE Bot認証・署名検証
```

### 2. モデル層（Fat Model設計）

#### 基底モデルとConcern
```
ApplicationRecord
└── ActiveRecord::Base (継承)

ShiftBase (Concern)
├── 共通バリデーション（日付・時間・ステータス）
├── ステータス管理（pending/approved/rejected/cancelled）
├── 通知処理（EmailNotificationService連携）
├── 時刻フォーマット（format_time_range_string等）
├── 重複チェック（has_shift_overlap?等）
├── エラーハンドリング（handle_shift_error）
└── バリデーション（validate_required_fields等）
```

#### 主要モデル
```
Employee
├── BCrypt (include) - パスワードハッシュ化
├── has_many :verification_codes - 認証コード管理
├── authenticate_login() - ログイン認証（Freee API連携）
├── setup_initial_password() - 初期パスワード設定
├── change_password!() - パスワード変更
├── calculate_wage_for_period() - 期間給与計算
├── calculate_monthly_hours_from_shifts() - 月次勤務時間計算
├── calculate_wage_from_hours() - 時間から給与計算
├── check_forgotten_clock_ins/outs() - 打刻忘れチェック
├── search_by_name() - 従業員検索（Freee API連携）
├── send_verification_code() - 認証コード送信
├── verify_code() - 認証コード検証
└── display_name() - 表示名取得（Freee API連携）

Shift
├── include ShiftBase
├── belongs_to :employee
├── create_with_validation() - バリデーション付き作成
├── update_with_validation() - バリデーション付き更新
├── destroy_with_validation() - バリデーション付き削除
├── has_shift_overlap?() - 重複チェック
├── get_monthly_shifts() - 月次シフト取得（Freee API連携）
├── get_employee_shifts() - 個人シフト取得
├── get_all_employee_shifts() - 全従業員シフト取得
├── check_deletion_eligibility() - 削除可能性チェック
└── get_pending_requests_for_shift() - 承認待ちリクエスト取得

ShiftExchange
├── include ShiftBase
├── belongs_to :shift
├── create_request_for() - 交代申請作成
├── approve_by!() - 承認処理（シフト作成・削除・通知）
├── reject_by!() - 拒否処理
├── cancel_by!() - キャンセル処理
└── send_notifications!() - 通知送信

ShiftAddition
├── include ShiftBase
├── create_request_for() - 追加申請作成
├── approve_by!() - 承認処理（シフト作成・通知）
└── reject_by!() - 拒否処理

ShiftDeletion
├── include ShiftBase
├── belongs_to :shift
├── create_request_for() - 削除申請作成
├── approve_by!() - 承認処理（シフト削除・通知）
└── reject_by!() - 拒否処理

ConversationState
├── LINE Bot状態管理
├── set_conversation_state() - 状態設定
├── get_conversation_state() - 状態取得
└── clear_conversation_state() - 状態クリア

LineMessageLog
├── belongs_to :employee
├── log_inbound_message() - 受信ログ
└── log_outbound_message() - 送信ログ

VerificationCode
├── belongs_to :employee
├── generate_code() - 認証コード生成
├── find_valid_code() - 有効コード検索
└── mark_as_used!() - 使用済みマーク
```

### 3. サービス層（外部API特化）

#### 外部API連携サービス
```
FreeeApiService
├── HTTParty (include) - HTTP通信
├── get_employees() - 従業員一覧取得
├── get_employee_info() - 従業員詳細取得
├── get_time_clocks() - 打刻記録取得
├── create_work_record() - 打刻記録作成
├── get_hourly_wage() - 時給取得
├── get_company_name() - 会社名取得
├── キャッシュ機能（5分間）
├── レート制限（1秒間隔）
└── エラーハンドリング

ClockService
├── FreeeApiService (使用)
├── clock_in() - 出勤打刻
├── clock_out() - 退勤打刻
├── get_clock_status() - 打刻状態取得
├── get_attendance_for_month() - 月次勤怠取得
├── check_forgotten_clock_ins/outs() - 打刻忘れチェック
├── send_clock_in/out_reminder() - リマインダー送信
└── Employee.create_clock_form_data() (委譲)

WageService
├── FreeeApiService (使用)
├── Employee.calculate_wage_for_period() (委譲)
└── 給与情報API連携

EmailNotificationService
├── ActionMailer (使用)
├── シフト関連通知送信
├── 認証コード送信
└── リマインダー送信
```

#### LINE Bot専用サービス
```
LineBaseService (基盤)
├── LINE Bot認証・権限チェック
├── メッセージ処理・コマンド振り分け
├── 状態管理（ConversationState）
├── 従業員検索・認証
├── エラーハンドリング
├── レスポンス生成
└── 各機能サービスへの委譲

LineWebhookService
├── LineBaseService (継承)
├── process_webhook_events() - イベント一括処理
├── process_single_webhook_event() - 個別イベント処理
├── handle_webhook_message() - メッセージイベント処理
├── handle_webhook_postback() - ポストバックイベント処理
├── send_line_reply() - LINE返信送信
├── フォールバック・モッククライアント対応
└── エラーハンドリング

LineShiftExchangeService
├── LineBaseService (継承)
├── handle_shift_exchange_command() - 交代コマンド処理
├── handle_approval_postback() - 承認ポストバック処理
├── handle_shift_date_input() - 日付入力処理
├── handle_shift_selection_input() - シフト選択処理
├── handle_employee_selection_input_exchange() - 従業員選択処理
├── handle_confirmation_input() - 確認入力処理
├── create_shift_exchange_request() - 交代申請作成
├── get_available_employees_for_shift() - 利用可能従業員取得
├── generate_shift_exchange_flex_message() - Flex Message生成
└── ShiftExchange.create_request_for() (委譲)

LineShiftAdditionService
├── LineBaseService (継承)
├── handle_shift_addition_command() - 追加コマンド処理
├── handle_shift_addition_date_input() - 日付入力処理
├── handle_shift_addition_time_input() - 時間入力処理
├── handle_shift_addition_employee_input() - 従業員入力処理
├── create_shift_addition_request() - 追加申請作成
└── ShiftAddition.create_request_for() (委譲)

LineShiftDeletionService
├── LineBaseService (継承)
├── handle_shift_deletion_command() - 削除コマンド処理
├── handle_shift_deletion_date_input() - 日付入力処理
├── handle_shift_deletion_confirmation() - 確認処理
├── create_shift_deletion_request() - 削除申請作成
└── ShiftDeletion.create_request_for() (委譲)

LineShiftDisplayService
├── LineBaseService (継承)
├── handle_shift_command() - シフト確認コマンド処理
├── handle_all_shifts_command() - 全員シフト確認コマンド処理
├── format_employee_shifts_for_line() - LINE用フォーマット
└── Shift.get_employee_shifts() (委譲)
```

## 主要機能の実装フロー

### 1. シフト交代申請（Web）
```
1. ShiftExchangesController#create
   ├── パラメータ検証
   ├── 認証・認可チェック
2. ShiftExchange.create_request_for()
   ├── バリデーション実行（ShiftBase）
   ├── 重複チェック（has_shift_overlap?）
   ├── データベース保存
   └── リクエストID生成
3. ShiftExchange.send_notifications!()
   ├── EmailNotificationService連携
   └── 承認者への通知送信
4. レスポンス返却（JSON/HTML）
```

### 2. シフト交代申請（LINE Bot）
```
1. WebhookController#callback
   ├── LINE署名検証
   ├── イベント解析
2. LineWebhookService.process_webhook_events()
   ├── イベント振り分け
   └── 個別イベント処理
3. LineShiftExchangeService.handle_shift_exchange_command()
   ├── LINE認証チェック
   ├── 状態管理開始
   └── 初期メッセージ送信
4. 対話フロー処理
   ├── 日付入力 → シフト選択 → 従業員選択 → 確認
   ├── ConversationState管理
   └── Flex Message生成
5. ShiftExchange.create_request_for() (委譲)
   ├── バリデーション実行
   ├── データベース保存
   └── 通知送信
6. LINE返信メッセージ送信
```

### 3. シフト交代承認処理
```
1. ShiftApprovalsController#approve
   ├── 認証・認可チェック
   ├── パラメータ準備
2. ShiftExchange.approve_by!()
   ├── 権限チェック（approver_id確認）
   ├── ステータスチェック（pending確認）
   ├── トランザクション開始
   ├── 新シフト作成（承認者用）
   ├── 元シフト削除
   ├── 関連リクエスト拒否
   ├── ステータス更新
   └── 通知送信
3. レスポンス返却
```

### 4. 勤怠打刻
```
1. AttendanceController#clock_in
   ├── 認証チェック
   ├── 現在時刻取得
2. ClockService.clock_in()
   ├── Employee.create_clock_form_data() (委譲)
   ├── フォームデータ作成
3. FreeeApiService.create_work_record()
   ├── HTTP POST送信
   ├── レスポンス確認
   └── 結果返却
4. レスポンス返却（JSON）
```

### 5. 給与計算
```
1. WagesController#index
   ├── 認証チェック
   ├── 期間パラメータ取得
2. Employee.calculate_wage_for_period()
   ├── Shift.where() - シフトデータ取得
   ├── calculate_monthly_hours_from_shifts() (委譲)
   ├── 時間帯別勤務時間計算
   ├── calculate_wage_from_hours() (委譲)
   ├── 時間帯別時給適用
   └── 合計給与計算
3. ビュー表示
```

### 6. LINE Bot認証フロー
```
1. LineBaseService.handle_auth_command()
   ├── 個人チャット確認
   ├── 状態管理開始
2. 従業員名入力処理
   ├── Employee.search_by_name() (Freee API連携)
   ├── 従業員検索・マッチング
   └── 認証コード送信
3. Employee.send_verification_code()
   ├── Freee API従業員情報取得
   ├── VerificationCode生成・保存
   └── AuthMailer送信
4. 認証コード入力処理
   ├── Employee.verify_code()
   ├── コード検証
   └── LINE ID紐付け
5. 認証完了・状態クリア
```

## データフロー

### 1. 認証フロー
```
Web認証:
User Input → AuthController → Employee.authenticate_login() → FreeeApiService → Session → Dashboard

LINE認証:
LINE Message → LineBaseService → Employee.search_by_name() → FreeeApiService → VerificationCode → Email → LINE Response
```

### 2. シフト管理フロー
```
Web:
User Input → ShiftController → ShiftModel.method() → Database → EmailNotificationService → Email → Response

LINE Bot:
LINE Message → LineWebhookService → LineShiftService → ShiftModel.method() → Database → LINE Response
```

### 3. 勤怠打刻フロー
```
Web:
User Input → AttendanceController → ClockService → FreeeApiService → Freee API → Response

LINE Bot:
LINE Message → LineBaseService → ClockService → FreeeApiService → Freee API → LINE Response
```

### 4. 外部API連携フロー
```
Controller → Model.method() → ExternalService → External API
                ↓                    ↓              ↓
            Database            Cache/Sync      Rate Limiting
```

### 5. 通知フロー
```
Model Event → EmailNotificationService → ActionMailer → SMTP → Email
                ↓
            LineMessageLog → Database
```

### 6. 状態管理フロー（LINE Bot）
```
LINE Event → ConversationState → Database → State Retrieval → Business Logic → State Update → Database
```

## 設計の利点

### 1. 保守性
- **単一責任**: 各層の責務が明確に分離
- **変更容易性**: ビジネスロジックがモデルに集約
- **テスト容易性**: モデル中心のテスト設計
- **コードの可読性**: Concernによる共通化で重複排除

### 2. 拡張性
- **新機能追加**: モデルメソッド追加のみで実装可能
- **外部連携追加**: サービス層への追加で対応
- **UI変更**: コントローラ・モデルへの影響なし
- **マルチチャネル対応**: WebとLINE Botの統一されたビジネスロジック

### 3. Rails Way準拠
- **Convention over Configuration**: Rails慣例に完全準拠
- **Fat Model, Skinny Controller**: 理想的な実装
- **DRY原則**: Concernによる共通化
- **ActiveRecord活用**: リレーションとバリデーションの適切な使用

### 4. セキュリティ
- **多層防御**: 認証・認可・入力値検証の多重チェック
- **セッション管理**: タイムアウト・改ざん検知機能
- **権限分離**: オーナー・従業員の適切な権限管理
- **パラメータ改ざん防止**: Strong Parameters + 追加検証

## 注意点

### 1. パフォーマンス
- **N+1クエリ**: includesによる最適化実装済み
- **バリデーション**: 必要最小限に限定
- **キャッシュ**: 外部API結果のキャッシュ実装（5分間）
- **レート制限**: Freee API呼び出し制限（1秒間隔）

### 2. 外部依存
- **API障害対応**: タイムアウト・リトライ実装
- **データ同期**: 非同期処理で実装
- **通知失敗**: ログ記録・再送機能実装
- **フォールバック**: LINE Botのフォールバック・モッククライアント対応

### 3. 状態管理
- **LINE Bot状態**: ConversationStateによる対話状態管理
- **セッション管理**: タイムアウト・改ざん検知
- **トランザクション**: データ整合性の保証

### 4. エラーハンドリング
- **統一エラー処理**: Concernによる共通化
- **ログ記録**: 詳細なエラーログとデバッグ情報
- **ユーザーフレンドリー**: 適切なエラーメッセージ表示
- **復旧機能**: エラー時の適切な状態復元
