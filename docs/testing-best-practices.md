# テスト実装ベストプラクティス

## 概要

このドキュメントでは、freee-Internshipプロジェクトでのテスト実装におけるベストプラクティスとノウハウをまとめています。特に外部API連携、モック、時間操作などの実装パターンについて詳しく説明します。

## 目次

1. [テストクラスの選択](#テストクラスの選択)
2. [外部APIのモック実装](#外部apiのモック実装)
3. [時間操作とテスト](#時間操作とテスト)
4. [データベース操作のテスト](#データベース操作のテスト)
5. [メール送信のテスト](#メール送信のテスト)
6. [エラーハンドリングのテスト](#エラーハンドリングのテスト)
7. [実装例とパターン](#実装例とパターン)

## テストクラスの選択

### メール送信を含むテスト

メール送信をテストする場合は、`ActionMailer::TestCase`を継承します。

```ruby
class ClockReminderServiceTest < ActionMailer::TestCase
  # assert_emails, assert_no_emails が使用可能
end
```

### 一般的なサービステスト

通常のサービスロジックのテストでは、`ActiveSupport::TestCase`を継承します。

```ruby
class SomeServiceTest < ActiveSupport::TestCase
  # 基本的なアサーションが使用可能
end
```

### ジョブテスト

バックグラウンドジョブのテストでは、`ActiveJob::TestCase`を継承します。

```ruby
class ClockReminderJobTest < ActiveJob::TestCase
  # perform_enqueued_jobs が使用可能
end
```

## 外部APIのモック実装

### 基本的なモックパターン

外部APIサービスをモックする際は、実際のメソッドシグネチャに合わせて実装します。

```ruby
def mock_freee_api_service
  mock_service = Object.new
  
  # 従業員情報取得
  def mock_service.get_employee_info(employee_id)
    {
      'display_name' => 'テスト従業員',
      'email' => 'test@example.com'
    }
  end
  
  # 全従業員情報取得
  def mock_service.get_employees_full
    [
      {
        'id' => 123,
        'display_name' => 'テスト従業員',
        'email' => 'test@example.com'
      }
    ]
  end
  
  # 打刻記録取得（3つの引数に注意）
  def mock_service.get_time_clocks(employee_id, start_date, end_date)
    []  # 打刻記録なし
  end
  
  mock_service
end
```

### 複数のモックパターン

異なるテストケースに対応するため、複数のモックパターンを用意します。

```ruby
# 打刻ありのパターン
def mock_freee_api_service_with_clock_in
  mock_service = Object.new
  
  def mock_service.get_time_clocks(employee_id, start_date, end_date)
    [
      { 'type' => 'clock_in', 'datetime' => '2024-01-01T09:00:00+09:00' }
    ]
  end
  
  # 他のメソッドは基本パターンと同じ
  mock_service
end

# 退勤打刻ありのパターン
def mock_freee_api_service_with_clock_out
  mock_service = Object.new
  
  def mock_service.get_time_clocks(employee_id, start_date, end_date)
    [
      { 'type' => 'clock_in', 'datetime' => '2024-01-01T09:00:00+09:00' },
      { 'type' => 'clock_out', 'datetime' => '2024-01-01T18:00:00+09:00' }
    ]
  end
  
  mock_service
end
```

### モックの適用方法

```ruby
test "出勤打刻忘れチェック - 打刻なしの場合にメール送信される" do
  travel_to @shift.start_time + 30.minutes do
    # シフトの日付を現在の日付に更新
    @shift.update!(shift_date: Date.current)
    
    # FreeeApiServiceのモック
    mock_freee_service = mock_freee_api_service
    @service.instance_variable_set(:@freee_service, mock_freee_service)
    
    # メール送信をテスト
    assert_emails 1 do
      @service.send(:check_forgotten_clock_ins)
    end
  end
end
```

## 時間操作とテスト

### travel_toの使用

時間に依存するテストでは、`travel_to`を使用して時間を固定します。

```ruby
test "特定の時間でのテスト" do
  travel_to Time.new(2024, 1, 1, 9, 30, 0) do
    # このブロック内では時間が固定される
    assert_equal Time.current, Time.new(2024, 1, 1, 9, 30, 0)
  end
end
```

### 日付の注意点

`travel_to`は`Time.current`には影響しますが、`Date.current`には影響しません。

```ruby
# ❌ 間違い: Date.currentはtravel_toの影響を受けない
@shift = Shift.create!(
  shift_date: Date.new(2000, 1, 1)  # 固定日付
)

# ✅ 正しい: テスト内で日付を更新
travel_to @shift.start_time + 30.minutes do
  @shift.update!(shift_date: Date.current)  # 現在の日付に更新
end
```

### 時間計算のテスト

```ruby
test "15分経過後のチェック" do
  # シフト開始時刻の30分後（15分経過後の条件を満たす）
  travel_to @shift.start_time + 30.minutes do
    # テスト実行
  end
end

test "15分経過前のチェック" do
  # シフト開始時刻の10分後（15分経過前）
  travel_to @shift.start_time + 10.minutes do
    # テスト実行
  end
end
```

## データベース操作のテスト

### テストデータの準備

```ruby
def setup
  @employee = Employee.create!(
    employee_id: 123,
    role: 'employee'
  )
  
  @shift = Shift.create!(
    employee_id: 123,
    shift_date: Date.new(2000, 1, 1),  # テスト用の固定日付
    start_time: Time.new(2000, 1, 1, 9, 0, 0),  # 9:00
    end_time: Time.new(2000, 1, 1, 18, 0, 0)    # 18:00
  )
  
  @service = ClockReminderService.new
end
```

### データベースのクリーンアップ

Railsのテストでは、各テスト後にデータベースが自動的にクリーンアップされます。

## メール送信のテスト

### メール送信のアサーション

```ruby
# メールが送信されることをテスト
assert_emails 1 do
  @service.send(:check_forgotten_clock_ins)
end

# メールが送信されないことをテスト
assert_no_emails do
  @service.send(:check_forgotten_clock_ins)
end
```

### メール内容のテスト

```ruby
test "メール内容の確認" do
  assert_emails 1 do
    @service.send(:check_forgotten_clock_ins)
  end
  
  mail = ActionMailer::Base.deliveries.last
  assert_equal '出勤打刻のお知らせ', mail.subject
  assert_equal 'test@example.com', mail.to.first
end
```

## エラーハンドリングのテスト

### 例外処理のテスト

```ruby
test "API呼び出しエラーの処理" do
  # エラーを発生させるモック
  mock_service = Object.new
  def mock_service.get_time_clocks(employee_id, start_date, end_date)
    raise StandardError, "API Error"
  end
  
  @service.instance_variable_set(:@freee_service, mock_service)
  
  # エラーが発生しても処理が継続されることをテスト
  assert_nothing_raised do
    @service.send(:check_forgotten_clock_ins)
  end
end
```

## 実装例とパターン

### 完全なテストクラスの例

```ruby
require 'test_helper'

class ClockReminderServiceTest < ActionMailer::TestCase
  def setup
    @employee = Employee.create!(
      employee_id: 123,
      role: 'employee'
    )
    
    @shift = Shift.create!(
      employee_id: 123,
      shift_date: Date.new(2000, 1, 1),
      start_time: Time.new(2000, 1, 1, 9, 0, 0),
      end_time: Time.new(2000, 1, 1, 18, 0, 0)
    )
    
    @service = ClockReminderService.new
  end

  test "正常ケースのテスト" do
    travel_to @shift.start_time + 30.minutes do
      @shift.update!(shift_date: Date.current)
      
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      assert_emails 1 do
        @service.send(:check_forgotten_clock_ins)
      end
    end
  end

  test "異常ケースのテスト" do
    travel_to @shift.start_time + 10.minutes do
      @shift.update!(shift_date: Date.current)
      
      mock_freee_service = mock_freee_api_service
      @service.instance_variable_set(:@freee_service, mock_freee_service)
      
      assert_no_emails do
        @service.send(:check_forgotten_clock_ins)
      end
    end
  end

  private

  def mock_freee_api_service
    mock_service = Object.new
    def mock_service.get_employee_info(employee_id)
      {
        'display_name' => 'テスト従業員',
        'email' => 'test@example.com'
      }
    end
    
    def mock_service.get_employees_full
      [
        {
          'id' => 123,
          'display_name' => 'テスト従業員',
          'email' => 'test@example.com'
        }
      ]
    end
    
    def mock_service.get_time_clocks(employee_id, start_date, end_date)
      []
    end
    
    mock_service
  end
end
```

### よくある間違いと解決方法

#### 1. メソッドシグネチャの不一致

```ruby
# ❌ 間違い: 引数の数が合わない
def mock_service.get_time_clocks(employee_id, date)
  []
end

# ✅ 正しい: 実際のメソッドシグネチャに合わせる
def mock_service.get_time_clocks(employee_id, start_date, end_date)
  []
end
```

#### 2. 日付の扱い

```ruby
# ❌ 間違い: Date.currentがtravel_toの影響を受けない
@shift = Shift.create!(shift_date: Date.new(2000, 1, 1))

# ✅ 正しい: テスト内で日付を更新
travel_to some_time do
  @shift.update!(shift_date: Date.current)
end
```

#### 3. モックメソッドの不足

```ruby
# ❌ 間違い: 必要なメソッドがモックされていない
def mock_service.get_employee_info(employee_id)
  # メソッドのみ
end

# ✅ 正しい: 使用される全てのメソッドをモック
def mock_service.get_employee_info(employee_id)
  # メソッド
end

def mock_service.get_employees_full
  # メソッド
end

def mock_service.get_time_clocks(employee_id, start_date, end_date)
  # メソッド
end
```

## まとめ

このドキュメントで説明したパターンに従うことで、外部API連携を含む複雑なサービスのテストを効率的に実装できます。特に以下の点に注意してください：

1. **適切なテストクラスの選択**
2. **外部APIの完全なモック実装**
3. **時間操作の正しい扱い**
4. **メソッドシグネチャの一致**
5. **エラーハンドリングのテスト**

これらのパターンを参考に、プロジェクト全体で一貫したテスト実装を行ってください。
