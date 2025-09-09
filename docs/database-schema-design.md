# データベーススキーマ設計書

## 1. 概要

### 1.1. 設計方針
- **既存機能の完全移行**: Google Sheetsベースの既存システムをPostgreSQLに完全移行
- **データ整合性の確保**: 既存のデータ構造と完全に互換性を保つ
- **拡張性の考慮**: 将来的な機能拡張に対応できる設計
- **パフォーマンス最適化**: インデックス設計による高速クエリ実現

### 1.2. 移行対象の既存データ構造
```
Google Sheets構造:
├── シフト表 (SHIFT_SHEET_NAME)
├── シフト交代管理 (SHIFT_MANAGEMENT_SHEET_NAME)
├── 認証設定 (AUTH_SETTINGS_SHEET_NAME)
├── 認証コード管理 (VERIFICATION_CODES_SHEET_NAME)
└── freee API連携データ
```

## 2. テーブル設計

### 2.1. 従業員テーブル (employees)
```sql
CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) UNIQUE NOT NULL,  -- freeeの従業員ID
  name VARCHAR(100) NOT NULL,              -- 従業員名
  email VARCHAR(255),                      -- メールアドレス
  role VARCHAR(20) DEFAULT 'employee',     -- 'employee' or 'owner'
  base_pay INTEGER,                        -- 基本時給 (freee APIから取得)
  password_hash VARCHAR(255),              -- パスワードハッシュ
  password_updated_at TIMESTAMP,           -- パスワード最終更新日時
  last_login_at TIMESTAMP,                 -- 最終ログイン日時
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_employees_employee_id ON employees(employee_id);
CREATE INDEX idx_employees_role ON employees(role);
```

**既存データとの対応:**
- `employee_id`: freeeの従業員ID（7桁）
- `name`: シフト表の従業員名
- `role`: オーナー判定（従業員名による判定ロジックを移行）
- `base_pay`: freee APIの`base_pay`フィールド
- `password_hash`: 認証設定シートのハッシュ化パスワード

### 2.2. LINEユーザーテーブル (line_users)
```sql
CREATE TABLE line_users (
  id SERIAL PRIMARY KEY,
  line_user_id VARCHAR(100) UNIQUE NOT NULL,  -- LINEユーザーID
  employee_id VARCHAR(7) REFERENCES employees(employee_id),  -- 従業員IDとの紐付け
  display_name VARCHAR(100),                  -- LINE表示名
  authenticated_at TIMESTAMP,                 -- 認証完了日時
  is_group BOOLEAN DEFAULT FALSE,             -- グループLINEかどうか
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_line_users_line_user_id ON line_users(line_user_id);
CREATE INDEX idx_line_users_employee_id ON line_users(employee_id);
CREATE INDEX idx_line_users_is_group ON line_users(is_group);
```

**既存データとの対応:**
- LINE認証フローで従業員IDと紐付け
- グループLINEと個人LINEの識別

### 2.3. シフトテーブル (shifts)
```sql
CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  shift_date DATE NOT NULL,                  -- シフト日付
  start_time TIME NOT NULL,                  -- 開始時間
  end_time TIME NOT NULL,                    -- 終了時間
  is_modified BOOLEAN DEFAULT FALSE,         -- シフト変更フラグ
  original_employee_id VARCHAR(7),           -- 元の担当者（交代時）
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_shifts_employee_id ON shifts(employee_id);
CREATE INDEX idx_shifts_shift_date ON shifts(shift_date);
CREATE INDEX idx_shifts_date_range ON shifts(shift_date, start_time, end_time);
```

**既存データとの対応:**
- シフト表の全データを移行
- 時間形式: "18-20" → start_time: 18:00, end_time: 20:00

### 2.4. シフト交代管理テーブル (shift_exchanges)
```sql
CREATE TABLE shift_exchanges (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(36) UNIQUE NOT NULL,    -- UUID
  requester_id VARCHAR(7) REFERENCES employees(employee_id),  -- 申請者
  approver_id VARCHAR(7) REFERENCES employees(employee_id),   -- 承認者
  shift_id INTEGER REFERENCES shifts(id),    -- 対象シフト
  status VARCHAR(20) DEFAULT 'pending',      -- 'pending', 'approved', 'rejected'
  request_message TEXT,                      -- 申請メッセージ
  response_message TEXT,                     -- 承認者からの返信
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_shift_exchanges_request_id ON shift_exchanges(request_id);
CREATE INDEX idx_shift_exchanges_requester_id ON shift_exchanges(requester_id);
CREATE INDEX idx_shift_exchanges_approver_id ON shift_exchanges(approver_id);
CREATE INDEX idx_shift_exchanges_status ON shift_exchanges(status);
```

**既存データとの対応:**
- シフト交代管理シートの全データを移行
- 申請ID、申請者ID、承認者ID、ステータス管理

### 2.5. シフト追加管理テーブル (shift_additions)
```sql
CREATE TABLE shift_additions (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(36) UNIQUE NOT NULL,    -- UUID
  target_employee_id VARCHAR(7) REFERENCES employees(employee_id),  -- 依頼対象従業員
  shift_date DATE NOT NULL,                  -- シフト日付
  start_time TIME NOT NULL,                  -- 開始時間
  end_time TIME NOT NULL,                    -- 終了時間
  status VARCHAR(20) DEFAULT 'pending',      -- 'pending', 'approved', 'rejected'
  request_message TEXT,                      -- 依頼メッセージ
  response_message TEXT,                     -- 従業員からの返信
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_shift_additions_request_id ON shift_additions(request_id);
CREATE INDEX idx_shift_additions_target_employee_id ON shift_additions(target_employee_id);
CREATE INDEX idx_shift_additions_status ON shift_additions(status);
```

**既存データとの対応:**
- シフト追加管理シートの全データを移行

### 2.6. 認証コードテーブル (verification_codes)
```sql
CREATE TABLE verification_codes (
  id SERIAL PRIMARY KEY,
  line_user_id VARCHAR(100) REFERENCES line_users(line_user_id),
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  code VARCHAR(6) NOT NULL,                  -- 6桁認証コード
  expires_at TIMESTAMP NOT NULL,             -- 有効期限
  used_at TIMESTAMP,                         -- 使用日時
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_verification_codes_code ON verification_codes(code);
CREATE INDEX idx_verification_codes_employee_id ON verification_codes(employee_id);
CREATE INDEX idx_verification_codes_expires_at ON verification_codes(expires_at);
```

**既存データとの対応:**
- 認証コード管理シートの全データを移行

### 2.7. 勤怠記録テーブル (attendance_records)
```sql
CREATE TABLE attendance_records (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  work_date DATE NOT NULL,                   -- 勤務日
  clock_in_time TIMESTAMP,                   -- 出勤時刻
  clock_out_time TIMESTAMP,                  -- 退勤時刻
  break_duration INTEGER DEFAULT 0,          -- 休憩時間（分）
  total_work_hours DECIMAL(4,2),             -- 総労働時間
  hourly_wage INTEGER,                       -- 時給（時間帯別）
  daily_wage INTEGER,                         -- 日給
  is_modified BOOLEAN DEFAULT FALSE,         -- 修正フラグ
  modified_by VARCHAR(7),                    -- 修正者
  modified_at TIMESTAMP,                     -- 修正日時
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_attendance_records_employee_id ON attendance_records(employee_id);
CREATE INDEX idx_attendance_records_work_date ON attendance_records(work_date);
CREATE INDEX idx_attendance_records_date_range ON attendance_records(work_date, employee_id);
```

**既存データとの対応:**
- freee APIから取得する勤怠データを保存
- 103万の壁ゲージ計算用のデータ

### 2.8. 給与計算テーブル (salary_calculations)
```sql
CREATE TABLE salary_calculations (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  calculation_date DATE NOT NULL,            -- 計算日
  monthly_wage INTEGER,                      -- 月給
  annual_wage_projection INTEGER,            -- 年間給与見込み
  target_achievement_rate DECIMAL(5,2),      -- 103万達成率
  time_zone_wages JSONB,                     -- 時間帯別給与詳細
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_salary_calculations_employee_id ON salary_calculations(employee_id);
CREATE INDEX idx_salary_calculations_calculation_date ON salary_calculations(calculation_date);
```

**既存データとの対応:**
- 103万の壁ゲージ計算結果を保存
- 時間帯別時給システムの計算結果

### 2.9. 通知ログテーブル (notification_logs)
```sql
CREATE TABLE notification_logs (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  notification_type VARCHAR(50) NOT NULL,    -- 'attendance_reminder', 'salary_alert', 'shift_change'
  message TEXT NOT NULL,                     -- 通知メッセージ
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) DEFAULT 'sent',         -- 'sent', 'failed', 'pending'
  error_message TEXT,                        -- エラーメッセージ
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_notification_logs_employee_id ON notification_logs(employee_id);
CREATE INDEX idx_notification_logs_type ON notification_logs(notification_type);
CREATE INDEX idx_notification_logs_sent_at ON notification_logs(sent_at);
```

**既存データとの対応:**
- 打刻リマインダー、103万の壁アラート等の通知履歴

## 3. リレーション設計

### 3.1. 主要リレーション
```
employees (1) ←→ (1) line_users
employees (1) ←→ (N) shifts
employees (1) ←→ (N) attendance_records
employees (1) ←→ (N) salary_calculations
employees (1) ←→ (N) shift_exchanges (requester)
employees (1) ←→ (N) shift_exchanges (approver)
employees (1) ←→ (N) shift_additions (target)
employees (1) ←→ (N) notification_logs
shifts (1) ←→ (N) shift_exchanges
line_users (1) ←→ (N) verification_codes
```

### 3.2. 外部キー制約
```sql
-- 外部キー制約の設定
ALTER TABLE line_users ADD CONSTRAINT fk_line_users_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE shifts ADD CONSTRAINT fk_shifts_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE shift_exchanges ADD CONSTRAINT fk_shift_exchanges_requester_id 
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE shift_exchanges ADD CONSTRAINT fk_shift_exchanges_approver_id 
  FOREIGN KEY (approver_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE shift_exchanges ADD CONSTRAINT fk_shift_exchanges_shift_id 
  FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE;

ALTER TABLE shift_additions ADD CONSTRAINT fk_shift_additions_target_employee_id 
  FOREIGN KEY (target_employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE verification_codes ADD CONSTRAINT fk_verification_codes_line_user_id 
  FOREIGN KEY (line_user_id) REFERENCES line_users(line_user_id) ON DELETE CASCADE;

ALTER TABLE verification_codes ADD CONSTRAINT fk_verification_codes_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE attendance_records ADD CONSTRAINT fk_attendance_records_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE salary_calculations ADD CONSTRAINT fk_salary_calculations_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;

ALTER TABLE notification_logs ADD CONSTRAINT fk_notification_logs_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;
```

## 4. データ移行計画

### 4.1. 移行順序
1. **employees** - 従業員基本情報
2. **line_users** - LINEユーザー情報（認証後）
3. **shifts** - シフトデータ
4. **shift_exchanges** - シフト交代管理
5. **shift_additions** - シフト追加管理
6. **verification_codes** - 認証コード
7. **attendance_records** - 勤怠記録（freee APIから）
8. **salary_calculations** - 給与計算結果
9. **notification_logs** - 通知履歴

### 4.2. データ変換ルール
```ruby
# シフト時間の変換例
def parse_shift_time(time_string)
  # "18-20" → start_time: 18:00, end_time: 20:00
  start_hour, end_hour = time_string.split('-').map(&:to_i)
  {
    start_time: "#{start_hour}:00:00",
    end_time: "#{end_hour}:00:00"
  }
end

# 従業員IDの正規化
def normalize_employee_id(id)
  # 7桁にゼロパディング
  id.to_s.rjust(7, '0')
end

# 権限の判定
def determine_role(employee_name)
  # 既存のオーナー判定ロジックを移行
  owner_names = ['オーナー', '店長', '管理者']
  owner_names.include?(employee_name) ? 'owner' : 'employee'
end
```

## 5. パフォーマンス最適化

### 5.1. インデックス戦略
```sql
-- 複合インデックス
CREATE INDEX idx_shifts_employee_date ON shifts(employee_id, shift_date);
CREATE INDEX idx_attendance_employee_date ON attendance_records(employee_id, work_date);
CREATE INDEX idx_verification_codes_active ON verification_codes(code, expires_at) WHERE used_at IS NULL;

-- 部分インデックス
CREATE INDEX idx_employees_owners ON employees(employee_id) WHERE role = 'owner';
CREATE INDEX idx_shift_exchanges_pending ON shift_exchanges(approver_id, status) WHERE status = 'pending';
```

### 5.2. クエリ最適化
```sql
-- 月次シフト取得（最適化済み）
SELECT s.*, e.name 
FROM shifts s 
JOIN employees e ON s.employee_id = e.employee_id 
WHERE s.shift_date BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY s.shift_date, s.start_time;

-- 103万の壁計算（最適化済み）
SELECT 
  e.employee_id,
  e.name,
  COALESCE(sc.annual_wage_projection, 0) as annual_wage,
  COALESCE(sc.target_achievement_rate, 0) as achievement_rate
FROM employees e
LEFT JOIN salary_calculations sc ON e.employee_id = sc.employee_id 
  AND sc.calculation_date = CURRENT_DATE
WHERE e.role = 'employee';
```

## 6. セキュリティ考慮

### 6.1. データ保護
```sql
-- パスワードハッシュの暗号化
-- bcryptを使用してハッシュ化（アプリケーションレベル）

-- 機密データのマスキング
CREATE VIEW employees_public AS
SELECT employee_id, name, role, created_at
FROM employees;

-- 監査ログの実装
CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  table_name VARCHAR(50) NOT NULL,
  record_id INTEGER NOT NULL,
  action VARCHAR(20) NOT NULL,  -- 'INSERT', 'UPDATE', 'DELETE'
  old_values JSONB,
  new_values JSONB,
  user_id VARCHAR(7),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 6.2. アクセス制御
```sql
-- ロールベースアクセス制御
CREATE ROLE attendance_app_user;
CREATE ROLE attendance_app_admin;

-- 権限設定
GRANT SELECT, INSERT, UPDATE ON employees TO attendance_app_user;
GRANT ALL PRIVILEGES ON employees TO attendance_app_admin;
```

## 7. バックアップ・復旧

### 7.1. バックアップ戦略
```sql
-- 日次フルバックアップ
-- 時間別増分バックアップ
-- 重要テーブルの即座バックアップ

-- バックアップテーブル
CREATE TABLE employees_backup AS SELECT * FROM employees;
CREATE TABLE shifts_backup AS SELECT * FROM shifts;
```

### 7.2. 復旧手順
1. 最新のフルバックアップから復元
2. 増分バックアップから差分復元
3. データ整合性チェック
4. アプリケーション再起動

## 8. 監視・メンテナンス

### 8.1. 監視項目
- テーブルサイズの監視
- インデックス使用率の監視
- クエリパフォーマンスの監視
- 接続数の監視

### 8.2. メンテナンスタスク
```sql
-- 定期的なVACUUM
VACUUM ANALYZE;

-- インデックス再構築
REINDEX TABLE shifts;
REINDEX TABLE attendance_records;

-- 統計情報更新
ANALYZE;
```

## 9. 移行後の検証

### 9.1. データ整合性チェック
```sql
-- 従業員数チェック
SELECT COUNT(*) FROM employees;
-- 期待値: 既存の従業員数と一致

-- シフト数チェック
SELECT COUNT(*) FROM shifts;
-- 期待値: 既存のシフト数と一致

-- 認証データチェック
SELECT COUNT(*) FROM verification_codes WHERE used_at IS NULL;
-- 期待値: 有効な認証コード数
```

### 9.2. 機能テスト
- 認証フローの動作確認
- シフト確認機能の動作確認
- 勤怠確認機能の動作確認
- 103万の壁ゲージの動作確認

## 10. 今後の拡張性

### 10.1. 追加予定テーブル
```sql
-- 勤怠修正履歴テーブル
CREATE TABLE attendance_modifications (
  id SERIAL PRIMARY KEY,
  attendance_record_id INTEGER REFERENCES attendance_records(id),
  modified_by VARCHAR(7) REFERENCES employees(employee_id),
  modification_type VARCHAR(50),  -- 'clock_in', 'clock_out', 'break'
  old_value TIMESTAMP,
  new_value TIMESTAMP,
  reason TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- システム設定テーブル
CREATE TABLE system_settings (
  id SERIAL PRIMARY KEY,
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 10.2. パフォーマンス改善
- パーティショニングの導入
- 読み取り専用レプリカの構築
- キャッシュ戦略の実装

この設計により、既存のGoogle Sheetsベースシステムを完全にPostgreSQLに移行し、既存機能を維持しながら拡張性を確保できます。
