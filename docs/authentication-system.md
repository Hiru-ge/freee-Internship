# 認証システム実装ドキュメント

## 概要

勤怠管理システムの認証システムは、GAS時代の機能を完全に再現し、freee APIとの連携により実データベースでの認証を実現しています。

## 実装完了日

**2025年9月9日** - Phase 2-1: 認証システム移行完了

## アーキテクチャ

### データベース設計

#### employees テーブル
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

#### verification_codes テーブル
```sql
CREATE TABLE verification_codes (
  id BIGSERIAL PRIMARY KEY,
  employee_id VARCHAR NOT NULL,
  code VARCHAR NOT NULL,
  code_type VARCHAR NOT NULL CHECK (code_type IN ('initial_password', 'password_reset')),
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### 認証フロー

#### 1. ログイン
1. 従業員選択（freee APIから動的取得）
2. パスワード入力
3. 認証処理（bcrypt使用）
4. セッション作成
5. ダッシュボードへリダイレクト

#### 2. 初回パスワード設定
1. 従業員選択
2. 認証コード送信（メール）
3. 認証コード入力・検証
4. 新パスワード設定
5. ログイン画面へリダイレクト

#### 3. パスワード変更
1. 現在のパスワード確認
2. 新パスワード設定
3. パスワード更新
4. ダッシュボードへリダイレクト

#### 4. パスワード忘れ（3段階）
1. **段階1**: 従業員選択 → 認証コード送信
2. **段階2**: 認証コード入力・検証
3. **段階3**: 新パスワード設定 → ログイン画面へ

## 主要コンポーネント

### コントローラー

#### AuthController
- `login` - ログイン処理
- `initial_password` - 初回パスワード設定
- `password_change` - パスワード変更
- `forgot_password` - パスワード忘れ（段階1）
- `verify_password_reset` - パスワード忘れ（段階2）
- `reset_password` - パスワード忘れ（段階3）
- `logout` - ログアウト
- `send_verification_code` - 認証コード送信API
- `verify_code` - 認証コード検証API

### モデル

#### Employee
```ruby
class Employee < ApplicationRecord
  validates :employee_id, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[employee owner] }
  
  has_many :verification_codes, foreign_key: 'employee_id', primary_key: 'employee_id', dependent: :destroy
  
  def owner?
    role == 'owner'
  end
  
  def update_password!(new_password_hash)
    update!(password_hash: new_password_hash, password_updated_at: Time.current)
  end
end
```

#### VerificationCode
```ruby
class VerificationCode < ApplicationRecord
  validates :employee_id, presence: true
  validates :code, presence: true, length: { is: 6 }
  validates :code_type, presence: true, inclusion: { in: %w[initial_password password_reset] }
  validates :expires_at, presence: true
  
  scope :valid, -> { where('expires_at > ?', Time.current) }
  
  def expired?
    expires_at < Time.current
  end
  
  def self.generate_code
    rand(100000..999999).to_s
  end
end
```

### サービス

#### AuthService
- `login` - ログイン認証
- `change_password` - パスワード変更
- `setup_initial_password` - 初回パスワード設定
- `send_password_reset_code` - パスワードリセット用認証コード送信
- `verify_password_reset_code` - パスワードリセット用認証コード検証
- `reset_password_with_verification` - 認証コード付きパスワードリセット
- `get_employee_info_from_freee` - freee APIから従業員情報取得

#### FreeeApiService
- `get_all_employees` - 全従業員情報取得（ページネーション対応）
- `get_employee_info` - 特定従業員情報取得
- `get_time_clocks` - 勤怠データ取得
- `get_hourly_wage` - 基本時給取得
- `get_company_name` - 事業所名取得
- `post_work_record` - 勤怠打刻登録

### メーラー

#### AuthMailer
- `password_reset_code` - パスワードリセット用認証コード送信
- `verification_code` - 初回パスワード設定用認証コード送信

## freee API連携

### 設定
```yaml
# config/freee_api.yml
development:
  access_token: <%= ENV['FREEE_ACCESS_TOKEN'] %>
  company_id: <%= ENV['FREEE_COMPANY_ID'] %>
```

### 環境変数
```bash
# .env
FREEE_ACCESS_TOKEN=your_access_token_here
FREEE_COMPANY_ID=your_company_id_here
```

### 実データ管理
- 従業員情報はfreee APIから動的取得
- DBには認証情報のみ保存
- 従業員一覧は常に最新のfreeeデータを表示

## メール送信

### Gmail SMTP設定
```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :smtp
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

### 環境変数
```bash
# .env
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here
```

## セキュリティ

### パスワード管理
- bcryptによるハッシュ化
- 初回ログイン時はパスワード未設定でもOK
- 認証コードは6桁の数字、10分間有効

### セッション管理
- Rails標準のセッション機能使用
- ログアウト時にセッションクリア
- 認証が必要なページは`authenticate_user!`で保護

### 環境変数
- 機密情報はすべて環境変数で管理
- `.env`ファイルはGit管理外
- 本番環境では環境変数を直接設定

## テスト済み機能

### ✅ 正常動作確認済み
- [x] ログイン機能（実データベース）
- [x] ログアウト機能
- [x] パスワード変更機能
- [x] 初回パスワード設定機能
- [x] パスワード忘れ機能（3段階）
- [x] メール送信機能（Gmail SMTP）
- [x] freee API連携（従業員情報取得）
- [x] セッション管理

### 実データ
- **従業員数**: 4名
- **店長**: 3313254 - 店長 太郎（パスワード設定済み）
- **従業員**: 3316116, 3316120, 3317741（パスワード未設定）

## 今後の拡張予定

### Phase 2-2: マイページ機能移行
- 打刻機能の実装
- 勤怠履歴表示
- 月次ナビゲーション

### Phase 2-3: シフト管理機能移行
- シフト表示・確認機能
- シフト交代機能

### Phase 2-4: 給与管理機能移行
- 103万の壁ゲージ機能
- 給与計算機能

## 技術スタック

- **Ruby on Rails**: 8.0.2
- **PostgreSQL**: データベース
- **bcrypt**: パスワードハッシュ化
- **HTTParty**: freee API連携
- **ActionMailer**: メール送信
- **Gmail SMTP**: メール配信

## 関連ファイル

### コントローラー
- `app/controllers/auth_controller.rb`
- `app/controllers/application_controller.rb`

### モデル
- `app/models/employee.rb`
- `app/models/verification_code.rb`

### サービス
- `app/services/auth_service.rb`
- `app/services/freee_api_service.rb`

### メーラー
- `app/mailers/auth_mailer.rb`
- `app/views/auth_mailer/`

### ビュー
- `app/views/auth/`
- `app/views/dashboard/`
- `app/views/shifts/`

### 設定
- `config/freee_api.yml`
- `config/environments/development.rb`
- `config/routes.rb`
- `.env`（環境変数）

### データベース
- `db/migrate/20250909085650_create_employees.rb`
- `db/migrate/20250909085942_create_verification_codes.rb`
- `db/schema.rb`
