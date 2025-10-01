# アーキテクチャ設計書

## 概要
勤怠管理システムのアーキテクチャ設計と責任分離について説明します。

## Controller層の責任分離

### ApplicationController
- **責任**: 基底コントローラーとしての共通機能提供
- **Concern**: ErrorHandler, Authentication, SessionManagement, Security
- **主要機能**:
  - エラーハンドリングの統一
  - 共通メソッドの提供

### Authentication Concern
- **責任**: 認証・認可機能の提供
- **主要機能**:
  - メールアドレス認証 (`require_email_authentication`)
  - ログイン認証 (`require_login`)
  - 従業員情報取得 (`current_employee`, `current_employee_id`)
  - 権限チェック (`owner?`)
  - 各種認可チェック機能（シフト操作、リクエスト承認等）
  - セキュリティチェック（パラメータ改ざん、権限昇格攻撃等）
- **before_action**: `require_email_authentication`, `require_login`

### SessionManagement Concern
- **責任**: セッション管理機能の提供
- **主要機能**:
  - セッションタイムアウト管理 (`session_expired?`)
  - セッションクリア (`clear_session`)
  - ヘッダー変数設定 (`set_header_variables`)
  - 従業員名取得 (`get_employee_name`)
- **定数**: `SESSION_TIMEOUT_HOURS = 24`

### Security Concern
- **責任**: セキュリティ機能の提供
- **主要機能**:
  - セキュリティヘッダー設定 (`set_security_headers`)
  - FreeeApiServiceの共通インスタンス化 (`freee_api_service`)
- **定数**: `SECURITY_HEADERS`
- **before_action**: `set_security_headers`

## Service層の責任分離

### LineBotService (ファサード)
- **責任**: LINE Bot機能の統合管理
- **主要機能**:
  - メッセージ処理のルーティング
  - Postbackイベントの処理
  - コマンドの振り分け
- **依存サービス**:
  - `LineShiftManagementService`: シフト管理
  - `LineMessageService`: メッセージ生成
  - `LineValidationService`: バリデーション
  - `LineUtilityService`: ユーティリティ
  - `LineRequestService`: リクエスト管理
  - `NotificationService`: 通知

### LineRequestService
- **責任**: リクエスト確認機能の提供
- **主要機能**:
  - 依頼確認コマンドの処理
  - 承認待ちリクエストの取得
  - データベースアクセスの抽象化

### LineShiftManagementService
- **責任**: シフト管理機能の提供
- **主要機能**:
  - シフト確認
  - シフト交代・追加・削除の処理

### LineMessageService
- **責任**: メッセージ生成機能の提供
- **主要機能**:
  - Flex Message生成
  - ヘルプメッセージ生成
  - 各種通知メッセージ生成

### LineUtilityService
- **責任**: ユーティリティ機能の提供
- **主要機能**:
  - イベント処理
  - 認証・従業員管理
  - 会話状態管理

### LineValidationService
- **責任**: バリデーション機能の提供
- **主要機能**:
  - 入力値検証
  - セキュリティチェック

## 設計原則

### 単一責任原則 (SRP)
- 各Concern・Serviceは単一の責任を持つ
- 機能の変更は該当するConcern・Serviceのみに影響

### 依存関係逆転原則 (DIP)
- 高レベルモジュールは低レベルモジュールに依存しない
- 抽象化されたインターフェースに依存

### ファサードパターン
- LineBotServiceが複数のサービスを統合
- クライアントはLineBotServiceのみとやり取り

### DRY原則
- 共通処理はConcern・Serviceに集約
- 重複コードの排除

### 認証・認可の統合
- AuthenticationとAuthorizationCheckを統合
- 認証と認可の密接な関係を反映
- コードの重複削除と保守性向上

## 依存関係図

```
ApplicationController
├── Authentication
├── SessionManagement
├── Security
└── ErrorHandler

LineBotService (ファサード)
├── LineShiftManagementService
├── LineMessageService
├── LineValidationService
├── LineUtilityService
├── LineRequestService
└── NotificationService
```

## 拡張性

### 新機能追加時
1. 新しいServiceを作成
2. LineBotServiceに追加
3. 必要に応じてConcernを作成

### 既存機能修正時
1. 該当するConcern・Serviceを特定
2. 責任範囲内でのみ修正
3. 他への影響を最小化
