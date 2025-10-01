# アプリケーション機能とコンポーネント依存関係

## 概要

勤怠管理システムの各機能がどのコンポーネントによって実現され、どのような依存関係を持っているかを説明します。

## 主要機能の実装フロー

### 1. シフト交代機能

#### Webからのシフト交代
```
ShiftExchangesController → ShiftExchangeService → ShiftExchange(DB) → NotificationService
```

**詳細フロー:**
1. **`ShiftExchangesController`** がリクエストを受け取り
2. **`InputValidation`** でバリデーション
3. **`ShiftExchangeService.create_exchange_request`** で共通処理
4. **`ShiftExchange`** モデルでDBに登録
5. **`NotificationService`** で通知送信

#### LINE Botからのシフト交代
```
WebhookController → LineBotService → LineShiftManagementService → ShiftExchangeService → ShiftExchange(DB)
```

**詳細フロー:**
1. **`WebhookController`** がLINEイベントを受け取り
2. **`LineBotService`** がコマンドを振り分け
3. **`LineShiftManagementService`** が会話状態管理
4. **`LineUtilityService`** が状態管理を委譲
5. **`ShiftExchangeService`** で共通処理
6. **`ShiftExchange`** モデルでDBに登録

### 2. シフト追加機能

#### Webからのシフト追加
```
ShiftAdditionsController → ShiftAdditionService → ShiftAddition(DB) → NotificationService
```

#### LINE Botからのシフト追加
```
WebhookController → LineBotService → LineShiftManagementService → ShiftAdditionService → ShiftAddition(DB)
```

### 3. シフト削除（欠勤申請）機能

#### Webからのシフト削除
```
ShiftDeletionsController → ShiftDeletionService → ShiftDeletion(DB) → NotificationService
```

#### LINE Botからのシフト削除
```
WebhookController → LineBotService → LineShiftManagementService → ShiftDeletionService → ShiftDeletion(DB)
```

### 4. 認証機能

#### Webからの認証
```
AuthController → AuthService → Employee(DB) + FreeeApiService
AccessControlController → AuthService → EmailVerificationCode(DB)
```

#### LINE Botからの認証
```
WebhookController → LineBotService → LineUtilityService → AuthService → Employee(DB) + FreeeApiService
```

### 5. シフト確認機能

#### Webからのシフト確認
```
ShiftsController → ShiftDisplayService → Shift(DB) + Employee(DB)
```

#### LINE Botからのシフト確認
```
WebhookController → LineBotService → LineShiftManagementService → ShiftDisplayService → Shift(DB)
```

### 6. 依頼確認機能

#### LINE Botからの依頼確認
```
WebhookController → LineBotService → LineRequestService → ShiftExchange/ShiftAddition/ShiftDeletion(DB)
```

### 7. 給与確認機能

#### Webからの給与確認
```
WagesController → WageService → Shift(DB) + FreeeApiService
```

## コンポーネント依存関係図

```
┌─────────────────────────────────────────────────────────────────┐
│                        Web Interface                            │
├─────────────────────────────────────────────────────────────────┤
│ ShiftExchangesController → ShiftExchangeService                │
│ ShiftAdditionsController → ShiftAdditionService                │
│ ShiftDeletionsController → ShiftDeletionService                │
│ ShiftsController → ShiftDisplayService                         │
│ WagesController → WageService                                  │
│ AuthController → AuthService                                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LINE Bot Interface                        │
├─────────────────────────────────────────────────────────────────┤
│ WebhookController → LineBotService (ファサード)                │
│                     ├── LineShiftManagementService             │
│                     ├── LineRequestService                     │
│                     ├── LineUtilityService                     │
│                     ├── LineMessageService                     │
│                     └── LineValidationService                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Business Logic Layer                      │
├─────────────────────────────────────────────────────────────────┤
│ ShiftExchangeService ←→ ShiftAdditionService                   │
│ ShiftDeletionService ←→ ShiftDisplayService                    │
│ AuthService ←→ NotificationService                             │
│ WageService ←→ FreeeApiService                                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Data Layer                              │
├─────────────────────────────────────────────────────────────────┤
│ Shift ←→ ShiftExchange ←→ ShiftAddition ←→ ShiftDeletion       │
│ Employee ←→ ConversationState ←→ VerificationCode              │
│ LineMessageLog ←→ EmailVerificationCode                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      External Services                         │
├─────────────────────────────────────────────────────────────────┤
│ FreeeApiService → Freee API                                    │
│ NotificationService → Mail + LINE Bot                          │
└─────────────────────────────────────────────────────────────────┘
```

## 共通パターン

### 1. ファサードパターン
- **`LineBotService`**: LINE Bot機能の統合管理
- **`ApplicationController`**: Web機能の共通処理

### 2. サービス層の責任分離
- **`*Service`**: ビジネスロジックの実装
- **`Line*Service`**: LINE Bot固有の処理
- **`*Controller`**: Web固有の処理

### 3. 共通処理の委譲
- **`ShiftExchangeService`**: Web・LINE共通のシフト交代処理
- **`AuthService`**: Web・LINE共通の認証処理
- **`NotificationService`**: 通知処理の統合

### 4. 状態管理
- **`ConversationState`**: LINE Bot会話状態
- **`Session`**: Web認証状態

## 依存関係の特徴

### 適切な分離
- Web・LINE Botのインターフェースが独立
- ビジネスロジックが共通サービスに集約
- データアクセスがモデル層に分離

### 改善が必要な箇所
- **重複コード**: FreeeApiServiceインスタンス化（14箇所）
- **マジックナンバー**: 認証コード長、タイムアウト値
- **巨大なサービス**: LineValidationService（467行）

## 設計原則

### 1. インターフェース分離
Web・LINE Botそれぞれのインターフェースが独立しており、同じビジネスロジックを共有

### 2. 責任分離
- **Controller層**: リクエスト処理・レスポンス生成
- **Service層**: ビジネスロジック
- **Model層**: データアクセス

### 3. 共通化
Web・LINE Bot両方から同じビジネスロジックを利用できる設計

### 4. 拡張性
新機能追加時は新しいServiceを作成し、既存のファサードに追加するだけで対応可能

## 今後の改善点

### Phase 16-2での改善予定
1. **FreeeApiServiceインスタンス化の共通化**
2. **マジックナンバー・文字列の外部化**
3. **従業員名取得ロジックの統合**
4. **バリデーションロジックの統合**

この構造により、Web・LINE Bot両方のインターフェースから同じビジネスロジックを利用できる設計になっています。
