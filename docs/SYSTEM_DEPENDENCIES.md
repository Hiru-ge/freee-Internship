# システム依存関係とアーキテクチャ

## 概要

勤怠管理システムの現在のアーキテクチャと各コンポーネント間の依存関係を説明します。
本システムは**モデル中心設計（Fat Model, Skinny Controller）**を採用しています。

## アーキテクチャ概要

### 設計原則
- **Fat Model, Skinny Controller**: ビジネスロジックはモデル層に集約
- **サービス層の特化**: 外部API連携のみに限定
- **薄いコントローラ**: HTTP処理とレスポンス制御のみ
- **共通処理のConcern化**: 重複排除とコードの再利用

### 層構造
```
┌─────────────────────────────────────────────────────────────┐
│                    プレゼンテーション層                      │
│  Controllers (薄層) + Views + JavaScript                   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      ビジネスロジック層                      │
│  Models (Fat) + Concerns + Validations                     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      外部連携・通知層                        │
│  Services (外部API特化) + Mailers                           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        データ層                             │
│  Database (SQLite3) + ActiveRecord                         │
└─────────────────────────────────────────────────────────────┘
```

## コンポーネント依存関係

### 1. コントローラ層（薄層設計）

#### 基底コントローラ
```
ApplicationController
├── Authentication (include) - 認証・認可
├── InputValidation (include) - 入力値検証
├── ErrorHandler (include) - エラーハンドリング
└── ServiceResponseHandler (include) - サービスレスポンス処理
```

#### 機能別コントローラ
```
AuthController
├── ApplicationController (継承)
└── Employee.authenticate_login() - 認証処理

AttendanceController
├── ApplicationController (継承)
├── Employee.clock_in() - 出勤処理
├── Employee.clock_out() - 退勤処理
└── ClockService - 外部API連携

ShiftDisplayController
├── ApplicationController (継承)
├── Shift.for_employee() - シフト取得
├── Shift.for_month() - 月次シフト
└── WageService - 給与API連携

ShiftExchangesController
├── ApplicationController (継承)
├── ShiftExchange.create_request_for() - 交代申請作成
├── ShiftExchange.approve_by!() - 承認処理
└── ShiftExchange.reject_by!() - 拒否処理

ShiftAdditionsController
├── ApplicationController (継承)
├── ShiftAddition.create_request_for() - 追加申請作成
├── ShiftAddition.approve_by!() - 承認処理
└── ShiftAddition.reject_by!() - 拒否処理

ShiftDeletionsController
├── ApplicationController (継承)
├── ShiftDeletion.create_request_for() - 削除申請作成
├── ShiftDeletion.approve_by!() - 承認処理
└── ShiftDeletion.reject_by!() - 拒否処理

ShiftApprovalsController
├── ApplicationController (継承)
├── ShiftExchange.pending - 承認待ち取得
├── ShiftAddition.pending - 承認待ち取得
└── ShiftDeletion.pending - 承認待ち取得

WagesController
├── ApplicationController (継承)
├── Employee.calculate_monthly_wage() - 給与計算
└── WageService - 外部API連携

WebhookController
├── ApplicationController (継承)
└── LINE Bot Services - LINE連携
```

### 2. モデル層（Fat Model設計）

#### 基底モデルとConcern
```
ApplicationRecord
└── ActiveRecord::Base (継承)

ShiftBase (Concern)
├── 共通バリデーション
├── ステータス管理
├── 通知処理
├── 時刻フォーマット
└── 重複チェック
```

#### 主要モデル
```
Employee
├── has_secure_password - パスワード管理
├── authenticate_login() - 認証処理
├── calculate_monthly_wage() - 給与計算
├── clock_in() / clock_out() - 打刻処理
└── search_by_name() - 従業員検索

Shift
├── belongs_to :employee
├── create_with_validation() - バリデーション付き作成
├── update_with_validation() - バリデーション付き更新
├── destroy_with_validation() - バリデーション付き削除
└── has_shift_overlap?() - 重複チェック

ShiftExchange
├── include ShiftBase
├── belongs_to :shift
├── create_request_for() - 交代申請作成
├── approve_by!() - 承認処理
├── reject_by!() - 拒否処理
└── cancel_by!() - キャンセル処理

ShiftAddition
├── include ShiftBase
├── create_request_for() - 追加申請作成
├── approve_by!() - 承認処理
└── reject_by!() - 拒否処理

ShiftDeletion
├── include ShiftBase
├── belongs_to :shift
├── create_request_for() - 削除申請作成
├── approve_by!() - 承認処理
└── reject_by!() - 拒否処理

LineMessageLog
├── belongs_to :employee
├── log_inbound_message() - 受信ログ
└── log_outbound_message() - 送信ログ
```

### 3. サービス層（外部API特化）

#### 外部API連携サービス
```
FreeeApiService
├── 従業員情報取得
└── データ同期

ClockService
├── FreeeApiService (使用)
└── 外部打刻API連携

WageService
├── FreeeApiService (使用)
└── 給与情報API連携

EmailNotificationService
├── ActionMailer (使用)
└── メール通知送信
```

#### LINE Bot専用サービス
```
LineBotService (基盤)
├── メッセージ処理
├── バリデーション
└── 状態管理

LineShiftExchangeService
├── LineBotService (使用)
└── ShiftExchange (使用)

LineShiftAdditionService
├── LineBotService (使用)
└── ShiftAddition (使用)

LineShiftDeletionService
├── LineBotService (使用)
└── ShiftDeletion (使用)

LineShiftDisplayService
├── LineBotService (使用)
└── Shift (使用)

LineWebhookService
├── 各LINE*Service (使用)
└── イベント振り分け
```

## 主要機能の実装フロー

### 1. シフト交代申請（Web）
```
1. ShiftExchangesController#create
2. ShiftExchange.create_request_for()
   ├── バリデーション実行
   ├── 重複チェック
   ├── データベース保存
   └── 通知送信
3. レスポンス返却
```

### 2. シフト交代申請（LINE Bot）
```
1. WebhookController#callback
2. LineWebhookService.process_event()
3. LineShiftExchangeService.handle_exchange()
4. ShiftExchange.create_request_for()
   ├── バリデーション実行
   ├── 重複チェック
   ├── データベース保存
   └── 通知送信
5. LINE返信メッセージ送信
```

### 3. 勤怠打刻
```
1. AttendanceController#clock_in
2. Employee.clock_in()
   ├── バリデーション実行
   ├── データベース更新
   └── ClockService.sync_to_external() - 外部API連携
3. レスポンス返却
```

### 4. 給与計算
```
1. WagesController#index
2. Employee.calculate_monthly_wage()
   ├── シフトデータ集計
   ├── 給与計算
   └── WageService.get_external_data() - 外部API連携
3. ビュー表示
```

## データフロー

### 1. 認証フロー
```
User Input → AuthController → Employee.authenticate_login() → Session → Dashboard
```

### 2. シフト管理フロー
```
User Input → ShiftController → ShiftModel.method() → Database → Response
                                    ↓
                            EmailNotificationService → Email
```

### 3. LINE Bot フロー
```
LINE Event → WebhookController → LineService → ShiftModel → Database
                                      ↓              ↓
                                LINE Response    Notification
```

### 4. 外部API連携フロー
```
Controller → Model.method() → ExternalService → External API
                ↓                    ↓
            Database            Cache/Sync
```

## 設計の利点

### 1. 保守性
- **単一責任**: 各層の責務が明確
- **変更容易性**: ビジネスロジックがモデルに集約
- **テスト容易性**: モデル中心のテスト設計

### 2. 拡張性
- **新機能追加**: モデルメソッド追加のみで実装可能
- **外部連携追加**: サービス層への追加で対応
- **UI変更**: コントローラ・モデルへの影響なし

### 3. Rails Way準拠
- **Convention over Configuration**: Rails慣例に完全準拠
- **Fat Model, Skinny Controller**: 理想的な実装
- **DRY原則**: Concernによる共通化

## 注意点

### 1. パフォーマンス
- **N+1クエリ**: includesによる最適化実装済み
- **バリデーション**: 必要最小限に限定
- **キャッシュ**: 外部API結果のキャッシュ実装

### 2. セキュリティ
- **Strong Parameters**: 全コントローラで実装
- **認証・認可**: Concernで共通化
- **入力値検証**: モデルバリデーションで実装

### 3. 外部依存
- **API障害対応**: タイムアウト・リトライ実装
- **データ同期**: 非同期処理で実装
- **通知失敗**: ログ記録・再送機能実装
