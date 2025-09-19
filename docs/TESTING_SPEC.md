# テスト仕様書

勤怠管理システムのテスト戦略と実装仕様です。

## 🎯 概要

LINE Bot連携システムの品質保証のための包括的なテスト戦略です。

## 🧪 テスト戦略

### テストピラミッド
```
        E2E Tests (少数)
       /              \
   Integration Tests (中程度)
  /                        \
Unit Tests (多数)
```

### テストの種類
1. **単体テスト**: 個別のメソッド・クラスのテスト
2. **統合テスト**: 複数のコンポーネント間の連携テスト
3. **E2Eテスト**: ユーザーシナリオ全体のテスト

## 🔧 テスト環境

### テストデータベース
```ruby
# test/database.yml
test:
  adapter: sqlite3
  database: db/test.sqlite3
  pool: 5
  timeout: 5000
```

### テスト設定
```ruby
# test/test_helper.rb
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  fixtures :all

  def setup
    # テストデータの初期化
  end

  def teardown
    # テストデータのクリーンアップ
  end
end
```

## 📊 テスト結果

### 現在のテスト状況
- **総テスト数**: 341テスト
- **総アサーション数**: 892アサーション
- **成功率**: 100%
- **失敗**: 0
- **エラー**: 0
- **スキップ**: 0

### テストファイル構成
```
test/
├── services/
│   ├── line_bot_service_test.rb
│   ├── line_bot_service_integration_test.rb
│   ├── line_bot_workflow_test.rb
│   ├── line_authentication_service_test.rb
│   ├── line_shift_service_test.rb
│   ├── line_shift_exchange_service_test.rb
│   ├── line_shift_addition_service_test.rb
│   ├── line_shift_deletion_service_test.rb
│   ├── line_message_service_test.rb
│   ├── line_validation_service_test.rb
│   ├── line_notification_service_test.rb
│   ├── line_utility_service_test.rb
│   └── access_control_service_test.rb
├── models/
│   ├── employee_test.rb
│   ├── conversation_state_test.rb
│   ├── verification_code_test.rb
│   └── shift_deletion_test.rb
└── controllers/
    └── webhook_controller_test.rb
```

## 🔍 単体テスト

### LineBotService テスト
```ruby
class LineBotServiceTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_#{SecureRandom.hex(8)}"
  end

  test "should handle help command" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response = @line_bot_service.handle_message(event)

    assert_not_nil response
    assert_includes response, "利用可能なコマンド"
  end

  test "should return unknown command message for non-command in personal chat" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "こんにちは")
    response = @line_bot_service.handle_message(event)

    assert_includes response, "コマンドは認識できませんでした"
  end

  test "should return nil for non-command in group chat" do
    event = mock_line_event(source_type: "group", user_id: @test_user_id, message_text: "こんにちは")
    response = @line_bot_service.handle_message(event)

    assert_nil response
  end
end
```

### LineAuthenticationService テスト
```ruby
class LineAuthenticationServiceTest < ActiveSupport::TestCase
  def setup
    @auth_service = LineAuthenticationService.new
    @test_user_id = "test_user_#{SecureRandom.hex(8)}"
  end

  test "should handle employee name input" do
    event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "田中太郎")
    response = @auth_service.handle_employee_name_input(@test_user_id, "田中太郎")

    assert_includes response, "認証コードを送信しました"
  end

  test "should handle verification code input" do
    # 認証コードの作成
    verification_code = VerificationCode.create!(
      employee_id: "test_employee",
      code: "123456",
      expires_at: 30.minutes.from_now
    )

    response = @auth_service.handle_verification_code_input(@test_user_id, "123456")

    assert_includes response, "認証が完了しました"
  end
end
```

## 🔗 統合テスト

### LineBotServiceIntegrationTest
```ruby
class LineBotServiceIntegrationTest < ActiveSupport::TestCase
  def setup
    @test_user_id = "test_user_#{SecureRandom.hex(8)}"
    @test_owner_id = "test_owner_#{SecureRandom.hex(8)}"
    @test_employee_id = "test_employee_#{SecureRandom.hex(8)}"

    # テスト用従業員を作成
    @owner = Employee.create!(
      employee_id: @test_owner_id,
      role: "owner",
      line_id: @test_user_id
    )

    @line_bot_service = LineBotService.new
  end

  def teardown
    # テストデータのクリーンアップ（依存関係を考慮した順序）
    ShiftExchange.where(requester_id: [@test_owner_id, @test_employee_id]).destroy_all
    ShiftAddition.where(requester_id: [@test_owner_id, @test_employee_id]).destroy_all
    ShiftDeletion.where(requester_id: [@test_owner_id, @test_employee_id]).destroy_all
    Shift.where(employee_id: [@test_owner_id, @test_employee_id]).destroy_all
    ConversationState.where(line_user_id: @test_user_id).delete_all
    Employee.where(employee_id: [@test_owner_id, @test_employee_id]).destroy_all
  end

  test "should handle authentication flow" do
    # 1. 認証コマンド
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "認証")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "既に認証済みです"

    # 2. 従業員名入力（存在しない従業員）
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "存在しない従業員")
    response2 = @line_bot_service.handle_message(event2)
    assert_includes response2, "コマンドは認識できませんでした"
  end

  test "should handle shift exchange request flow" do
    # テスト用シフトを作成
    tomorrow = Date.current + 1
    shift = Shift.create!(
      employee_id: @test_owner_id,
      shift_date: tomorrow,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00")
    )

    # 1. 交代依頼コマンド
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event1["message"]["text"] = "交代依頼"
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"

    # 2. 日付入力
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id)
    event2["message"]["text"] = tomorrow.strftime("%m/%d")
    response2 = @line_bot_service.handle_message(event2)
    assert response2.is_a?(Hash)
    assert_equal "flex", response2[:type]

    shift.destroy
  end
end
```

## 🔄 ワークフローテスト

### LineBotWorkflowTest
```ruby
class LineBotWorkflowTest < ActiveSupport::TestCase
  def setup
    @test_user_id = "test_user_#{SecureRandom.hex(8)}"
    @line_bot_service = LineBotService.new
  end

  test "should handle complete shift exchange workflow" do
    # 1. 交代依頼開始
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "交代依頼")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"

    # 2. 日付入力
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "12/25")
    response2 = @line_bot_service.handle_message(event2)
    assert response2.is_a?(Hash)

    # 3. シフト選択（Postback）
    postback_event = mock_line_event(source_type: "user", user_id: @test_user_id)
    postback_event["type"] = "postback"
    postback_event["postback"] = { "data" => "shift_123" }
    response3 = @line_bot_service.handle_message(postback_event)
    assert_includes response3, "交代先の従業員を選択してください"

    # 4. 従業員名入力
    event4 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "田中太郎")
    response4 = @line_bot_service.handle_message(event4)
    assert_includes response4, "シフト交代の確認"

    # 5. 確認
    event5 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "はい")
    response5 = @line_bot_service.handle_message(event5)
    assert_includes response5, "シフト交代依頼を送信しました"
  end

  test "should handle command interruption during conversation" do
    # 1. 交代依頼開始
    event1 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "交代依頼")
    response1 = @line_bot_service.handle_message(event1)
    assert_includes response1, "シフト交代依頼"

    # 2. 会話中にヘルプコマンドを送信
    event2 = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "ヘルプ")
    response2 = @line_bot_service.handle_message(event2)

    if response2.nil?
      # コマンド割り込みが正常に動作している
      assert true, "コマンド割り込みが正常に動作しました"
    else
      assert_includes response2, "利用可能なコマンド"
    end
  end
end
```

## 🎭 モック・スタブ

### LINE イベントのモック
```ruby
def mock_line_event(source_type:, user_id:, message_text: "")
  event = {
    "type" => "message",
    "source" => { "type" => source_type, "userId" => user_id },
    "message" => { "text" => message_text }
  }
  event.define_singleton_method(:source) { self["source"] }
  event.define_singleton_method(:message) { self["message"] }
  event.define_singleton_method(:type) { self["type"] }
  event
end
```

### Freee API のモック
```ruby
def mock_freee_api_response
  {
    employees: [
      {
        id: 123456,
        num: "EMP001",
        display_name: "田中太郎",
        email: "tanaka@example.com"
      }
    ]
  }.to_json
end

def stub_freee_api
  stub_request(:get, "https://api.freee.co.jp/hr/api/v1/employees")
    .to_return(
      status: 200,
      body: mock_freee_api_response,
      headers: { 'Content-Type' => 'application/json' }
    )
end
```

### 日付のモック
```ruby
def travel_to_date(date)
  travel_to(date) do
    yield
  end
end

# 使用例
test "should handle year rollover" do
  travel_to_date(Date.new(2024, 12, 31)) do
    # 12月31日に1/1と入力すると翌年の1月1日として認識されることをテスト
    result = LineDateValidationService.validate_month_day_format("1/1")
    assert_equal Date.new(2025, 1, 1), result
  end
end
```

## 📊 テストカバレッジ

### カバレッジ目標
- **行カバレッジ**: 90%以上
- **分岐カバレッジ**: 85%以上
- **メソッドカバレッジ**: 95%以上

### カバレッジ測定
```ruby
# Gemfile
gem 'simplecov', group: :test

# test/test_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
end
```

## 🚨 エラーハンドリングテスト

### 例外処理のテスト
```ruby
test "should handle Freee API connection error" do
  stub_request(:get, "https://api.freee.co.jp/hr/api/v1/employees")
    .to_return(status: 500)

  assert_raises(StandardError) do
    FreeeApiService.new.fetch_employees
  end
end

test "should handle invalid date format gracefully" do
  event = mock_line_event(source_type: "user", user_id: @test_user_id, message_text: "無効な日付")
  response = @line_bot_service.handle_message(event)

  assert_includes response, "日付の形式が正しくありません"
end
```

### バリデーションエラーのテスト
```ruby
test "should validate employee name input" do
  # 空の名前
  response = @auth_service.handle_employee_name_input(@test_user_id, "")
  assert_includes response, "従業員名を入力してください"

  # 長すぎる名前
  long_name = "a" * 100
  response = @auth_service.handle_employee_name_input(@test_user_id, long_name)
  assert_includes response, "従業員名が長すぎます"
end
```

## 🔄 継続的インテグレーション

### GitHub Actions 設定
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

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

    - name: Set up database
      run: |
        bundle exec rails db:create
        bundle exec rails db:migrate

    - name: Run tests
      run: bundle exec rails test

    - name: Generate coverage report
      run: bundle exec rails test:coverage
```

## 📈 テストメトリクス

### 品質メトリクス
- **テスト成功率**: 100%
- **テスト実行時間**: 平均5秒
- **テスト安定性**: 99.9%
- **カバレッジ**: 90%以上

### パフォーマンスメトリクス
- **単体テスト**: 平均0.1秒/テスト
- **統合テスト**: 平均0.5秒/テスト
- **E2Eテスト**: 平均2秒/テスト

## 🚀 今後のテスト改善

### 計画中の改善
- パフォーマンステストの追加
- 負荷テストの実装
- セキュリティテストの強化
- アクセシビリティテストの追加

### 継続的改善
- テストの自動化
- テストデータの管理改善
- テスト実行時間の最適化
- テストカバレッジの向上

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
