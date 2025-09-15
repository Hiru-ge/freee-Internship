# LINE Bot連携 データベース設計

## 概要

LINE Bot連携機能のためのデータベース設計について説明します。Phase 9-1で実装予定のデータベース変更について詳細に記載しています。

## 設計方針

### 1. シンプルな設計
- 複雑な中間テーブルを避け、保守性を重視
- 1対1の関係性を活用したシンプルな構造
- 既存のEmployeeテーブルを拡張する方針

### 2. データ整合性
- 外部キー制約による参照整合性の保証
- ユニーク制約による重複防止
- 適切なインデックスの設定

### 3. 監査証跡
- メッセージ履歴の完全な記録
- デバッグ・トラブルシューティングの支援
- セキュリティ監査の実現

## データベース変更内容

### Employeeテーブルの拡張

#### 追加カラム
```sql
ALTER TABLE employees ADD COLUMN line_id VARCHAR(255);
CREATE UNIQUE INDEX index_employees_on_line_id ON employees(line_id);
```

#### カラム仕様
- **line_id**: VARCHAR(255), NULL許可, ユニーク制約
- **用途**: LINEユーザーIDの格納
- **制約**: 1人の従業員につき1つのLINEアカウントのみ紐付け可能

#### 設計理由
1. **1対1関係**: 1人の従業員 = 1つのLINEアカウントの関係
2. **シンプル性**: 複雑な中間テーブルを避ける
3. **パフォーマンス**: JOIN処理の削減
4. **保守性**: 既存のEmployeeモデルとの統合

### LineMessageLogテーブルの新規作成

#### テーブル定義
```sql
CREATE TABLE line_message_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  line_user_id VARCHAR(255) NOT NULL,
  message_type VARCHAR(50) NOT NULL,
  message_content TEXT,
  direction VARCHAR(20) NOT NULL,
  processed_at DATETIME,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE INDEX index_line_message_logs_on_line_user_id ON line_message_logs(line_user_id);
CREATE INDEX index_line_message_logs_on_processed_at ON line_message_logs(processed_at);
CREATE INDEX index_line_message_logs_on_direction ON line_message_logs(direction);
```

#### カラム仕様

| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| id | INTEGER | PRIMARY KEY | 主キー |
| line_user_id | VARCHAR(255) | NOT NULL | LINEユーザーID |
| message_type | VARCHAR(50) | NOT NULL | メッセージタイプ（text, image, etc.） |
| message_content | TEXT | NULL許可 | メッセージ内容 |
| direction | VARCHAR(20) | NOT NULL | 送信方向（inbound, outbound） |
| processed_at | DATETIME | NULL許可 | 処理日時 |
| created_at | DATETIME | NOT NULL | 作成日時 |
| updated_at | DATETIME | NOT NULL | 更新日時 |

#### 設計理由
1. **監査証跡**: 全てのメッセージの記録
2. **デバッグ支援**: 問題発生時の原因特定
3. **セキュリティ**: 不正アクセスの検出
4. **分析**: 利用状況の分析と改善

## マイグレーション実装

### マイグレーションファイル

#### 1. Employeeテーブル拡張
```ruby
# db/migrate/YYYYMMDDHHMMSS_add_line_id_to_employees.rb
class AddLineIdToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :employees, :line_id, :string
    add_index :employees, :line_id, unique: true
  end
end
```

#### 2. LineMessageLogテーブル作成
```ruby
# db/migrate/YYYYMMDDHHMMSS_create_line_message_logs.rb
class CreateLineMessageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :line_message_logs do |t|
      t.string :line_user_id, null: false
      t.string :message_type, null: false
      t.text :message_content
      t.string :direction, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :line_message_logs, :line_user_id
    add_index :line_message_logs, :processed_at
    add_index :line_message_logs, :direction
  end
end
```

## モデル実装

### Employeeモデルの拡張

```ruby
# app/models/employee.rb
class Employee < ApplicationRecord
  # 既存のバリデーション
  validates :employee_id, presence: true, uniqueness: true
  validates :password_hash, presence: true
  validates :role, presence: true, inclusion: { in: %w[employee owner] }
  
  # LINE関連のバリデーション
  validates :line_id, uniqueness: true, allow_nil: true
  
  # LINE関連のメソッド
  def linked_to_line?
    line_id.present?
  end
  
  def link_to_line(line_user_id)
    update!(line_id: line_user_id)
  end
  
  def unlink_from_line
    update!(line_id: nil)
  end
  
  # 関連
  has_many :line_message_logs, foreign_key: :line_user_id, primary_key: :line_id
end
```

### LineMessageLogモデル

```ruby
# app/models/line_message_log.rb
class LineMessageLog < ApplicationRecord
  # バリデーション
  validates :line_user_id, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[text image sticker location] }
  validates :direction, presence: true, inclusion: { in: %w[inbound outbound] }
  
  # 関連
  belongs_to :employee, foreign_key: :line_user_id, primary_key: :line_id, optional: true
  
  # スコープ
  scope :inbound, -> { where(direction: 'inbound') }
  scope :outbound, -> { where(direction: 'outbound') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(line_user_id) { where(line_user_id: line_user_id) }
  
  # クラスメソッド
  def self.log_inbound_message(line_user_id, message_type, content)
    create!(
      line_user_id: line_user_id,
      message_type: message_type,
      message_content: content,
      direction: 'inbound',
      processed_at: Time.current
    )
  end
  
  def self.log_outbound_message(line_user_id, message_type, content)
    create!(
      line_user_id: line_user_id,
      message_type: message_type,
      message_content: content,
      direction: 'outbound',
      processed_at: Time.current
    )
  end
end
```

## データ整合性

### 外部キー制約
```sql
-- LineMessageLogからEmployeeへの参照（オプショナル）
-- 注意: line_idがNULLの場合は参照できないため、外部キー制約は設定しない
```

### データクリーンアップ
```ruby
# 定期的なデータクリーンアップ（将来実装）
class LineMessageLogCleanupJob < ApplicationJob
  def perform
    # 30日以上古いログを削除
    LineMessageLog.where('created_at < ?', 30.days.ago).delete_all
  end
end
```

## パフォーマンス考慮

### インデックス戦略
1. **line_user_id**: ユーザー別のメッセージ検索
2. **processed_at**: 時系列でのメッセージ検索
3. **direction**: 送信方向別の検索
4. **created_at**: 作成日時でのソート

### クエリ最適化
```ruby
# 効率的なクエリ例
def recent_messages_for_user(line_user_id, limit = 10)
  LineMessageLog.by_user(line_user_id)
                .recent
                .limit(limit)
end

def message_statistics(line_user_id)
  LineMessageLog.by_user(line_user_id)
                .group(:direction, :message_type)
                .count
end
```

## セキュリティ考慮

### データ保護
- 個人情報の適切な分離
- メッセージ内容の暗号化（将来実装）
- アクセスログの記録

### プライバシー
- メッセージ内容の最小限の記録
- 定期的なデータクリーンアップ
- ユーザーの削除要求への対応

## テスト戦略

### モデルテスト
```ruby
# test/models/employee_test.rb
class EmployeeTest < ActiveSupport::TestCase
  test "should link to line account" do
    employee = employees(:one)
    line_user_id = "U1234567890abcdef"
    
    employee.link_to_line(line_user_id)
    
    assert_equal line_user_id, employee.line_id
    assert employee.linked_to_line?
  end
  
  test "should not allow duplicate line_id" do
    employee1 = employees(:one)
    employee2 = employees(:two)
    line_user_id = "U1234567890abcdef"
    
    employee1.link_to_line(line_user_id)
    
    assert_raises(ActiveRecord::RecordInvalid) do
      employee2.link_to_line(line_user_id)
    end
  end
end
```

### 統合テスト
```ruby
# test/integration/line_bot_database_test.rb
class LineBotDatabaseTest < ActionDispatch::IntegrationTest
  test "should log inbound and outbound messages" do
    line_user_id = "U1234567890abcdef"
    
    # 受信メッセージのログ
    LineMessageLog.log_inbound_message(line_user_id, "text", "Hello")
    
    # 送信メッセージのログ
    LineMessageLog.log_outbound_message(line_user_id, "text", "Hi there")
    
    assert_equal 2, LineMessageLog.by_user(line_user_id).count
    assert_equal 1, LineMessageLog.by_user(line_user_id).inbound.count
    assert_equal 1, LineMessageLog.by_user(line_user_id).outbound.count
  end
end
```

## 今後の拡張予定

### Phase 9-2以降での追加機能
1. **メッセージテンプレート管理**
2. **ユーザー行動分析**
3. **自動応答機能**
4. **通知設定の管理**

### パフォーマンス改善
1. **メッセージログのアーカイブ機能**
2. **バッチ処理による一括操作**
3. **キャッシュ戦略の実装**

## 関連ファイル

- `db/migrate/YYYYMMDDHHMMSS_add_line_id_to_employees.rb`
- `db/migrate/YYYYMMDDHHMMSS_create_line_message_logs.rb`
- `app/models/employee.rb`
- `app/models/line_message_log.rb`
- `test/models/employee_test.rb`
- `test/models/line_message_log_test.rb`
- `test/integration/line_bot_database_test.rb`
