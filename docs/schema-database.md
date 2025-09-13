# データベーススキーマ設計書

## 1. 概要

### 1.1. 設計方針
- **freee APIを唯一の情報源**: ユーザー情報はfreee APIから取得し、ローカルでは最小限の情報のみ保存
- **データ重複の排除**: 従業員名、メール、時給等の情報はfreee APIから取得
- **認証情報のみローカル保存**: freeeの従業員ID + パスワードハッシュのみをローカルで管理
- **キャッシュ戦略**: パフォーマンス向上のための一時的なキャッシュ機能
- **データ整合性の確保**: 単一の情報源による整合性の保証

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
  employee_id VARCHAR(7) UNIQUE NOT NULL,  -- freeeの従業員ID（主キー）
  password_hash VARCHAR(255) NOT NULL,     -- パスワードハッシュ（唯一のローカル情報）
  role VARCHAR(20) DEFAULT 'employee',     -- 権限管理（'employee' or 'owner'）
  last_login_at TIMESTAMP,                 -- 最終ログイン日時
  password_updated_at TIMESTAMP,           -- パスワード最終更新日時
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_employees_employee_id ON employees(employee_id);
CREATE INDEX idx_employees_role ON employees(role);
```

**設計方針:**
- 従業員名、メール、時給等の情報はfreee APIから動的取得
- 認証に必要な情報のみをローカル保存
- データの重複を排除し、freee APIを唯一の情報源として活用

### 2.2. 従業員情報キャッシュテーブル (employee_cache)
```sql
CREATE TABLE employee_cache (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  name VARCHAR(100) NOT NULL,              -- 従業員名（キャッシュ）
  email VARCHAR(255),                      -- メールアドレス（キャッシュ）
  base_pay INTEGER,                        -- 基本時給（キャッシュ）
  cache_expires_at TIMESTAMP NOT NULL,     -- キャッシュ有効期限
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス
CREATE INDEX idx_employee_cache_employee_id ON employee_cache(employee_id);
CREATE INDEX idx_employee_cache_expires_at ON employee_cache(cache_expires_at);
```

**目的:**
- freee APIからの情報を一時的にキャッシュ
- API呼び出し回数の削減
- パフォーマンス向上

### 2.3. LINEユーザーテーブル (line_users)
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

### 2.4. シフトテーブル (shifts)
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

### 2.5. シフト交代管理テーブル (shift_exchanges)
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

### 2.6. シフト追加管理テーブル (shift_additions)
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

### 2.7. 認証コードテーブル (verification_codes)
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

### 2.8. 勤怠記録テーブル (attendance_records)
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

### 2.9. 給与計算テーブル (salary_calculations)
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

### 2.10. 通知ログテーブル (notification_logs)
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

## 3. freee API連携サービス設計

### 3.1. FreeeApiService クラス設計
```ruby
# app/services/freee_api_service.rb
class FreeeApiService
  include HTTParty
  base_uri 'https://api.freee.co.jp'

  def initialize(access_token)
    @access_token = access_token
    @options = {
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      }
    }
  end

  # 従業員情報取得（キャッシュ付き）
  def get_employee_info(employee_id)
    # キャッシュチェック
    cached_info = get_cached_employee_info(employee_id)
    return cached_info if cached_info && !cache_expired?(cached_info)

    # freee APIから取得
    response = self.class.get("/hr/api/v1/employees/#{employee_id}", @options)
    
    if response.success?
      employee_data = response.parsed_response['employee']
      # キャッシュに保存
      cache_employee_info(employee_id, employee_data)
      employee_data
    else
      raise "freee API Error: #{response.message}"
    end
  end

  # 全従業員情報取得
  def get_all_employees
    response = self.class.get("/hr/api/v1/companies/#{company_id}/employees", @options)
    
    if response.success?
      response.parsed_response['employees']
    else
      raise "freee API Error: #{response.message}"
    end
  end

  # 時給情報取得
  def get_hourly_wage(employee_id)
    response = self.class.get("/hr/api/v1/employees/#{employee_id}/basic_pay_rule", @options)
    
    if response.success?
      response.parsed_response['basic_pay_rule']['base_pay']
    else
      # フォールバック値
      1000
    end
  end

  private

  def get_cached_employee_info(employee_id)
    EmployeeCache.find_by(employee_id: employee_id)
  end

  def cache_expired?(cached_info)
    cached_info.cache_expires_at < Time.current
  end

  def cache_employee_info(employee_id, employee_data)
    EmployeeCache.create!(
      employee_id: employee_id,
      name: employee_data['display_name'],
      email: employee_data['email'],
      base_pay: employee_data['base_pay'],
      cache_expires_at: 1.hour.from_now
    )
  end
end
```

### 3.2. キャッシュ戦略
```ruby
# app/models/employee_cache.rb
class EmployeeCache < ApplicationRecord
  belongs_to :employee, foreign_key: 'employee_id', primary_key: 'employee_id'

  # 期限切れキャッシュの自動削除
  scope :expired, -> { where('cache_expires_at < ?', Time.current) }
  scope :valid, -> { where('cache_expires_at > ?', Time.current) }

  def self.cleanup_expired
    expired.delete_all
  end
end
```

## 4. リレーション設計

### 4.1. 主要リレーション
```
employees (1) ←→ (1) line_users
employees (1) ←→ (N) shifts
employees (1) ←→ (N) attendance_records
employees (1) ←→ (N) salary_calculations
employees (1) ←→ (N) shift_exchanges (requester)
employees (1) ←→ (N) shift_exchanges (approver)
employees (1) ←→ (N) shift_additions (target)
employees (1) ←→ (N) notification_logs
employees (1) ←→ (N) employee_cache
shifts (1) ←→ (N) shift_exchanges
line_users (1) ←→ (N) verification_codes
```

### 4.2. 外部キー制約（実装済み）

**Phase 6-3で実装された外部キー制約:**

```sql
-- shiftsテーブルの外部キー制約
ALTER TABLE shifts ADD CONSTRAINT fk_rails_5274ef45fe 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;

ALTER TABLE shifts ADD CONSTRAINT fk_rails_original_employee_id 
  FOREIGN KEY (original_employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;

-- shift_exchangesテーブルの外部キー制約
ALTER TABLE shift_exchanges ADD CONSTRAINT fk_rails_requester_id 
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;

ALTER TABLE shift_exchanges ADD CONSTRAINT fk_rails_approver_id 
  FOREIGN KEY (approver_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;

ALTER TABLE shift_exchanges ADD CONSTRAINT fk_rails_4c15eca29f 
  FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE RESTRICT;

-- shift_additionsテーブルの外部キー制約
ALTER TABLE shift_additions ADD CONSTRAINT fk_rails_target_employee_id 
  FOREIGN KEY (target_employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;

ALTER TABLE shift_additions ADD CONSTRAINT fk_rails_requester_id 
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;

-- verification_codesテーブルの外部キー制約
ALTER TABLE verification_codes ADD CONSTRAINT fk_rails_employee_id 
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT;
```

**実装効果:**
- データ整合性の保証
- 不正なデータの挿入を防止
- データ削除時の依存関係の制御
- セキュリティの向上

## 5. データ移行計画

### 5.1. 移行順序
1. **employees** - 従業員認証情報のみ
2. **employee_cache** - 新規テーブル作成
3. **line_users** - LINEユーザー情報
4. **shifts** - シフトデータ
5. **shift_exchanges** - シフト交代管理
6. **shift_additions** - シフト追加管理
7. **verification_codes** - 認証コード
8. **attendance_records** - 勤怠記録
9. **salary_calculations** - 給与計算結果
10. **notification_logs** - 通知履歴

### 5.2. データ変換ルール
```ruby
# 従業員データの移行（認証情報のみ）
def migrate_employee_auth_data
  # 既存の認証設定シートから認証情報のみを移行
  auth_data = get_auth_settings_from_sheets
  
  auth_data.each do |row|
    Employee.create!(
      employee_id: normalize_employee_id(row[:employee_id]),
      password_hash: row[:hashed_password],
      role: determine_role(row[:employee_name]),
      password_updated_at: row[:password_last_updated],
      last_login_at: row[:last_login]
    )
  end
end

# 従業員情報はfreee APIから動的取得
def populate_employee_cache
  Employee.find_each do |employee|
    begin
      freee_service = FreeeApiService.new(access_token)
      employee_info = freee_service.get_employee_info(employee.employee_id)
      
      EmployeeCache.create!(
        employee_id: employee.employee_id,
        name: employee_info['display_name'],
        email: employee_info['email'],
        base_pay: employee_info['base_pay'],
        cache_expires_at: 1.hour.from_now
      )
    rescue => e
      Rails.logger.error "Failed to cache employee info for #{employee.employee_id}: #{e.message}"
    end
  end
end

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

## 6. パフォーマンス最適化

### 6.1. インデックス戦略
```sql
-- 複合インデックス
CREATE INDEX idx_shifts_employee_date ON shifts(employee_id, shift_date);
CREATE INDEX idx_attendance_employee_date ON attendance_records(employee_id, work_date);
CREATE INDEX idx_verification_codes_active ON verification_codes(code, expires_at) WHERE used_at IS NULL;

-- 部分インデックス
CREATE INDEX idx_employees_owners ON employees(employee_id) WHERE role = 'owner';
CREATE INDEX idx_shift_exchanges_pending ON shift_exchanges(approver_id, status) WHERE status = 'pending';

-- キャッシュ有効期限のインデックス
CREATE INDEX idx_employee_cache_expires_at ON employee_cache(cache_expires_at);
```

### 6.2. クエリ最適化
```sql
-- 従業員情報取得（キャッシュ優先）
SELECT 
  e.employee_id,
  e.role,
  COALESCE(ec.name, 'Unknown') as name,
  COALESCE(ec.email, '') as email,
  COALESCE(ec.base_pay, 1000) as base_pay
FROM employees e
LEFT JOIN employee_cache ec ON e.employee_id = ec.employee_id 
  AND ec.cache_expires_at > NOW()
WHERE e.employee_id = ?;

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

## 7. セキュリティ考慮

### 7.1. データ保護
```sql
-- パスワードハッシュの暗号化
-- bcryptを使用してハッシュ化（アプリケーションレベル）

-- 機密データのマスキング（従業員情報はfreee APIから取得）
CREATE VIEW employees_public AS
SELECT employee_id, role, last_login_at, created_at
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

### 7.2. アクセス制御
```sql
-- ロールベースアクセス制御
CREATE ROLE attendance_app_user;
CREATE ROLE attendance_app_admin;

-- 権限設定
GRANT SELECT, INSERT, UPDATE ON employees TO attendance_app_user;
GRANT ALL PRIVILEGES ON employees TO attendance_app_admin;
```

### 7.3. API セキュリティ
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :load_employee_info

  private

  def load_employee_info
    if current_user
      @current_employee_info = FreeeApiService.new(session[:freee_access_token])
        .get_employee_info(current_user.employee_id)
    end
  end
end
```

## 8. バックアップ・復旧

### 8.1. バックアップ戦略
```sql
-- 日次フルバックアップ
-- 時間別増分バックアップ
-- 重要テーブルの即座バックアップ

-- バックアップテーブル
CREATE TABLE employees_backup AS SELECT * FROM employees;
CREATE TABLE shifts_backup AS SELECT * FROM shifts;
```

### 8.2. 復旧手順
1. 最新のフルバックアップから復元
2. 増分バックアップから差分復元
3. データ整合性チェック
4. アプリケーション再起動

## 9. 監視・メンテナンス

### 9.1. 監視項目
- テーブルサイズの監視
- インデックス使用率の監視
- クエリパフォーマンスの監視
- 接続数の監視
- キャッシュヒット率の監視

### 9.2. メンテナンスタスク
```sql
-- 定期的なVACUUM
VACUUM ANALYZE;

-- インデックス再構築
REINDEX TABLE shifts;
REINDEX TABLE attendance_records;

-- 統計情報更新
ANALYZE;

-- 期限切れキャッシュの定期削除
-- 毎時実行されるバッチ処理で期限切れキャッシュを削除
```

## 10. 運用フロー

### 10.1. 初期設定
1. 従業員認証情報の移行
2. freee API接続の設定
3. 初期キャッシュの作成
4. データ整合性の確認

### 10.2. 日常運用
1. ログイン時: 認証情報確認 + freee APIから従業員情報取得
2. キャッシュの自動更新（1時間間隔）
3. 期限切れキャッシュの自動削除
4. freee API障害時のフォールバック処理

### 10.3. メンテナンス
1. キャッシュの定期クリーンアップ
2. freee API接続状況の監視
3. データ整合性の定期チェック
4. パフォーマンス監視

## 11. 移行後の検証

### 11.1. データ整合性チェック
```sql
-- 認証情報の確認
SELECT COUNT(*) FROM employees;
-- 期待値: 既存の従業員数と一致

-- キャッシュの確認
SELECT COUNT(*) FROM employee_cache WHERE cache_expires_at > NOW();
-- 期待値: 全従業員のキャッシュが存在

-- freee API連携の確認
-- 各従業員の情報がfreee APIから正しく取得できることを確認
```

### 11.2. 機能テスト
- 認証フローの動作確認
- freee APIからの情報取得確認
- キャッシュ機能の動作確認
- シフト確認機能の動作確認
- 勤怠確認機能の動作確認
- 103万の壁ゲージの動作確認

## 12. 今後の拡張性

### 12.1. 追加予定テーブル
```sql
-- API呼び出しログテーブル
CREATE TABLE api_call_logs (
  id SERIAL PRIMARY KEY,
  api_endpoint VARCHAR(255) NOT NULL,
  employee_id VARCHAR(7),
  response_code INTEGER,
  response_time INTEGER,  -- ミリ秒
  error_message TEXT,
  called_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- システム設定テーブル
CREATE TABLE system_settings (
  id SERIAL PRIMARY KEY,
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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
```

### 12.2. パフォーマンス改善
- キャッシュの階層化（Redis導入）
- 読み取り専用レプリカの構築
- API呼び出しの最適化
- バックグラウンド処理の強化

この設計により、freee APIを唯一の情報源として活用し、データの重複を排除しながら、パフォーマンスとメンテナンス性を大幅に向上させることができます。