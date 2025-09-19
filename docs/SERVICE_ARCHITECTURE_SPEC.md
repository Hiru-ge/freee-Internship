# サービスアーキテクチャ仕様書

勤怠管理システムのサービス層アーキテクチャの詳細仕様です。

## 🎯 概要

勤怠管理システムのサービス層における責務分離、依存関係、設計原則の詳細仕様です。

## 🏗️ アーキテクチャ原則

### 設計原則
- **単一責任原則 (SRP)**: 各サービスは一つの責任を持つ
- **依存性逆転原則 (DIP)**: 抽象に依存し、具象に依存しない
- **開放閉鎖原則 (OCP)**: 拡張に開放、修正に閉鎖
- **DRY原則**: 重複を避ける
- **SOLID原則**: オブジェクト指向設計の原則に従う

### 責務分離
```
Controller → Service → Model → Database
    ↓         ↓        ↓
  View    Business  Data
         Logic    Access
```

## 🔧 コアサービス

### 1. AuthService
認証・認可を担当するサービス

```ruby
class AuthService
  def initialize
    @freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

  def send_verification_code(email)
    # 認証コード生成・送信
  end

  def verify_verification_code(email, code)
    # 認証コード検証
  end

  def find_employee_by_email(email)
    # 従業員検索
  end
end
```

**責務**:
- メール認証コードの生成・送信
- 認証コードの検証
- 従業員の検索・認証

### 2. ClockService
打刻機能を担当するサービス

```ruby
class ClockService
  def initialize(employee_id)
    @employee_id = employee_id
    @freee_service = FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end

  def clock_in
    # 出勤打刻
  end

  def clock_out
    # 退勤打刻
  end

  def get_clock_status
    # 打刻状態取得
  end

  def get_attendance_for_month(year, month)
    # 月次勤怠データ取得
  end
end
```

**責務**:
- 出勤・退勤打刻処理
- 打刻状態の管理
- 勤怠データの取得

### 3. WageService
給与計算を担当するサービス

```ruby
class WageService
  def self.time_zone_wage_rates
    # 時間帯別時給レート
  end

  def self.monthly_wage_target
    # 月間給与目標
  end

  def calculate_monthly_wage(employee_id, month, year)
    # 月次給与計算
  end

  def get_employee_wage_info(employee_id, month, year)
    # 従業員給与情報取得
  end

  def get_all_employees_wages(month, year)
    # 全従業員給与情報取得
  end
end
```

**責務**:
- 時間帯別時給計算
- 月次給与計算
- 103万の壁の計算

### 4. FreeeApiService
Freee API連携を担当するサービス

```ruby
class FreeeApiService
  include HTTParty
  base_uri "https://api.freee.co.jp"

  def initialize(access_token, company_id)
    @access_token = access_token
    @company_id = company_id
  end

  def get_employees
    # 従業員一覧取得
  end

  def get_employee_info(employee_id)
    # 個別従業員情報取得
  end

  def get_time_clocks(employee_id, from_date, to_date)
    # 勤怠記録取得
  end

  def create_work_record(employee_id, form_data)
    # 勤怠記録作成
  end
end
```

**責務**:
- Freee APIとの通信
- 従業員情報の取得
- 勤怠データの同期

## 🔄 シフト管理サービス

### 1. ShiftExchangeService
シフト交代を担当するサービス

```ruby
class ShiftExchangeService
  def initialize
    @notification_service = UnifiedNotificationService.new
  end

  def create_shift_exchange_request(requester_id, shift_id, approver_id)
    # シフト交代依頼作成
  end

  def approve_shift_exchange(request_id)
    # シフト交代承認
  end

  def reject_shift_exchange(request_id)
    # シフト交代拒否
  end

  def get_pending_requests(employee_id)
    # 承認待ち依頼取得
  end
end
```

**責務**:
- シフト交代依頼の作成
- 承認・拒否処理
- 通知送信

### 2. ShiftAdditionService
シフト追加を担当するサービス

```ruby
class ShiftAdditionService
  def initialize
    @notification_service = UnifiedNotificationService.new
  end

  def create_shift_addition_request(requester_id, shift_data, target_employee_ids)
    # シフト追加依頼作成
  end

  def approve_shift_addition(request_id)
    # シフト追加承認
  end

  def reject_shift_addition(request_id)
    # シフト追加拒否
  end

  def get_available_employees(date, start_time, end_time)
    # 利用可能従業員取得
  end
end
```

**責務**:
- シフト追加依頼の作成
- 承認・拒否処理
- 重複チェック

### 3. ShiftDeletionService
欠勤申請を担当するサービス

```ruby
class ShiftDeletionService
  def initialize
    @notification_service = UnifiedNotificationService.new
  end

  def create_shift_deletion_request(requester_id, shift_id, reason)
    # 欠勤申請作成
  end

  def approve_shift_deletion(request_id)
    # 欠勤申請承認
  end

  def reject_shift_deletion(request_id)
    # 欠勤申請拒否
  end

  def get_employee_future_shifts(employee_id)
    # 従業員の未来シフト取得
  end
end
```

**責務**:
- 欠勤申請の作成
- 承認・拒否処理
- シフト削除

## 📧 通知サービス

### 1. EmailNotificationService
メール通知を担当するサービス

```ruby
class EmailNotificationService
  def send_verification_code(email, code)
    # 認証コード送信
  end

  def send_clock_reminder(employee_id, type)
    # 打刻忘れアラート
  end

  def send_shift_notification(employee_id, message)
    # シフト変更通知
  end
end
```

**責務**:
- メール送信処理
- SMTP設定管理
- メールテンプレート管理

### 2. UnifiedNotificationService
統合通知を担当するサービス

```ruby
class UnifiedNotificationService
  def initialize
    @email_service = EmailNotificationService.new
    @line_service = LineNotificationService.new
  end

  def send_shift_change_notification(employee_id, message)
    # シフト変更通知（メール・LINE）
  end

  def send_approval_request_notification(employee_id, message)
    # 承認依頼通知（メール・LINE）
  end

  def send_clock_reminder(employee_id, type)
    # 打刻忘れアラート（メール・LINE）
  end
end
```

**責務**:
- メール・LINE通知の統合
- 通知ルーティング
- 通知履歴管理

## 🔍 バリデーションサービス

### 1. LineValidationService
LINE Bot用バリデーションを担当するサービス

```ruby
class LineValidationService
  def validate_shift_date(date_string)
    # 日付バリデーション
  end

  def validate_shift_time(time_string)
    # 時間バリデーション
  end

  def validate_employee_name(name)
    # 従業員名バリデーション
  end

  def validate_verification_code(code)
    # 認証コードバリデーション
  end
end
```

**責務**:
- 入力値の検証
- エラーメッセージの生成
- データの正規化

### 2. LineDateValidationService
日付バリデーションを担当するサービス

```ruby
class LineDateValidationService
  def self.validate_month_day_format(date_string)
    # 月/日形式の日付バリデーション
  end

  def self.parse_month_day(date_string)
    # 月/日形式の日付パース
  end

  def self.handle_year_rollover(month, day)
    # 年切り替え処理
  end
end
```

**責務**:
- 月/日形式の日付検証
- 年切り替え処理
- 日付の正規化

## 🛠️ ユーティリティサービス

### 1. LineUtilityService
LINE Bot用ユーティリティを担当するサービス

```ruby
class LineUtilityService
  def extract_user_id(event)
    # ユーザーID抽出
  end

  def format_date(date)
    # 日付フォーマット
  end

  def format_time(time)
    # 時間フォーマット
  end

  def find_employee_by_line_id(line_user_id)
    # LINE IDから従業員検索
  end

  def normalize_employee_name(name)
    # 従業員名正規化
  end
end
```

**責務**:
- 共通的なユーティリティ機能
- データ変換・フォーマット
- 検索・正規化処理

### 2. LineMessageService
メッセージ生成を担当するサービス

```ruby
class LineMessageService
  def generate_help_message
    # ヘルプメッセージ生成
  end

  def generate_shift_flex_message_for_date(date, shifts)
    # 日付別シフトFlex Message生成
  end

  def generate_pending_requests_flex_message(requests)
    # 承認待ち依頼Flex Message生成
  end

  def generate_shift_deletion_flex_message(shifts)
    # 欠勤申請シフト選択Flex Message生成
  end
end
```

**責務**:
- メッセージテンプレート管理
- Flex Message生成
- メッセージの国際化

## 🔄 サービス間の依存関係

### 依存関係図
```
LineBotService
├── LineAuthenticationService
│   ├── AuthService
│   └── LineUtilityService
├── LineShiftService
│   ├── FreeeApiService
│   └── LineMessageService
├── LineShiftExchangeService
│   ├── ShiftExchangeService
│   ├── UnifiedNotificationService
│   └── LineValidationService
├── LineShiftAdditionService
│   ├── ShiftAdditionService
│   ├── UnifiedNotificationService
│   └── LineValidationService
└── LineShiftDeletionService
    ├── ShiftDeletionService
    ├── UnifiedNotificationService
    └── LineValidationService
```

### 依存性注入
```ruby
class LineShiftExchangeService
  def initialize(notification_service: nil, validation_service: nil)
    @notification_service = notification_service || UnifiedNotificationService.new
    @validation_service = validation_service || LineValidationService.new
  end
end
```

## 🧪 テスト戦略

### サービス層のテスト
```ruby
describe ShiftExchangeService do
  let(:service) { ShiftExchangeService.new }
  let(:mock_notification_service) { instance_double(UnifiedNotificationService) }

  before do
    allow(UnifiedNotificationService).to receive(:new).and_return(mock_notification_service)
  end

  describe '#create_shift_exchange_request' do
    it 'シフト交代依頼を作成する' do
      result = service.create_shift_exchange_request(
        'requester_id', 'shift_id', 'approver_id'
      )

      expect(result[:success]).to be true
      expect(mock_notification_service).to have_received(:send_approval_request_notification)
    end
  end
end
```

### モック・スタブの使用
```ruby
describe FreeeApiService do
  let(:service) { FreeeApiService.new('token', 'company_id') }

  before do
    stub_request(:get, "https://api.freee.co.jp/hr/api/v1/companies/company_id/employees")
      .to_return(
        status: 200,
        body: { employees: [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it '従業員一覧を取得する' do
    result = service.get_employees
    expect(result).to be_an(Array)
  end
end
```

## 📊 パフォーマンス最適化

### 遅延ロード
```ruby
class LineBotService
  def auth_service
    @auth_service ||= LineAuthenticationService.new
  end

  def shift_service
    @shift_service ||= LineShiftService.new
  end
end
```

### キャッシュ戦略
```ruby
class FreeeApiService
  CACHE_DURATION = 5.minutes

  def get_employees
    Rails.cache.fetch("employees_#{@company_id}", expires_in: CACHE_DURATION) do
      # API呼び出し
    end
  end
end
```

### バッチ処理
```ruby
class ClockReminderService
  def self.check_all_employees
    Employee.find_each do |employee|
      check_forgotten_clock_ins(employee.id)
      check_forgotten_clock_outs(employee.id)
    end
  end
end
```

## 🔒 エラーハンドリング

### サービス層のエラーハンドリング
```ruby
class ShiftExchangeService
  def create_shift_exchange_request(requester_id, shift_id, approver_id)
    begin
      # ビジネスロジック
      result = perform_shift_exchange_creation
      { success: true, data: result }
    rescue StandardError => e
      Rails.logger.error "シフト交代依頼作成エラー: #{e.message}"
      { success: false, error: e.message }
    end
  end
end
```

### 外部API エラーハンドリング
```ruby
class FreeeApiService
  def get_employees
    response = self.class.get(url, @options)

    unless response.success?
      handle_api_error(response)
      return []
    end

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error "Freee API接続エラー: #{e.message}"
    []
  end

  private

  def handle_api_error(response)
    case response.code
    when 401
      raise "認証エラー: アクセストークンが無効です"
    when 429
      raise "レート制限: リクエスト制限に達しました"
    else
      raise "API エラー: #{response.code} - #{response.body}"
    end
  end
end
```

## 🚀 今後の拡張予定

### 機能拡張
- **イベント駆動アーキテクチャ**: イベントベースの処理
- **マイクロサービス**: サービス分割
- **CQRS**: コマンド・クエリ責任分離
- **ドメイン駆動設計**: DDDの導入

### 技術的改善
- **依存性注入**: DIコンテナの導入
- **インターフェース**: 抽象化の強化
- **非同期処理**: バックグラウンド処理の強化
- **監視**: サービス監視の実装

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
