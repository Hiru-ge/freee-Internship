# システム仕様書

勤怠管理システムの包括的なシステム仕様書です。

## 概要

勤怠管理システムは、LINE BotとWebアプリケーションを組み合わせた勤怠管理ツールです。従業員のシフト管理、交代申請、欠勤申請などを効率的に行うことができます。

## システムアーキテクチャ

### 全体構成

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LINE Bot      │    │  Web App        │    │  Freee API      │
│                 │    │                 │    │                 │
│  - 認証         │    │  - シフト管理   │    │  - 従業員情報   │
│  - シフト確認   │    │  - 申請管理     │    │  - データ同期   │
│  - 申請処理     │    │  - 管理者機能   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Rails API     │
                    │                 │
                    │  - 認証・認可   │
                    │  - ビジネスロジック │
                    │  - データ管理   │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   SQLite        │
                    │                 │
                    │  - データ保存   │
                    │  - トランザクション │
                    └─────────────────┘
```

### 技術スタック

- **バックエンド**: Ruby on Rails 8.0.2
- **データベース**: SQLite
- **フロントエンド**: HTML, CSS, JavaScript
- **Bot**: LINE Messaging API
- **外部API**: Freee API
- **デプロイ**: Fly.io
- **メール**: Gmail SMTP

## データベース設計

### 基本情報
- **データベース**: SQLite
- **Rails環境**: production, development, test
- **文字エンコーディング**: UTF-8
- **タイムゾーン**: Asia/Tokyo

### テーブル構成

#### employees テーブル
```sql
CREATE TABLE employees (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  role VARCHAR(50) NOT NULL DEFAULT 'employee',
  freee_id INTEGER,
  line_user_id VARCHAR(255),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

#### shifts テーブル
```sql
CREATE TABLE shifts (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES employees(id),
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'confirmed',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

#### shift_requests テーブル
```sql
CREATE TABLE shift_requests (
  id BIGSERIAL PRIMARY KEY,
  shift_id BIGINT NOT NULL REFERENCES shifts(id),
  requester_id BIGINT NOT NULL REFERENCES employees(id),
  target_employee_id BIGINT NOT NULL REFERENCES employees(id),
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  approved_at TIMESTAMP,
  rejected_at TIMESTAMP
);
```

#### absence_requests テーブル
```sql
CREATE TABLE absence_requests (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT NOT NULL REFERENCES employees(id),
  shift_id BIGINT NOT NULL REFERENCES shifts(id),
  reason TEXT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  approved_at TIMESTAMP,
  rejected_at TIMESTAMP,
  rejection_reason TEXT
);
```

#### conversation_states テーブル
```sql
CREATE TABLE conversation_states (
  id BIGSERIAL PRIMARY KEY,
  line_user_id VARCHAR(255) NOT NULL,
  state VARCHAR(100) NOT NULL,
  context JSONB,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### インデックス設計

```sql
-- パフォーマンス向上のためのインデックス
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_line_user_id ON employees(line_user_id);
CREATE INDEX idx_shifts_employee_id ON shifts(employee_id);
CREATE INDEX idx_shifts_date ON shifts(date);
CREATE INDEX idx_shift_requests_requester_id ON shift_requests(requester_id);
CREATE INDEX idx_shift_requests_target_employee_id ON shift_requests(target_employee_id);
CREATE INDEX idx_shift_requests_status ON shift_requests(status);
CREATE INDEX idx_absence_requests_employee_id ON absence_requests(employee_id);
CREATE INDEX idx_absence_requests_status ON absence_requests(status);
CREATE INDEX idx_conversation_states_line_user_id ON conversation_states(line_user_id);
```

## 認証・認可

### 認証方式

#### メール認証
- メールアドレス + 認証コードによる認証
- 認証コードは6桁の数字
- 有効期限: 10分

#### セッション認証
- ログイン後にセッションCookieで認証状態を維持
- 未認証の場合はログインページにリダイレクト
- CSRFトークンによる保護

### 権限管理

#### ロール定義
- **owner**: 全機能にアクセス可能
- **employee**: 自分のシフト確認、交代申請が可能

#### アクセス制御
```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :check_permissions

  private

  def authenticate_user!
    redirect_to login_path unless current_user
  end

  def check_permissions
    case action_name
    when 'create', 'update', 'destroy'
      redirect_to root_path unless current_user.owner?
    end
  end
end
```

### セキュリティ対策

#### LINE Webhook署名検証
```ruby
def verify_line_signature(body, signature)
  hash = OpenSSL::HMAC.digest(
    OpenSSL::Digest.new('sha256'),
    ENV['LINE_CHANNEL_SECRET'],
    body
  )

  expected_signature = Base64.strict_encode64(hash)
  signature == expected_signature
end
```

#### CSRF保護
- Rails標準のCSRF保護機能を使用
- すべてのPOST/PUT/DELETEリクエストでCSRFトークン必須

#### データ保護
- 個人情報の暗号化
- ログからの機密情報除外
- HTTPS通信の強制

## サービス層アーキテクチャ

### 設計原則
- **単一責任原則 (SRP)**: 各サービスは一つの責任を持つ
- **依存性逆転原則 (DIP)**: 抽象に依存し、具象に依存しない
- **開放閉鎖原則 (OCP)**: 拡張に開放、修正に閉鎖
- **DRY原則**: 重複を避ける
- **SOLID原則**: オブジェクト指向設計の原則に従う

### コアサービス

#### AuthService
認証・認可を担当するサービス

```ruby
class AuthService
  def self.authenticate_user(email, code)
    # 認証ロジック
  end

  def self.generate_auth_code(email)
    # 認証コード生成
  end

  def self.verify_auth_code(email, code)
    # 認証コード検証
  end
end
```

#### ShiftManagementService
シフト管理を担当するサービス

```ruby
class ShiftManagementService
  def self.create_shift(employee_id, date, start_time, end_time)
    # シフト作成ロジック
  end

  def self.update_shift(shift_id, params)
    # シフト更新ロジック
  end

  def self.delete_shift(shift_id)
    # シフト削除ロジック
  end
end
```

#### ShiftRequestService
シフト交代申請を担当するサービス

```ruby
class ShiftRequestService
  def self.create_request(shift_id, target_employee_id)
    # 申請作成ロジック
  end

  def self.approve_request(request_id)
    # 申請承認ロジック
  end

  def self.reject_request(request_id, reason)
    # 申請拒否ロジック
  end
end
```

#### AbsenceRequestService
欠勤申請を担当するサービス

```ruby
class AbsenceRequestService
  def self.create_request(employee_id, shift_id, reason)
    # 欠勤申請作成ロジック
  end

  def self.approve_request(request_id)
    # 欠勤申請承認ロジック
  end

  def self.reject_request(request_id, reason)
    # 欠勤申請拒否ロジック
  end
end
```

#### NotificationService
通知を担当するサービス

```ruby
class NotificationService
  def self.send_email_notification(recipient, subject, body)
    # メール通知送信
  end

  def self.send_line_notification(user_id, message)
    # LINE通知送信（現在無効化）
  end
end
```

## LINE Bot仕様

### 基本機能

#### 認証機能
- 個人チャットでのみ認証可能
- 従業員名による認証
- 認証コードによる二段階認証

#### シフト管理機能
- 自分のシフト確認
- 全従業員のシフト確認
- シフト交代依頼
- シフト追加依頼（オーナーのみ）
- 欠勤申請

#### 申請管理機能
- 承認待ち依頼の確認
- 申請の承認・拒否

### 会話状態管理

#### 状態定義
```ruby
class ConversationState
  AUTHENTICATION = 'authentication'
  SHIFT_CONFIRMATION = 'shift_confirmation'
  SHIFT_REQUEST = 'shift_request'
  ABSENCE_REQUEST = 'absence_request'
  REQUEST_CONFIRMATION = 'request_confirmation'
end
```

#### 状態遷移
```
初期状態 → 認証 → メイン機能
    ↓
認証失敗 → 再認証
    ↓
メイン機能 → 各機能 → 完了
```

### Flex Message仕様

#### シフト選択画面
```json
{
  "type": "flex",
  "altText": "シフト選択",
  "contents": {
    "type": "bubble",
    "body": {
      "type": "box",
      "layout": "vertical",
      "contents": [
        {
          "type": "text",
          "text": "シフトを選択してください",
          "weight": "bold",
          "size": "md"
        }
      ]
    },
    "footer": {
      "type": "box",
      "layout": "vertical",
      "contents": [
        {
          "type": "button",
          "action": {
            "type": "postback",
            "label": "選択",
            "data": "shift_id=1"
          }
        }
      ]
    }
  }
}
```

## Webアプリケーション仕様

### 画面構成

#### ログインページ
- メールアドレス入力
- 認証コード入力
- エラーメッセージ表示

#### ダッシュボード
- シフト表表示
- 申請一覧表示
- ナビゲーションメニュー

#### シフト管理画面
- シフト一覧表示
- シフト作成・編集・削除
- 週単位での表示

#### 申請管理画面
- 交代申請一覧
- 欠勤申請一覧
- 承認・拒否処理

### レスポンシブデザイン
- モバイルファーストデザイン
- タブレット・デスクトップ対応
- ブラウザ互換性確保

## Freee API統合

### 基本情報
- **API**: Freee API v1
- **認証**: OAuth 2.0
- **エンドポイント**: https://api.freee.co.jp/hr/api/v1/
- **レート制限**: 1000リクエスト/時間

### 従業員情報同期

#### 同期処理
```ruby
class FreeeEmployeeSyncService
  def self.sync_employees
    employees = fetch_freee_employees

    employees.each do |freee_employee|
      employee = Employee.find_or_initialize_by(freee_id: freee_employee['id'])
      employee.update!(
        name: freee_employee['display_name'],
        email: freee_employee['email'],
        employee_number: freee_employee['employee_number']
      )
    end
  end
end
```

### エラーハンドリング

#### Freee API エラー
```ruby
class FreeeApiError < StandardError
  attr_reader :status, :message

  def initialize(status, message)
    @status = status
    @message = message
    super("Freee API Error: #{status} - #{message}")
  end
end
```

## パフォーマンス仕様

### レスポンス時間
- **API レスポンス**: 500ms以内
- **ページ表示**: 2秒以内
- **データベースクエリ**: 100ms以内

### スケーラビリティ
- **同時接続数**: 100ユーザー
- **データベース接続**: 20接続
- **メモリ使用量**: 512MB以内

### 可用性
- **稼働率**: 99.9%以上
- **ダウンタイム**: 月4時間以内
- **復旧時間**: 1時間以内

## セキュリティ仕様

### データ保護
- **暗号化**: 転送時・保存時暗号化
- **アクセス制御**: ロールベース
- **監査ログ**: 全操作の記録

### 脆弱性対策
- **SQLインジェクション**: ActiveRecord使用
- **XSS**: 入力値のエスケープ
- **CSRF**: トークンによる保護

### 監視・ログ
- **アクセスログ**: 全リクエストの記録
- **エラーログ**: エラー詳細の記録
- **セキュリティログ**: 認証・認可の記録

## 運用仕様

### バックアップ
- **データベース**: 日次自動バックアップ
- **設定ファイル**: Gitリポジトリで管理
- **復旧時間**: 1時間以内

### 監視
- **ヘルスチェック**: `/health` エンドポイント
- **メトリクス**: CPU、メモリ、レスポンス時間
- **アラート**: 閾値超過時の通知

### メンテナンス
- **定期メンテナンス**: 月次
- **緊急メンテナンス**: 必要時
- **通知**: 事前通知（24時間前）

## テスト仕様

### テスト戦略
- **単体テスト**: 90%以上のカバレッジ
- **統合テスト**: 主要機能の動作確認
- **システムテスト**: エンドツーエンドテスト

### テスト環境
- **開発環境**: ローカル開発用
- **テスト環境**: 自動テスト用
- **ステージング環境**: 本番前テスト用

### 品質保証
- **コードレビュー**: 全コードのレビュー
- **自動テスト**: CI/CDパイプライン
- **パフォーマンステスト**: 負荷テスト
