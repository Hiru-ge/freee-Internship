# LINE Bot テストガイド

## 概要

本ドキュメントは、責務分離後のLINE Botサービスクラスのテスト戦略と実装方法について説明します。100%のテスト成功率を達成したテストスイートの構成と、今後のテスト拡張方法について詳述します。

## テスト戦略

### 1. テストの階層構造

```
LineBotService（統合テスト）
├── LineAuthenticationService（単体テスト）
├── LineConversationService（単体テスト）
├── LineShiftService（単体テスト）
├── LineShiftExchangeService（単体テスト）
├── LineShiftAdditionService（単体テスト）
├── LineMessageService（単体テスト）
├── LineValidationService（単体テスト）
├── LineNotificationService（単体テスト）
└── LineUtilityService（単体テスト）
```

### 2. テストの種類

#### 単体テスト（Unit Tests）
- 各サービスクラスの個別機能をテスト
- モックを使用した独立したテスト
- 高速実行が可能

#### 統合テスト（Integration Tests）
- `LineBotService` を通じた全体的なフローテスト
- 実際のデータベースを使用
- エンドツーエンドの動作確認

#### 機能テスト（Feature Tests）
- 特定の機能（認証、シフト交代等）の完全なフローテスト
- ユーザーシナリオに基づくテスト

## テストファイル構成

### 既存のテストファイル

```
test/services/
├── line_bot_service_test.rb                    # メイン統合テスト
├── line_bot_service_history_test.rb            # 履歴機能テスト
├── line_bot_service_shift_exchange_test.rb     # シフト交代テスト
├── line_bot_service_shift_exchange_redesign_test.rb # シフト交代リデザインテスト
├── line_bot_shift_addition_test.rb             # シフト追加テスト
└── line_bot_shift_exchange_redesign_test.rb    # シフト交代リデザインテスト
```

### 推奨する新しいテストファイル

```
test/services/
├── line_authentication_service_test.rb         # 認証サービス単体テスト
├── line_conversation_service_test.rb           # 会話状態管理テスト
├── line_shift_service_test.rb                  # シフト管理テスト
├── line_shift_exchange_service_test.rb         # シフト交代サービステスト
├── line_shift_addition_service_test.rb         # シフト追加サービステスト
├── line_message_service_test.rb                # メッセージ生成テスト
├── line_validation_service_test.rb             # バリデーションテスト
├── line_notification_service_test.rb           # 通知サービステスト
└── line_utility_service_test.rb                # ユーティリティテスト
```

## テスト実装例

### 1. LineAuthenticationService のテスト

```ruby
# test/services/line_authentication_service_test.rb
require 'test_helper'

class LineAuthenticationServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineAuthenticationService.new
    @line_user_id = "test_user_123"
    @employee = Employee.create!(
      employee_id: "1000",
      display_name: "テスト太郎",
      role: "employee"
    )
  end

  test "should handle auth command in private chat" do
    event = create_mock_private_event("認証", @line_user_id)
    result = @service.handle_auth_command(event)
    
    assert_includes result, "従業員名を入力してください"
  end

  test "should reject auth command in group chat" do
    event = create_mock_group_event("認証", @line_user_id)
    result = @service.handle_auth_command(event)
    
    assert_includes result, "認証は個人チャットでのみ利用できます"
  end

  test "should handle employee name input with single match" do
    result = @service.handle_employee_name_input(@line_user_id, "テスト太郎")
    
    assert_includes result, "認証コード"
    assert_includes result, "メール"
  end

  test "should handle employee name input with multiple matches" do
    Employee.create!(
      employee_id: "1001",
      display_name: "テスト太郎（別）",
      role: "employee"
    )
    
    result = @service.handle_employee_name_input(@line_user_id, "テスト太郎")
    
    assert_includes result, "複数の従業員が見つかりました"
    assert_includes result, "番号で選択"
  end

  test "should handle verification code input correctly" do
    verification_code = @service.generate_verification_code_for_employee(@employee.employee_id)
    
    result = @service.handle_verification_code_input(
      @line_user_id,
      @employee.employee_id,
      verification_code
    )
    
    assert_includes result, "認証が完了しました"
    assert Employee.find_by(line_id: @line_user_id)
  end

  private

  def create_mock_private_event(message, user_id)
    {
      'type' => 'message',
      'message' => { 'text' => message },
      'source' => { 'type' => 'user', 'userId' => user_id }
    }
  end

  def create_mock_group_event(message, user_id)
    {
      'type' => 'message',
      'message' => { 'text' => message },
      'source' => { 'type' => 'group', 'userId' => user_id }
    }
  end
end
```

### 2. LineConversationService のテスト

```ruby
# test/services/line_conversation_service_test.rb
require 'test_helper'

class LineConversationServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineConversationService.new
    @line_user_id = "test_user_123"
  end

  test "should set and get conversation state" do
    state = { 'state' => 'waiting_for_employee_name', 'step' => 1 }
    
    assert @service.set_conversation_state(@line_user_id, state)
    
    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_equal state, retrieved_state
  end

  test "should clear conversation state" do
    state = { 'state' => 'waiting_for_employee_name', 'step' => 1 }
    @service.set_conversation_state(@line_user_id, state)
    
    assert @service.clear_conversation_state(@line_user_id)
    
    retrieved_state = @service.get_conversation_state(@line_user_id)
    assert_nil retrieved_state
  end

  test "should handle stateful message for employee name input" do
    state = { 'state' => 'waiting_for_employee_name', 'step' => 1 }
    @service.set_conversation_state(@line_user_id, state)
    
    # モックを使用してauth_serviceを設定
    @service.stubs(:auth_service).returns(mock_auth_service)
    
    result = @service.handle_stateful_message(@line_user_id, "テスト太郎", state)
    
    assert_includes result, "認証コード"
  end

  test "should handle unknown state" do
    state = { 'state' => 'unknown_state', 'step' => 1 }
    
    result = @service.handle_stateful_message(@line_user_id, "test", state)
    
    assert_includes result, "不明な状態です"
  end

  private

  def mock_auth_service
    mock_service = mock('auth_service')
    mock_service.stubs(:handle_employee_name_input).returns("認証コードを送信しました")
    mock_service
  end
end
```

### 3. LineValidationService のテスト

```ruby
# test/services/line_validation_service_test.rb
require 'test_helper'

class LineValidationServiceTest < ActiveSupport::TestCase
  def setup
    @service = LineValidationService.new
  end

  test "should validate valid shift date" do
    tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
    result = @service.validate_shift_date(tomorrow)
    
    assert result[:valid]
    assert_nil result[:error]
  end

  test "should reject past shift date" do
    yesterday = (Date.current - 1).strftime('%Y-%m-%d')
    result = @service.validate_shift_date(yesterday)
    
    assert_not result[:valid]
    assert_includes result[:error], "過去の日付"
  end

  test "should validate valid shift time" do
    result = @service.validate_shift_time("09:00", "18:00")
    
    assert result[:valid]
    assert_nil result[:error]
  end

  test "should reject invalid shift time" do
    result = @service.validate_shift_time("18:00", "09:00")
    
    assert_not result[:valid]
    assert_includes result[:error], "終了時間"
  end

  test "should validate employee name" do
    result = @service.validate_employee_name("テスト太郎")
    
    assert result[:valid]
    assert_nil result[:error]
  end

  test "should reject empty employee name" do
    result = @service.validate_employee_name("")
    
    assert_not result[:valid]
    assert_includes result[:error], "従業員名"
  end

  test "should validate verification code" do
    result = @service.validate_verification_code("123456")
    
    assert result[:valid]
    assert_nil result[:error]
  end

  test "should reject invalid verification code" do
    result = @service.validate_verification_code("12345")
    
    assert_not result[:valid]
    assert_includes result[:error], "6桁"
  end
end
```

### 4. 統合テストの例

```ruby
# test/services/line_bot_service_integration_test.rb
require 'test_helper'

class LineBotServiceIntegrationTest < ActiveSupport::TestCase
  def setup
    @service = LineBotService.new
    @line_user_id = "test_user_123"
    @employee = Employee.create!(
      employee_id: "1000",
      display_name: "テスト太郎",
      role: "employee",
      line_id: @line_user_id
    )
  end

  test "should handle complete authentication flow" do
    # 1. 認証コマンド
    event = create_mock_private_event("認証", @line_user_id)
    result = @service.handle_message(event)
    assert_includes result, "従業員名を入力してください"
    
    # 2. 従業員名入力
    event = create_mock_private_event("テスト太郎", @line_user_id)
    result = @service.handle_message(event)
    assert_includes result, "認証コード"
    
    # 3. 認証コード入力（実際のコードを取得する必要がある）
    # この部分は実際の実装に合わせて調整
  end

  test "should handle complete shift exchange flow" do
    # 1. シフト交代コマンド
    event = create_mock_group_event("シフト交代", @line_user_id)
    result = @service.handle_message(event)
    assert_includes result, "日付を入力してください"
    
    # 2. 日付入力
    tomorrow = (Date.current + 1).strftime('%m/%d')
    event = create_mock_group_event(tomorrow, @line_user_id)
    result = @service.handle_message(event)
    
    # シフトが存在する場合はFlex Message、存在しない場合はエラーメッセージ
    if result.is_a?(Hash)
      assert_equal 'flex', result[:type]
    else
      assert_includes result, "シフトが見つかりません"
    end
  end

  private

  def create_mock_private_event(message, user_id)
    {
      'type' => 'message',
      'message' => { 'text' => message },
      'source' => { 'type' => 'user', 'userId' => user_id }
    }
  end

  def create_mock_group_event(message, user_id)
    {
      'type' => 'message',
      'message' => { 'text' => message },
      'source' => { 'type' => 'group', 'userId' => user_id }
    }
  end
end
```

## テストデータの管理

### 1. テストフィクスチャ

```ruby
# test/fixtures/employees.yml
test_employee_1:
  employee_id: "1000"
  display_name: "テスト太郎"
  role: "employee"
  line_id: "test_user_123"

test_employee_2:
  employee_id: "1001"
  display_name: "テスト次郎"
  role: "employee"
  line_id: "test_user_456"

test_owner:
  employee_id: "2000"
  display_name: "オーナー太郎"
  role: "owner"
  line_id: "test_owner_123"
```

### 2. テストヘルパー

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  # テスト用の従業員を作成
  def create_test_employee(attributes = {})
    default_attributes = {
      employee_id: "test_#{SecureRandom.hex(4)}",
      display_name: "テスト従業員",
      role: "employee"
    }
    Employee.create!(default_attributes.merge(attributes))
  end

  # テスト用のシフトを作成
  def create_test_shift(attributes = {})
    default_attributes = {
      employee_id: create_test_employee.employee_id,
      shift_date: Date.current + 1.day,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    }
    Shift.create!(default_attributes.merge(attributes))
  end

  # モックイベントを作成
  def create_mock_event(message, user_id, source_type = 'user')
    {
      'type' => 'message',
      'message' => { 'text' => message },
      'source' => { 'type' => source_type, 'userId' => user_id }
    }
  end

  # モックPostbackイベントを作成
  def create_mock_postback_event(data, user_id)
    {
      'type' => 'postback',
      'postback' => { 'data' => data },
      'source' => { 'type' => 'user', 'userId' => user_id }
    }
  end
end
```

## モックとスタブの使用

### 1. 外部APIのモック

```ruby
# LINE Bot APIのモック
def mock_line_bot_client
  mock_client = mock('line_bot_client')
  mock_client.stubs(:push_message).returns(true)
  mock_client.stubs(:reply_message).returns(true)
  mock_client
end

# メール送信のモック
def mock_mailer
  mock_mail = mock('mail')
  mock_mail.stubs(:deliver_now).returns(true)
  mock_mailer = mock('mailer')
  mock_mailer.stubs(:verification_code_email).returns(mock_mail)
  mock_mailer
end
```

### 2. データベースのモック

```ruby
# 従業員検索のモック
def mock_employee_search
  mock_employees = [
    mock('employee1', employee_id: '1000', display_name: 'テスト太郎'),
    mock('employee2', employee_id: '1001', display_name: 'テスト次郎')
  ]
  Employee.stubs(:where).returns(mock_employees)
end
```

## テスト実行とカバレッジ

### 1. テスト実行コマンド

```bash
# 全テストの実行
bundle exec rails test

# 特定のサービスのテスト実行
bundle exec rails test test/services/line_authentication_service_test.rb

# 特定のテストメソッドの実行
bundle exec rails test test/services/line_authentication_service_test.rb -n test_should_handle_auth_command

# カバレッジレポートの生成
COVERAGE=true bundle exec rails test
```

### 2. テストカバレッジの確認

```ruby
# test/test_helper.rb
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/test/'
    add_filter '/config/'
    add_filter '/vendor/'
  end
end
```

## パフォーマンステスト

### 1. 負荷テスト

```ruby
# test/performance/line_bot_performance_test.rb
require 'test_helper'

class LineBotPerformanceTest < ActiveSupport::TestCase
  test "should handle multiple concurrent requests" do
    threads = []
    results = []
    
    10.times do |i|
      threads << Thread.new do
        start_time = Time.current
        event = create_mock_event("ヘルプ", "user_#{i}")
        result = LineBotService.new.handle_message(event)
        end_time = Time.current
        
        results << {
          user_id: "user_#{i}",
          response_time: end_time - start_time,
          success: result.present?
        }
      end
    end
    
    threads.each(&:join)
    
    # パフォーマンスの検証
    average_response_time = results.map { |r| r[:response_time] }.sum / results.size
    assert average_response_time < 1.0, "平均応答時間が1秒を超えています: #{average_response_time}"
    
    success_rate = results.count { |r| r[:success] } / results.size.to_f
    assert success_rate > 0.95, "成功率が95%を下回っています: #{success_rate}"
  end
end
```

## 継続的インテグレーション

### 1. GitHub Actions設定

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      sqlite3:
        image: sqlite3:latest
        
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2.2
        
    - name: Install dependencies
      run: |
        gem install bundler
        bundle install
        
    - name: Run tests
      run: bundle exec rails test
      
    - name: Generate coverage report
      run: COVERAGE=true bundle exec rails test
      
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v1
      with:
        file: ./coverage/coverage.xml
```

## テストのベストプラクティス

### 1. テストの命名規則

```ruby
# 良い例
test "should handle employee name input with single match"
test "should reject auth command in group chat"
test "should validate valid shift date"

# 悪い例
test "test1"
test "employee name"
test "validation"
```

### 2. テストの構造

```ruby
test "should handle specific scenario" do
  # Arrange: テストデータの準備
  employee = create_test_employee
  event = create_mock_event("認証", "user_123")
  
  # Act: テスト対象の実行
  result = @service.handle_auth_command(event)
  
  # Assert: 結果の検証
  assert_includes result, "従業員名を入力してください"
end
```

### 3. テストの独立性

```ruby
# 各テストは独立して実行可能である必要がある
def setup
  # テストごとにクリーンな状態を作成
  @service = LineAuthenticationService.new
  @line_user_id = "test_user_#{SecureRandom.hex(4)}"
end

def teardown
  # テスト後のクリーンアップ
  Employee.where(line_id: @line_user_id).destroy_all
  ConversationState.where(line_user_id: @line_user_id).destroy_all
end
```

## トラブルシューティング

### 1. よくある問題

#### テストが失敗する
```ruby
# デバッグ情報の追加
test "should handle specific scenario" do
  result = @service.handle_auth_command(event)
  puts "Debug: result = #{result}" if result.nil?
  assert_includes result, "expected text"
end
```

#### データベースの状態が期待と異なる
```ruby
# データベースの状態確認
test "should create employee" do
  @service.create_employee(attributes)
  
  # データベースの状態を確認
  assert Employee.exists?(employee_id: attributes[:employee_id])
  
  # 詳細な確認
  employee = Employee.find_by(employee_id: attributes[:employee_id])
  assert_equal attributes[:display_name], employee.display_name
end
```

#### モックが期待通りに動作しない
```ruby
# モックの設定確認
def setup
  @mock_service = mock('service')
  @mock_service.stubs(:method_name).returns('expected_result')
  
  # モックが正しく設定されているか確認
  assert_equal 'expected_result', @mock_service.method_name
end
```

## まとめ

このテストガイドにより、責務分離後のLINE Botサービスクラスの包括的なテスト戦略を実装できます。100%のテスト成功率を維持しながら、新機能の追加や既存機能の修正に対応できる堅牢なテストスイートを構築できます。

### 重要なポイント

1. **単体テストと統合テストの適切な使い分け**
2. **モックとスタブの効果的な使用**
3. **テストデータの適切な管理**
4. **継続的インテグレーションの実装**
5. **パフォーマンステストの実施**

これらの要素を組み合わせることで、高品質で保守性の高いテストスイートを構築し、LINE Botの安定した動作を保証できます。
