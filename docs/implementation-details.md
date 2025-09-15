# 実装詳細ドキュメント

## 概要

勤怠管理システムの各機能の実装詳細について説明します。認証システム、メールシステム、パフォーマンス最適化、セキュリティ強化などの実装内容をまとめています。

## 目次

1. [認証システム](#認証システム)
2. [メールシステム](#メールシステム)
3. [パフォーマンス最適化](#パフォーマンス最適化)
4. [セキュリティ強化](#セキュリティ強化)
5. [エラーハンドリング](#エラーハンドリング)
6. [UI/UX改善](#uiux改善)

---

## 認証システム

### 概要

勤怠管理システムの認証システムは、GAS時代の機能を完全に再現し、freee APIとの連携により実データベースでの認証を実現しています。

### 実装完了日

**2025年9月9日** - Phase 2-1: 認証システム移行完了

### アーキテクチャ

#### データベース設計

**employees テーブル**
```sql
CREATE TABLE employees (
  id BIGSERIAL PRIMARY KEY,
  employee_id VARCHAR NOT NULL UNIQUE,
  password_hash VARCHAR,
  role VARCHAR NOT NULL CHECK (role IN ('employee', 'owner')),
  last_login_at TIMESTAMP,
  password_updated_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

**verification_codes テーブル**
```sql
CREATE TABLE verification_codes (
  id BIGSERIAL PRIMARY KEY,
  employee_id VARCHAR NOT NULL,
  code VARCHAR NOT NULL,
  purpose VARCHAR NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

#### 主要コンポーネント

1. **AuthController**: 認証処理の制御
2. **Employee Model**: 従業員データの管理
3. **VerificationCode Model**: 認証コードの管理
4. **FreeeApiService**: freee APIとの連携
5. **PasswordService**: パスワード管理

### 認証フロー

1. **ログイン**: 従業員ID + パスワード認証
2. **初回ログイン**: パスワード設定画面への誘導
3. **パスワードリセット**: メール認証コードによるリセット
4. **セッション管理**: セッションタイムアウト機能

### セキュリティ機能

- パスワードハッシュ化（BCrypt）
- セッションタイムアウト（30分）
- CSRF保護
- 認証コードの有効期限管理

---

## メールシステム

### 概要

勤怠管理システムのメール機能は、GAS時代の機能を完全に再現し、シフト管理と認証に関する自動メール送信を提供します。

### アーキテクチャ

#### 主要コンポーネント

1. **Mailer Classes**
   - `AuthMailer`: 認証関連メール
   - `ShiftMailer`: シフト関連メール
   - `ClockReminderMailer`: 打刻リマインダーメール

2. **Service Classes**
   - `EmailNotificationService`: メール送信の一元管理
   - `ClockReminderService`: 打刻リマインダー処理
   - `FreeeApiService`: 従業員情報取得

3. **Background Jobs**
   - `ClockReminderJob`: 打刻リマインダーのバックグラウンド処理

### メール送信機能

#### 1. 認証関連メール

**パスワードリセット認証コード**
- 送信タイミング: パスワードリセット申請時
- 送信先: 申請者のメールアドレス
- 内容: 6桁の認証コード

**パスワードリセット完了通知**
- 送信タイミング: パスワードリセット完了時
- 送信先: 申請者のメールアドレス
- 内容: パスワード変更完了の通知

#### 2. シフト関連メール

**シフト交代リクエスト通知**
- 送信タイミング: シフト交代リクエスト送信時
- 送信先: 依頼先従業員のメールアドレス
- 内容: リクエスト詳細と承認URL

**シフト交代承認/否認通知**
- 送信タイミング: シフト交代承認/否認時
- 送信先: 依頼者と承認者のメールアドレス
- 内容: 承認/否認結果の通知

#### 3. 打刻リマインダーメール

**出勤打刻アラート**
- 送信タイミング: シフト開始時刻から5分経過後
- 送信先: 対象従業員のメールアドレス
- 内容: 出勤打刻の催促

**退勤打刻リマインダー**
- 送信タイミング: 退勤予定時刻から15分間隔
- 送信先: 対象従業員のメールアドレス
- 内容: 退勤打刻の催促

### 設定

#### Gmail SMTP設定
```ruby
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'gmail.com',
  user_name: ENV['GMAIL_USERNAME'],
  password: ENV['GMAIL_APP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

---

## パフォーマンス最適化

### 概要

フェーズ7-2で実装したパフォーマンス最適化について説明します。N+1問題の解決とfreee API呼び出しの最適化により、レスポンス時間の大幅改善と外部API依存の最適化を実現しました。

### 実装日時

- **実装完了**: 2025年1月
- **実装手法**: t-wadaのTDD手法
- **見積時間**: 7時間（N+1問題解決: 4時間、freee API最適化: 3時間）

### N+1問題の解決

#### 問題の定義

**N+1問題**は、データベースアクセスでよく発生するパフォーマンス問題です。

- **N**: メインクエリで取得したレコード数
- **+1**: メインクエリ自体
- **問題**: 関連データを取得するために、メインクエリの結果数分だけ追加クエリが実行される

#### 解決手法

1. **includes**: 関連データの事前読み込み
2. **joins**: JOINクエリによる効率的な取得
3. **select**: 必要なカラムのみの取得
4. **counter_cache**: カウントのキャッシュ

#### 実装例

```ruby
# ❌ N+1問題が発生するコード
employees = Employee.all
employees.each do |employee|
  puts employee.shifts.count  # 各従業員ごとにクエリ実行
end

# ✅ 最適化後のコード
employees = Employee.includes(:shifts)
employees.each do |employee|
  puts employee.shifts.size  # 事前読み込み済み
end
```

### freee API呼び出しの最適化

#### キャッシュ戦略

1. **メモリキャッシュ**: 従業員情報の一時保存
2. **TTL設定**: キャッシュの有効期限管理
3. **レート制限**: API呼び出し頻度の制御

#### 実装例

```ruby
class FreeeApiService
  def get_employee_info(employee_id)
    Rails.cache.fetch("employee_#{employee_id}", expires_in: 1.hour) do
      # freee API呼び出し
      fetch_from_api(employee_id)
    end
  end
end
```

---

## セキュリティ強化

### 概要

フェーズ6で実装したセキュリティ強化について説明します。セッションタイムアウト、CSRF保護、サーバーサイドバリデーション、権限チェックの強化を実装しました。

### 実装日時

- **実装完了**: 2025年1月
- **見積時間**: 22時間

### セッションタイムアウト機能

#### 実装内容

```ruby
class ApplicationController < ActionController::Base
  before_action :check_session_timeout

  private

  def check_session_timeout
    if session[:last_activity] && session[:last_activity] < 30.minutes.ago
      reset_session
      redirect_to login_path, alert: 'セッションがタイムアウトしました。'
    end
    session[:last_activity] = Time.current
  end
end
```

### CSRF保護の強化

#### 実装内容

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  # カスタムCSRFトークン検証
  def verify_authenticity_token
    unless verified_request?
      raise ActionController::InvalidAuthenticityToken
    end
  end
end
```

### サーバーサイドバリデーション

#### 実装内容

```ruby
class Employee < ApplicationRecord
  validates :employee_id, presence: true, uniqueness: true
  validates :role, inclusion: { in: %w[employee owner] }
  validates :password_hash, presence: true, on: :create
  
  # カスタムバリデーション
  validate :password_strength, on: :update
  
  private
  
  def password_strength
    return unless password_hash_changed?
    
    if password_hash.length < 8
      errors.add(:password, 'は8文字以上で入力してください')
    end
  end
end
```

### 権限チェックの強化

#### 実装内容

```ruby
class ApplicationController < ActionController::Base
  before_action :require_login
  before_action :check_permissions

  private

  def require_login
    redirect_to login_path unless logged_in?
  end

  def check_permissions
    return if current_user.owner?
    
    # 従業員のアクセス制限
    if owner_only_action?
      redirect_to dashboard_path, alert: '権限がありません。'
    end
  end
end
```

---

## エラーハンドリング

### 概要

フェーズ7-1で実装したエラーハンドリングの統一と改善について説明します。エラーメッセージの統一、ログ出力の改善、ユーザーフレンドリーなエラー表示を実装しました。

### 実装日時

- **実装完了**: 2025年1月
- **見積時間**: 6時間

### エラーハンドリング戦略

#### 1. 統一されたエラーレスポンス

```ruby
class ApplicationController < ActionController::Base
  rescue_from StandardError, with: :handle_error

  private

  def handle_error(exception)
    logger.error "Error: #{exception.message}"
    logger.error exception.backtrace.join("\n")
    
    render json: {
      error: 'システムエラーが発生しました',
      message: Rails.env.development? ? exception.message : nil
    }, status: :internal_server_error
  end
end
```

#### 2. バリデーションエラーの統一

```ruby
class Api::BaseController < ApplicationController
  def render_validation_errors(record)
    render json: {
      error: 'バリデーションエラー',
      details: record.errors.full_messages
    }, status: :unprocessable_entity
  end
end
```

#### 3. 外部APIエラーの処理

```ruby
class FreeeApiService
  def get_employees
    response = HTTParty.get(api_url, headers: headers)
    
    case response.code
    when 200
      response.parsed_response
    when 401
      raise FreeeApiError, '認証に失敗しました'
    when 429
      raise FreeeApiError, 'API制限に達しました'
    else
      raise FreeeApiError, "API呼び出しエラー: #{response.code}"
    end
  rescue HTTParty::Error => e
    raise FreeeApiError, "ネットワークエラー: #{e.message}"
  end
end
```

---

## UI/UX改善

### 概要

フェーズ5で実装したUI/UX改善について説明します。ダッシュボードの簡素化、情報の再配分、ヘッダーナビゲーションの改善を実装しました。

### 実装日時

- **実装完了**: 2025年1月
- **見積時間**: 8時間

### ダッシュボードの簡素化

#### 改善内容

1. **打刻機能の特化**: メイン機能を打刻に集中
2. **情報の整理**: 必要な情報のみを表示
3. **クイックアクセス**: よく使う機能への素早いアクセス

#### 実装例

```erb
<!-- 簡素化されたダッシュボード -->
<div class="dashboard">
  <div class="clock-section">
    <h2>打刻</h2>
    <%= render 'clock_form' %>
  </div>
  
  <div class="today-summary">
    <h3>今日の勤怠</h3>
    <%= render 'today_attendance' %>
  </div>
  
  <div class="quick-actions">
    <h3>クイックアクセス</h3>
    <%= link_to 'シフトページ', shifts_path, class: 'btn btn-primary' %>
    <%= link_to '勤怠履歴', attendance_history_path, class: 'btn btn-secondary' %>
  </div>
</div>
```

### 情報の再配分

#### 改善内容

1. **権限別表示**: 従業員とオーナーで表示内容を変更
2. **段階的開示**: 必要な情報を段階的に表示
3. **コンテキスト情報**: 関連情報を適切に配置

### ヘッダーナビゲーションの改善

#### 改善内容

1. **シンプルなナビゲーション**: 主要機能への直接アクセス
2. **ユーザー情報の表示**: 現在のユーザー情報を表示
3. **ログアウト機能**: 簡単なログアウト操作

#### 実装例

```erb
<header class="main-header">
  <div class="header-content">
    <h1 class="logo">勤怠管理システム</h1>
    
    <nav class="main-nav">
      <%= link_to 'ダッシュボード', dashboard_path, class: 'nav-link' %>
      <%= link_to 'シフト', shifts_path, class: 'nav-link' %>
      <%= link_to '勤怠履歴', attendance_history_path, class: 'nav-link' %>
    </nav>
    
    <div class="user-menu">
      <span class="user-name"><%= current_user.name %></span>
      <%= link_to 'ログアウト', logout_path, method: :delete, class: 'logout-btn' %>
    </div>
  </div>
</header>
```

---

## LINE Bot連携機能

### 概要

フェーズ9-1で実装予定のLINE Bot連携機能について説明します。データベース設計の仕様変更により、Employeeテーブルにline_idカラムを追加し、LineMessageLogテーブルでメッセージ履歴を管理します。

### 実装予定日時

- **実装予定**: Phase 9-1
- **見積時間**: 9時間
- **実装手法**: t-wadaのTDD手法

### データベース設計変更

#### Employeeテーブルの拡張
```sql
-- Employeeテーブルにline_idカラムを追加
ALTER TABLE employees ADD COLUMN line_id VARCHAR(255);
CREATE UNIQUE INDEX idx_employees_line_id ON employees(line_id);
```

#### LineMessageLogテーブルの新規作成
```sql
CREATE TABLE line_message_logs (
  id SERIAL PRIMARY KEY,
  line_user_id VARCHAR(255) NOT NULL,
  message_type VARCHAR(50) NOT NULL,
  message_content TEXT,
  direction VARCHAR(20) NOT NULL,
  processed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 設計思想

- **1対1関係**: 1人の従業員 = 1つのLINEアカウント
- **シンプル設計**: 複雑な中間テーブルを避け、保守性を重視
- **監査証跡**: LineMessageLogでメッセージ履歴を管理
- **データ整合性**: 外部キー制約でデータの整合性を保証

## 関連ドキュメント

- [要件定義](./requirement.md)
- [API仕様](./api-specification.md)
- [データベース設計](./schema-database.md)
- [画面設計](./screen-design.md)
- [セットアップガイド](./setup-guide.md)
- [実装状況](./implementation-status.md)
- [テスト仕様](./testing.md)
- [Rails移行ガイド](./rails-migration-complete-guide.md)
- [LINE Bot連携](./line_bot_integration.md)
- [LINE Bot データベース設計](./line_bot_database_design.md)
