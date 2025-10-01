# サービス間依存関係マップ

## Controller層の依存関係

```
ApplicationController
├── ErrorHandler (include)
├── Authentication (include)
├── SessionManagement (include)
└── Security (include)

AuthController
├── ApplicationController (継承)
├── InputValidation (include)
└── ErrorHandler (include)

DashboardController
├── ApplicationController (継承)
└── AuthorizationCheck (include)

ShiftController
├── ApplicationController (継承)
└── AuthorizationCheck (include)

WebhookController
├── ApplicationController (継承)
└── LineBotService (使用)
```

## Service層の依存関係

### LINE Bot関連サービス

```
LineBotService (ファサード)
├── LineShiftManagementService
├── LineMessageService
├── LineValidationService
├── LineUtilityService
├── LineRequestService
└── NotificationService

LineShiftManagementService
├── LineMessageService
├── LineValidationService
├── LineUtilityService
└── NotificationService

LineRequestService
├── LineMessageService
└── LineUtilityService

LineMessageService
└── (外部依存なし)

LineValidationService
└── (外部依存なし)

LineUtilityService
└── FreeeApiService
```

### 共通サービス

```
NotificationService
├── MailService
└── LineBotService

FreeeApiService
└── (外部API依存)

AuthService
├── Employee (モデル)
└── FreeeApiService

ShiftExchangeService
├── ShiftExchange (モデル)
├── Shift (モデル)
├── Employee (モデル)
└── NotificationService

ShiftAdditionService
├── ShiftAddition (モデル)
├── Shift (モデル)
├── Employee (モデル)
└── NotificationService

ShiftDeletionService
├── ShiftDeletion (モデル)
├── Shift (モデル)
├── Employee (モデル)
└── NotificationService
```

## 依存関係の特徴

### 1. ファサードパターン
- `LineBotService`が複数のサービスを統合
- クライアントは`LineBotService`のみとやり取り

### 2. 単方向依存
- 高レベルサービスは低レベルサービスに依存
- 循環依存は存在しない

### 3. 責任分離
- 各サービスは明確な責任を持つ
- 機能の変更は該当サービスのみに影響

### 4. 共通サービス
- `NotificationService`は複数のサービスから使用
- `FreeeApiService`は外部APIアクセスの共通化

## 依存関係の管理

### 新規サービス追加時
1. 依存関係を最小限に抑える
2. 循環依存を避ける
3. インターフェースを明確にする

### 既存サービス修正時
1. 依存関係の影響範囲を確認
2. 下位サービスから上位サービスへ影響を伝播
3. テストの更新が必要な範囲を特定

## 循環依存の回避

### 現在の設計
- すべての依存関係が単方向
- 循環依存は存在しない

### 注意点
- `NotificationService`と`LineBotService`の相互依存を避ける
- サービス間の直接的な相互参照を禁止
- イベント駆動アーキテクチャの検討

## 拡張性の考慮

### 新機能追加
1. 新しいサービスを作成
2. 既存サービスとの依存関係を最小化
3. ファサードパターンで統合

### パフォーマンス最適化
1. 依存関係の深さを最小化
2. 遅延ロードの活用
3. キャッシュ戦略の実装
