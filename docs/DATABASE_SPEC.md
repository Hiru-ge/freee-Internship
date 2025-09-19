# データベース仕様書

勤怠管理システムのデータベース設計と実装仕様です。

## 🎯 概要

勤怠管理システムのデータベース設計、テーブル構造、リレーション、インデックス設計の詳細仕様です。

## 🗄️ データベース構成

### 基本情報
- **データベース**: PostgreSQL
- **Rails環境**: production, development, test
- **文字エンコーディング**: UTF-8
- **タイムゾーン**: Asia/Tokyo

### 接続設定
```yaml
# config/database.yml
production:
  adapter: postgresql
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV['DATABASE_HOST'] %>
  port: <%= ENV['DATABASE_PORT'] %>
  encoding: utf8
  timezone: Asia/Tokyo
```

## 📊 テーブル設計

### 1. employees テーブル
従業員情報を管理するテーブル

```sql
CREATE TABLE employees (
  id BIGSERIAL PRIMARY KEY,
  employee_id VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  role VARCHAR(50) NOT NULL DEFAULT 'employee',
  password_hash VARCHAR(255),
  password_updated_at TIMESTAMP,
  line_id VARCHAR(255),
  last_login_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `employee_id`: 従業員ID（Freee API連携用、一意）
- `name`: 従業員名
- `email`: メールアドレス
- `role`: 役割（employee/owner）
- `password_hash`: パスワードハッシュ
- `password_updated_at`: パスワード更新日時
- `line_id`: LINEユーザーID（LINE Bot連携用）
- `last_login_at`: 最終ログイン日時

**インデックス**:
```sql
CREATE INDEX idx_employees_employee_id ON employees(employee_id);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_line_id ON employees(line_id);
CREATE INDEX idx_employees_role ON employees(role);
```

### 2. shifts テーブル
シフト情報を管理するテーブル

```sql
CREATE TABLE shifts (
  id BIGSERIAL PRIMARY KEY,
  employee_id VARCHAR(255) NOT NULL,
  shift_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `employee_id`: 従業員ID（外部キー）
- `shift_date`: シフト日付
- `start_time`: 開始時間
- `end_time`: 終了時間

**インデックス**:
```sql
CREATE INDEX idx_shifts_employee_id ON shifts(employee_id);
CREATE INDEX idx_shifts_shift_date ON shifts(shift_date);
CREATE INDEX idx_shifts_employee_date ON shifts(employee_id, shift_date);
CREATE INDEX idx_shifts_date_range ON shifts(shift_date, start_time, end_time);
```

### 3. shift_exchanges テーブル
シフト交代依頼を管理するテーブル

```sql
CREATE TABLE shift_exchanges (
  id BIGSERIAL PRIMARY KEY,
  request_id VARCHAR(255) UNIQUE NOT NULL,
  requester_id VARCHAR(255) NOT NULL,
  approver_id VARCHAR(255) NOT NULL,
  shift_id BIGINT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id),
  FOREIGN KEY (approver_id) REFERENCES employees(employee_id),
  FOREIGN KEY (shift_id) REFERENCES shifts(id)
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `request_id`: リクエストID（一意）
- `requester_id`: 依頼者ID（外部キー）
- `approver_id`: 承認者ID（外部キー）
- `shift_id`: シフトID（外部キー）
- `status`: ステータス（pending/approved/rejected）

**インデックス**:
```sql
CREATE INDEX idx_shift_exchanges_request_id ON shift_exchanges(request_id);
CREATE INDEX idx_shift_exchanges_requester_id ON shift_exchanges(requester_id);
CREATE INDEX idx_shift_exchanges_approver_id ON shift_exchanges(approver_id);
CREATE INDEX idx_shift_exchanges_shift_id ON shift_exchanges(shift_id);
CREATE INDEX idx_shift_exchanges_status ON shift_exchanges(status);
```

### 4. shift_additions テーブル
シフト追加依頼を管理するテーブル

```sql
CREATE TABLE shift_additions (
  id BIGSERIAL PRIMARY KEY,
  request_id VARCHAR(255) UNIQUE NOT NULL,
  requester_id VARCHAR(255) NOT NULL,
  approver_id VARCHAR(255) NOT NULL,
  shift_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  target_employee_ids TEXT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id),
  FOREIGN KEY (approver_id) REFERENCES employees(employee_id)
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `request_id`: リクエストID（一意）
- `requester_id`: 依頼者ID（外部キー）
- `approver_id`: 承認者ID（外部キー）
- `shift_date`: シフト日付
- `start_time`: 開始時間
- `end_time`: 終了時間
- `target_employee_ids`: 対象従業員ID（JSON形式）
- `status`: ステータス（pending/approved/rejected）

**インデックス**:
```sql
CREATE INDEX idx_shift_additions_request_id ON shift_additions(request_id);
CREATE INDEX idx_shift_additions_requester_id ON shift_additions(requester_id);
CREATE INDEX idx_shift_additions_approver_id ON shift_additions(approver_id);
CREATE INDEX idx_shift_additions_shift_date ON shift_additions(shift_date);
CREATE INDEX idx_shift_additions_status ON shift_additions(status);
```

### 5. shift_deletions テーブル
欠勤申請を管理するテーブル

```sql
CREATE TABLE shift_deletions (
  id BIGSERIAL PRIMARY KEY,
  request_id VARCHAR(255) UNIQUE NOT NULL,
  requester_id VARCHAR(255) NOT NULL,
  approver_id VARCHAR(255) NOT NULL,
  shift_id BIGINT NOT NULL,
  reason TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id),
  FOREIGN KEY (approver_id) REFERENCES employees(employee_id),
  FOREIGN KEY (shift_id) REFERENCES shifts(id)
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `request_id`: リクエストID（一意）
- `requester_id`: 依頼者ID（外部キー）
- `approver_id`: 承認者ID（外部キー）
- `shift_id`: シフトID（外部キー）
- `reason`: 欠勤理由
- `status`: ステータス（pending/approved/rejected）

**インデックス**:
```sql
CREATE INDEX idx_shift_deletions_request_id ON shift_deletions(request_id);
CREATE INDEX idx_shift_deletions_requester_id ON shift_deletions(requester_id);
CREATE INDEX idx_shift_deletions_approver_id ON shift_deletions(approver_id);
CREATE INDEX idx_shift_deletions_shift_id ON shift_deletions(shift_id);
CREATE INDEX idx_shift_deletions_status ON shift_deletions(status);
```

### 6. conversation_states テーブル
LINE Botの会話状態を管理するテーブル

```sql
CREATE TABLE conversation_states (
  id BIGSERIAL PRIMARY KEY,
  line_user_id VARCHAR(255) NOT NULL,
  state VARCHAR(255) NOT NULL,
  state_data TEXT,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `line_user_id`: LINEユーザーID
- `state`: 会話状態
- `state_data`: 状態データ（JSON形式）
- `expires_at`: 有効期限

**インデックス**:
```sql
CREATE INDEX idx_conversation_states_line_user_id ON conversation_states(line_user_id);
CREATE INDEX idx_conversation_states_state ON conversation_states(state);
CREATE INDEX idx_conversation_states_expires_at ON conversation_states(expires_at);
```

### 7. verification_codes テーブル
認証コードを管理するテーブル

```sql
CREATE TABLE verification_codes (
  id BIGSERIAL PRIMARY KEY,
  employee_id VARCHAR(255) NOT NULL,
  code VARCHAR(6) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `employee_id`: 従業員ID（外部キー）
- `code`: 認証コード（6桁）
- `expires_at`: 有効期限
- `used_at`: 使用日時

**インデックス**:
```sql
CREATE INDEX idx_verification_codes_employee_id ON verification_codes(employee_id);
CREATE INDEX idx_verification_codes_code ON verification_codes(code);
CREATE INDEX idx_verification_codes_expires_at ON verification_codes(expires_at);
```

### 8. email_verification_codes テーブル
メール認証コードを管理するテーブル

```sql
CREATE TABLE email_verification_codes (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  code VARCHAR(6) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `email`: メールアドレス
- `code`: 認証コード（6桁）
- `expires_at`: 有効期限
- `used_at`: 使用日時

**インデックス**:
```sql
CREATE INDEX idx_email_verification_codes_email ON email_verification_codes(email);
CREATE INDEX idx_email_verification_codes_code ON email_verification_codes(code);
CREATE INDEX idx_email_verification_codes_expires_at ON email_verification_codes(expires_at);
```

### 9. line_message_logs テーブル
LINE Botのメッセージログを管理するテーブル

```sql
CREATE TABLE line_message_logs (
  id BIGSERIAL PRIMARY KEY,
  line_user_id VARCHAR(255) NOT NULL,
  message_type VARCHAR(50) NOT NULL,
  message_content TEXT,
  response_content TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**カラム説明**:
- `id`: 主キー（自動採番）
- `line_user_id`: LINEユーザーID
- `message_type`: メッセージタイプ
- `message_content`: メッセージ内容
- `response_content`: レスポンス内容

**インデックス**:
```sql
CREATE INDEX idx_line_message_logs_line_user_id ON line_message_logs(line_user_id);
CREATE INDEX idx_line_message_logs_message_type ON line_message_logs(message_type);
CREATE INDEX idx_line_message_logs_created_at ON line_message_logs(created_at);
```

## 🔗 リレーション設計

### 主要なリレーション
```ruby
# Employee モデル
class Employee < ApplicationRecord
  has_many :verification_codes, foreign_key: "employee_id", primary_key: "employee_id"
  has_many :shifts, foreign_key: "employee_id", primary_key: "employee_id"
  has_many :shift_exchanges, foreign_key: "requester_id", primary_key: "employee_id"
  has_many :shift_additions, foreign_key: "requester_id", primary_key: "employee_id"
  has_many :shift_deletions, foreign_key: "requester_id", primary_key: "employee_id"
end

# Shift モデル
class Shift < ApplicationRecord
  belongs_to :employee, foreign_key: "employee_id", primary_key: "employee_id"
  has_many :shift_exchanges, dependent: :destroy
  has_many :shift_deletions, dependent: :destroy
end

# ShiftExchange モデル
class ShiftExchange < ApplicationRecord
  belongs_to :requester, class_name: "Employee", foreign_key: "requester_id", primary_key: "employee_id"
  belongs_to :approver, class_name: "Employee", foreign_key: "approver_id", primary_key: "employee_id"
  belongs_to :shift
end
```

## 📈 パフォーマンス最適化

### インデックス戦略
1. **主キー**: 自動採番のBIGSERIAL
2. **外部キー**: 関連テーブルへの高速アクセス
3. **検索条件**: 頻繁に使用される検索条件
4. **複合インデックス**: 複数カラムでの検索最適化

### クエリ最適化
```sql
-- 月次シフト取得の最適化
SELECT s.*, e.name
FROM shifts s
JOIN employees e ON s.employee_id = e.employee_id
WHERE s.shift_date BETWEEN '2024-12-01' AND '2024-12-31'
ORDER BY s.shift_date, s.start_time;

-- 承認待ち依頼の取得
SELECT se.*, e1.name as requester_name, e2.name as approver_name
FROM shift_exchanges se
JOIN employees e1 ON se.requester_id = e1.employee_id
JOIN employees e2 ON se.approver_id = e2.employee_id
WHERE se.status = 'pending'
ORDER BY se.created_at DESC;
```

### バッチ処理最適化
```sql
-- 期限切れデータの一括削除
DELETE FROM conversation_states
WHERE expires_at < NOW();

DELETE FROM verification_codes
WHERE expires_at < NOW();

DELETE FROM email_verification_codes
WHERE expires_at < NOW();
```

## 🔒 セキュリティ

### データ保護
- **パスワード**: bcryptによるハッシュ化
- **認証コード**: 6桁ランダム数字
- **有効期限**: 自動削除によるデータ保護
- **アクセス制御**: ロールベースのアクセス制御

### 監査ログ
```sql
-- 監査ログテーブル（将来の拡張用）
CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  table_name VARCHAR(255) NOT NULL,
  record_id BIGINT NOT NULL,
  action VARCHAR(50) NOT NULL,
  old_values JSONB,
  new_values JSONB,
  user_id VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

## 📊 データ移行

### マイグレーション戦略
```ruby
# 例: インデックス追加のマイグレーション
class AddIndexesToShifts < ActiveRecord::Migration[8.0]
  def change
    add_index :shifts, [:employee_id, :shift_date], name: 'idx_shifts_employee_date'
    add_index :shifts, [:shift_date, :start_time, :end_time], name: 'idx_shifts_date_range'
  end
end
```

### データバックアップ
```bash
# データベースバックアップ
pg_dump -h localhost -U username -d database_name > backup.sql

# 特定テーブルのバックアップ
pg_dump -h localhost -U username -d database_name -t employees > employees_backup.sql
```

## 🧪 テストデータ

### テストデータ生成
```ruby
# テスト用の従業員データ
FactoryBot.define do
  factory :employee do
    employee_id { "EMP#{rand(1000..9999)}" }
    name { Faker::Name.name }
    email { Faker::Internet.email }
    role { "employee" }
    password_hash { BCrypt::Password.create("password") }
  end

  factory :shift do
    employee
    shift_date { Date.current + rand(1..30).days }
    start_time { Time.zone.parse("09:00") }
    end_time { Time.zone.parse("17:00") }
  end
end
```

## 🚀 今後の拡張予定

### 機能拡張
- **勤怠記録テーブル**: Freee API連携用の勤怠記録
- **給与計算テーブル**: 給与計算結果の保存
- **通知履歴テーブル**: 通知送信履歴の管理
- **システム設定テーブル**: システム設定の管理

### パフォーマンス改善
- **パーティショニング**: 大容量テーブルの分割
- **レプリケーション**: 読み取り専用レプリカ
- **キャッシュ**: Redis によるキャッシュ
- **アーカイブ**: 古いデータのアーカイブ

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
