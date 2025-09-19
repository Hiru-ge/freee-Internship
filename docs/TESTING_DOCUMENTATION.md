# テスト仕様

勤怠管理システムのテスト戦略と実装方法について説明します。

## 概要

GASからRailsへの移行において、機能の完全性を保証するためのテストスイートです。TDD（テスト駆動開発）手法を採用し、Red, Green, Refactoringのサイクルで実装しています。

## テスト結果

- **総テスト数**: 414テスト
- **成功**: 414テスト
- **失敗**: 0テスト
- **エラー**: 0テスト
- **アサーション数**: 1072アサーション
- **成功率**: 100%
- **テストファイル数**: 10ファイル（機能別最適化後）
- **機能見直し後のテスト最適化完了**
- **リファクタリング後のテスト安定性確保**
- **実装クリーンアップ後のテスト一貫性確保**

## テスト戦略

### テストピラミッド
```
        E2E Tests (少数)
       /              \
   Integration Tests (中程度)
  /                        \
Unit Tests (多数)
```

### テストの種類

#### 1. 単体テスト (Unit Tests)
- **目的**: 個別のメソッドやクラスの動作確認
- **範囲**: モデル、サービス、ヘルパー
- **実行時間**: 高速（数秒）
- **依存関係**: 最小限

#### 2. 統合テスト (Integration Tests)
- **目的**: 複数のコンポーネント間の連携確認
- **範囲**: コントローラー、API、データベース
- **実行時間**: 中程度（数分）
- **依存関係**: データベース、外部サービス

#### 3. システムテスト (System Tests)
- **目的**: エンドツーエンドの動作確認
- **範囲**: ブラウザ操作、LINE Bot連携
- **実行時間**: 低速（数十分）
- **依存関係**: ブラウザ、外部API

## テスト環境設定

### 1. テスト用Gem

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers'
  gem 'database_cleaner-active_record'
  gem 'webmock'
  gem 'vcr'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'simplecov'
end
```

### 2. RSpec設定

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end

# spec/spec_helper.rb
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
```

### 3. データベース設定

```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

## テスト実装

### 1. モデルテスト

#### Employee モデル
```ruby
# spec/models/employee_spec.rb
RSpec.describe Employee, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:role) }
  end

  describe 'associations' do
    it { should have_many(:shifts) }
    it { should have_many(:shift_requests) }
    it { should have_many(:absence_requests) }
  end

  describe 'scopes' do
    let!(:employee1) { create(:employee, role: 'employee') }
    let!(:employee2) { create(:employee, role: 'owner') }

    it 'returns employees by role' do
      expect(Employee.by_role('employee')).to include(employee1)
      expect(Employee.by_role('employee')).not_to include(employee2)
    end
  end

  describe 'methods' do
    let(:employee) { create(:employee, name: '田中太郎') }

    it 'returns full name' do
      expect(employee.full_name).to eq('田中太郎')
    end
  end
end
```

#### Shift モデル
```ruby
# spec/models/shift_spec.rb
RSpec.describe Shift, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:employee) }
    it { should validate_presence_of(:date) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }
  end

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should have_many(:shift_requests) }
  end

  describe 'validations' do
    let(:employee) { create(:employee) }
    let(:shift) { build(:shift, employee: employee) }

    it 'validates start_time is before end_time' do
      shift.start_time = '18:00'
      shift.end_time = '09:00'
      expect(shift).not_to be_valid
      expect(shift.errors[:end_time]).to include('は開始時間より後である必要があります')
    end

    it 'validates date is not in the past' do
      shift.date = 1.day.ago
      expect(shift).not_to be_valid
      expect(shift.errors[:date]).to include('は過去の日付は選択できません')
    end
  end
end
```

### 2. コントローラーテスト

#### ShiftsController
```ruby
# spec/controllers/shifts_controller_spec.rb
RSpec.describe ShiftsController, type: :controller do
  let(:employee) { create(:employee) }
  let(:shift) { create(:shift, employee: employee) }

  before do
    sign_in employee
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns shifts' do
      get :index
      expect(assigns(:shifts)).to eq([shift])
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        shift: {
          employee_id: employee.id,
          date: Date.current + 1.day,
          start_time: '09:00',
          end_time: '17:00'
        }
      }
    end

    it 'creates a new shift' do
      expect {
        post :create, params: valid_params
      }.to change(Shift, :count).by(1)
    end

    it 'redirects to shifts index' do
      post :create, params: valid_params
      expect(response).to redirect_to(shifts_path)
    end
  end

  describe 'PUT #update' do
    let(:update_params) do
      {
        id: shift.id,
        shift: {
          start_time: '10:00',
          end_time: '18:00'
        }
      }
    end

    it 'updates the shift' do
      put :update, params: update_params
      shift.reload
      expect(shift.start_time.strftime('%H:%M')).to eq('10:00')
      expect(shift.end_time.strftime('%H:%M')).to eq('18:00')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the shift' do
      expect {
        delete :destroy, params: { id: shift.id }
      }.to change(Shift, :count).by(-1)
    end
  end
end
```

### 3. サービステスト

#### ShiftRequestService
```ruby
# spec/services/shift_request_service_spec.rb
RSpec.describe ShiftRequestService do
  let(:requester) { create(:employee) }
  let(:target_employee) { create(:employee) }
  let(:shift) { create(:shift, employee: requester) }

  describe '#create_request' do
    it 'creates a shift request' do
      expect {
        described_class.new.create_request(shift.id, target_employee.id)
      }.to change(ShiftRequest, :count).by(1)
    end

    it 'sends notification email' do
      expect {
        described_class.new.create_request(shift.id, target_employee.id)
      }.to have_enqueued_mail(ShiftRequestMailer, :request_notification)
    end
  end

  describe '#approve_request' do
    let(:request) { create(:shift_request, shift: shift, target_employee: target_employee) }

    it 'approves the request' do
      described_class.new.approve_request(request.id)
      request.reload
      expect(request.status).to eq('approved')
    end

    it 'updates the shift employee' do
      described_class.new.approve_request(request.id)
      shift.reload
      expect(shift.employee).to eq(target_employee)
    end
  end

  describe '#reject_request' do
    let(:request) { create(:shift_request, shift: shift, target_employee: target_employee) }

    it 'rejects the request' do
      described_class.new.reject_request(request.id, 'スケジュールの都合')
      request.reload
      expect(request.status).to eq('rejected')
      expect(request.rejection_reason).to eq('スケジュールの都合')
    end
  end
end
```

### 4. システムテスト

#### シフト管理フロー
```ruby
# spec/system/shift_management_spec.rb
RSpec.describe 'Shift Management', type: :system do
  let(:employee) { create(:employee) }

  before do
    sign_in employee
  end

  it 'allows creating a new shift' do
    visit new_shift_path

    fill_in '日付', with: Date.current + 1.day
    fill_in '開始時間', with: '09:00'
    fill_in '終了時間', with: '17:00'
    select employee.name, from: '従業員'

    click_button 'シフトを作成'

    expect(page).to have_content('シフトを作成しました')
    expect(page).to have_content(employee.name)
  end

  it 'allows editing a shift' do
    shift = create(:shift, employee: employee)
    visit edit_shift_path(shift)

    fill_in '開始時間', with: '10:00'
    fill_in '終了時間', with: '18:00'

    click_button 'シフトを更新'

    expect(page).to have_content('シフトを更新しました')
    expect(page).to have_content('10:00')
  end

  it 'allows deleting a shift' do
    shift = create(:shift, employee: employee)
    visit shifts_path

    click_link '削除', href: shift_path(shift)

    expect(page).to have_content('シフトを削除しました')
    expect(page).not_to have_content(shift.employee.name)
  end
end
```

### 5. APIテスト

#### シフトAPI
```ruby
# spec/requests/shifts_spec.rb
RSpec.describe 'Shifts API', type: :request do
  let(:employee) { create(:employee) }
  let(:headers) { { 'Authorization' => "Bearer #{employee.token}" } }

  describe 'GET /api/v1/shifts' do
    let!(:shift) { create(:shift, employee: employee) }

    it 'returns shifts' do
      get '/api/v1/shifts', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['shifts']).to be_an(Array)
      expect(JSON.parse(response.body)['shifts'].first['id']).to eq(shift.id)
    end
  end

  describe 'POST /api/v1/shifts' do
    let(:valid_params) do
      {
        shift: {
          employee_id: employee.id,
          date: Date.current + 1.day,
          start_time: '09:00',
          end_time: '17:00'
        }
      }
    end

    it 'creates a new shift' do
      expect {
        post '/api/v1/shifts', params: valid_params, headers: headers
      }.to change(Shift, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['status']).to eq('success')
    end
  end

  describe 'PUT /api/v1/shifts/:id' do
    let(:shift) { create(:shift, employee: employee) }
    let(:update_params) do
      {
        shift: {
          start_time: '10:00',
          end_time: '18:00'
        }
      }
    end

    it 'updates the shift' do
      put "/api/v1/shifts/#{shift.id}", params: update_params, headers: headers

      expect(response).to have_http_status(:ok)
      shift.reload
      expect(shift.start_time.strftime('%H:%M')).to eq('10:00')
    end
  end

  describe 'DELETE /api/v1/shifts/:id' do
    let(:shift) { create(:shift, employee: employee) }

    it 'deletes the shift' do
      expect {
        delete "/api/v1/shifts/#{shift.id}", headers: headers
      }.to change(Shift, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
```

### 6. LINE Botテスト

#### LINE Bot連携
```ruby
# spec/services/line_bot_service_spec.rb
RSpec.describe LineBotService do
  let(:employee) { create(:employee) }
  let(:line_user_id) { 'U1234567890abcdef' }

  before do
    allow(Line::Bot::Client).to receive(:new).and_return(double('client'))
  end

  describe '#send_message' do
    it 'sends a text message' do
      client = double('client')
      allow(Line::Bot::Client).to receive(:new).and_return(client)
      allow(client).to receive(:push_message).and_return(double('response', code: '200'))

      service = described_class.new
      service.send_message(line_user_id, 'テストメッセージ')

      expect(client).to have_received(:push_message)
    end
  end

  describe '#send_flex_message' do
    it 'sends a flex message' do
      client = double('client')
      allow(Line::Bot::Client).to receive(:new).and_return(client)
      allow(client).to receive(:push_message).and_return(double('response', code: '200'))

      flex_message = {
        type: 'flex',
        altText: 'シフト選択',
        contents: {
          type: 'bubble',
          body: {
            type: 'box',
            contents: []
          }
        }
      }

      service = described_class.new
      service.send_flex_message(line_user_id, flex_message)

      expect(client).to have_received(:push_message)
    end
  end
end
```

## テストデータ管理

### 1. Factory Bot

#### Employee Factory
```ruby
# spec/factories/employees.rb
FactoryBot.define do
  factory :employee do
    sequence(:name) { |n| "従業員#{n}" }
    sequence(:email) { |n| "employee#{n}@example.com" }
    role { 'employee' }
    freee_id { nil }

    trait :owner do
      role { 'owner' }
    end

    trait :with_freee_id do
      freee_id { rand(1000..9999) }
    end
  end
end
```

#### Shift Factory
```ruby
# spec/factories/shifts.rb
FactoryBot.define do
  factory :shift do
    association :employee
    date { Date.current + 1.day }
    start_time { '09:00' }
    end_time { '17:00' }
    status { 'confirmed' }

    trait :past do
      date { Date.current - 1.day }
    end

    trait :today do
      date { Date.current }
    end

    trait :pending do
      status { 'pending' }
    end
  end
end
```

#### ShiftRequest Factory
```ruby
# spec/factories/shift_requests.rb
FactoryBot.define do
  factory :shift_request do
    association :shift
    association :requester, factory: :employee
    association :target_employee, factory: :employee
    status { 'pending' }
    created_at { Time.current }

    trait :approved do
      status { 'approved' }
      approved_at { Time.current }
    end

    trait :rejected do
      status { 'rejected' }
      rejected_at { Time.current }
      rejection_reason { 'スケジュールの都合' }
    end
  end
end
```

### 2. テストデータの準備

#### Database Cleaner
```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

#### テストデータのセットアップ
```ruby
# spec/support/test_data.rb
RSpec.configure do |config|
  config.before(:suite) do
    # テスト用の基本データを作成
    create(:employee, :owner, name: 'オーナー', email: 'owner@example.com')
    create_list(:employee, 5, role: 'employee')
  end
end
```

## テスト実行

### 1. 全テスト実行

```bash
# 全テストを実行
bundle exec rspec

# 並列実行
bundle exec rspec --parallel

# 特定のファイルのみ実行
bundle exec rspec spec/models/employee_spec.rb

# 特定のテストのみ実行
bundle exec rspec spec/models/employee_spec.rb:10
```

### 2. テストカバレッジ

```bash
# カバレッジレポート生成
COVERAGE=true bundle exec rspec

# カバレッジレポート確認
open coverage/index.html
```

### 3. 継続的インテグレーション

#### GitHub Actions
```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      # SQLiteは追加のサービス設定不要

    steps:
    - uses: actions/checkout@v3

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.3.0
        bundler-cache: true

    - name: Set up database
      run: |
        bundle exec rails db:create
        bundle exec rails db:migrate
        bundle exec rails db:test:prepare

    - name: Run tests
      run: bundle exec rspec

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/coverage.xml
```

## テスト品質管理

### 1. コードカバレッジ

#### SimpleCov設定
```ruby
# spec/spec_helper.rb
require 'simplecov'

SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Mailers', 'app/mailers'

  minimum_coverage 90
end
```

### 2. テスト品質指標

- **カバレッジ**: 90%以上
- **テスト数**: 機能あたり10テスト以上
- **実行時間**: 全テスト5分以内
- **成功率**: 100%

### 3. テストレビュー

#### チェックリスト
- [ ] テストケースが網羅的か
- [ ] エッジケースが含まれているか
- [ ] テストデータが適切か
- [ ] アサーションが明確か
- [ ] テスト名が分かりやすいか

## パフォーマンステスト

### 1. 負荷テスト

#### シフト一覧取得
```ruby
# spec/performance/shifts_performance_spec.rb
RSpec.describe 'Shifts Performance', type: :request do
  before do
    # 大量のテストデータを作成
    create_list(:shift, 1000)
  end

  it 'loads shifts within acceptable time' do
    start_time = Time.current

    get '/shifts'

    end_time = Time.current
    response_time = end_time - start_time

    expect(response).to have_http_status(:ok)
    expect(response_time).to be < 1.second
  end
end
```

### 2. メモリ使用量テスト

```ruby
# spec/performance/memory_usage_spec.rb
RSpec.describe 'Memory Usage' do
  it 'does not leak memory' do
    initial_memory = `ps -o rss= -p #{Process.pid}`.to_i

    100.times do
      create(:shift)
    end

    final_memory = `ps -o rss= -p #{Process.pid}`.to_i
    memory_increase = final_memory - initial_memory

    expect(memory_increase).to be < 10.megabytes
  end
end
```

## テストメンテナンス

### 1. テストの更新

#### 機能変更時の対応
- テストケースの更新
- テストデータの調整
- アサーションの修正

#### リファクタリング時の対応
- テストの分割・統合
- 重複テストの削除
- テスト名の改善

### 2. テストの最適化

#### 実行時間の短縮
- データベースクエリの最適化
- 不要なテストの削除
- 並列実行の活用

#### メモリ使用量の削減
- テストデータの最小化
- メモリリークの防止
- ガベージコレクションの最適化
