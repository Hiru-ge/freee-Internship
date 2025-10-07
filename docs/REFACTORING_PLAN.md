# リファクタリング計画書

## 概要

本ドキュメントは、サービス層とコントローラー層のリファクタリング計画を記載します。主な目的は以下の通りです：

1. **サービス層の階層化**: 基底クラスによる共通処理の抽出
2. **コントローラー層の薄層化**: ビジネスロジックをサービス層に移行
3. **責任の明確化**: 各層の役割を明確に分離
4. **コードの重複排除**: DRY原則の適用

## 現状の問題点

### 1. サービス層の問題
- 各サービスが独立しており、共通処理が重複
- バリデーション、エラーハンドリング、レスポンス生成が散在
- シフト重複チェック処理が複数箇所に存在

### 2. コントローラー層の問題
- ビジネスロジックがコントローラーに混在
- バリデーション処理がコントローラーに存在
- エラーハンドリングが統一されていない

## リファクタリング方針

### 1. サービス層の階層化

#### 階層構造
```
BaseService (全サービスの基底)
    ├── ShiftBaseService (シフト関連サービスの基底)
    │       ├── ShiftValidationService (シフト重複チェック専用)
    │       ├── ShiftAdditionService (シフト追加)
    │       ├── ShiftExchangeService (シフト交代)
    │       ├── ShiftDeletionService (シフト削除)
    │       └── ShiftDisplayService (シフト表示)
    ├── LineBaseService (LINE Bot関連サービスの基底)
    │       ├── LineShiftAdditionService
    │       ├── LineShiftExchangeService
    │       ├── LineShiftDeletionService
    │       └── LineShiftDisplayService
    ├── AuthService (認証関連)
    ├── EmailNotificationService (メール通知)
    ├── ClockService (打刻関連)
    └── WageService (給与計算)
```

#### 各層の責任

**BaseService**
- 全サービス共通の処理
- 基本的なバリデーション
- レスポンス生成
- 従業員名取得
- エラーハンドリング
- FreeeApiServiceの初期化

**ShiftBaseService**
- シフト関連サービス共通の処理
- シフト固有のバリデーション
- シフト関連の共通ロジック
- ShiftValidationServiceへの委譲

**LineBaseService**
- LINE Bot関連サービス共通の処理
- 会話状態管理
- メッセージ生成
- 従業員検索

### 2. コントローラー層の薄層化

#### 継承関係
```
ApplicationController (基底)
    ├── ShiftBaseController (シフト関連の基底)
    │       ├── ShiftDisplayController
    │       ├── ShiftAdditionsController
    │       ├── ShiftExchangesController
    │       ├── ShiftDeletionsController
    │       └── ShiftApprovalsController
    ├── AuthController (直接継承)
    ├── AttendanceController (直接継承)
    ├── WagesController (直接継承)
    ├── WebhookController (直接継承)
    └── ClockReminderController (直接継承)
```

#### 各層の責任

**コントローラー層**
- HTTPリクエスト/レスポンスの処理
- パラメータの準備と変換
- サービスの呼び出し
- レスポンスの形式決定
- 認証・認可の確認

**サービス層**
- ビジネスロジックの実装
- バリデーション処理
- データの整合性チェック
- 複数のモデルにまたがる処理
- 外部APIとの連携

## 実装計画

### Phase 1: 基底サービスの作成

#### 1.1 BaseServiceの作成
```ruby
class BaseService
  def initialize
    # 共通の初期化処理
  end

  # 共通のバリデーション処理
  def validate_required_params(params, required_fields)
    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      return error_response("必須項目が不足しています: #{missing_fields.join(', ')}")
    end

    success_response("バリデーション成功")
  end

  # 共通のレスポンス生成
  def success_response(message, data = nil)
    response = { success: true, message: message }
    response[:data] = data if data
    response
  end

  def error_response(message)
    { success: false, message: message }
  end

  # 従業員名取得の共通処理
  def get_employee_display_name(employee_id)
    employee = Employee.find_by(employee_id: employee_id)
    employee&.display_name || "ID: #{employee_id}"
  end

  # FreeeApiServiceの共通初期化
  def freee_api_service
    @freee_api_service ||= FreeeApiService.new(
      ENV.fetch("FREEE_ACCESS_TOKEN", nil),
      ENV.fetch("FREEE_COMPANY_ID", nil)
    )
  end
end
```

#### 1.2 ShiftBaseServiceの作成
```ruby
class ShiftBaseService < BaseService
  # シフト関連の共通バリデーション
  def validate_shift_date(date_string)
    begin
      date = Date.parse(date_string)
      if date < Date.current
        return error_response("過去の日付のシフトリクエストはできません。")
      end
      { success: true, date: date }
    rescue ArgumentError
      error_response("無効な日付形式です。")
    end
  end

  def validate_shift_time(time_string)
    begin
      Time.zone.parse(time_string)
      { success: true }
    rescue ArgumentError
      error_response("無効な時間形式です。")
    end
  end

  def validate_shift_params(params, required_fields)
    # 基本バリデーション
    basic_validation = validate_required_params(params, required_fields)
    return basic_validation unless basic_validation[:success]

    # 日付バリデーション
    date_validation = validate_shift_date(params[:shift_date])
    return date_validation unless date_validation[:success]

    # 時間バリデーション
    start_time_validation = validate_shift_time(params[:start_time])
    return start_time_validation unless start_time_validation[:success]

    end_time_validation = validate_shift_time(params[:end_time])
    return end_time_validation unless end_time_validation[:success]

    success_response("シフトパラメータのバリデーション成功")
  end

  # シフト重複チェックサービスへの委譲
  def shift_validation_service
    @shift_validation_service ||= ShiftValidationService.new
  end

  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    shift_validation_service.has_shift_overlap?(employee_id, shift_date, start_time, end_time)
  end

  def get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
    shift_validation_service.get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
  end
end
```

#### 1.3 ShiftValidationServiceの作成
```ruby
class ShiftValidationService < BaseService
  # シフト重複チェック処理
  def has_shift_overlap?(employee_id, shift_date, start_time, end_time)
    existing_shifts = Shift.where(
      employee_id: employee_id,
      shift_date: shift_date
    )

    existing_shifts.any? do |shift|
      shift_overlaps?(shift, start_time, end_time)
    end
  end

  def get_available_and_overlapping_employees(employee_ids, shift_date, start_time, end_time)
    available_ids = []
    overlapping_names = []

    employee_ids.each do |employee_id|
      if has_shift_overlap?(employee_id, shift_date, start_time, end_time)
        employee_name = get_employee_display_name(employee_id)
        overlapping_names << employee_name
      else
        available_ids << employee_id
      end
    end

    { available_ids: available_ids, overlapping_names: overlapping_names }
  end

  def check_addition_overlap(employee_id, shift_date, start_time, end_time)
    if has_shift_overlap?(employee_id, shift_date, start_time, end_time)
      return get_employee_display_name(employee_id)
    end
    nil
  end

  private

  def shift_overlaps?(existing_shift, new_start_time, new_end_time)
    existing_times = convert_shift_times_to_objects(existing_shift)
    new_times = convert_new_shift_times_to_objects(existing_shift.shift_date, new_start_time, new_end_time)

    new_times[:start] < existing_times[:end] && new_times[:end] > existing_times[:start]
  end

  def convert_shift_times_to_objects(existing_shift)
    base_date = existing_shift.shift_date
    {
      start: Time.zone.parse("#{base_date} #{existing_shift.start_time.strftime('%H:%M')}"),
      end: Time.zone.parse("#{base_date} #{existing_shift.end_time.strftime('%H:%M')}")
    }
  end

  def convert_new_shift_times_to_objects(base_date, new_start_time, new_end_time)
    new_start_time_str = format_time_to_string(new_start_time)
    new_end_time_str = format_time_to_string(new_end_time)

    {
      start: Time.zone.parse("#{base_date} #{new_start_time_str}"),
      end: Time.zone.parse("#{base_date} #{new_end_time_str}")
    }
  end

  def format_time_to_string(time)
    time.is_a?(String) ? time : time.strftime("%H:%M")
  end
end
```

#### 1.4 LineBaseServiceの作成
```ruby
class LineBaseService < BaseService
  def initialize
    super
    @line_bot_service = LineBotService.new
  end

  # 会話状態管理の共通処理
  def get_conversation_state(line_user_id)
    @line_bot_service.get_conversation_state(line_user_id)
  end

  def set_conversation_state(line_user_id, state)
    @line_bot_service.set_conversation_state(line_user_id, state)
  end

  def clear_conversation_state(line_user_id)
    @line_bot_service.clear_conversation_state(line_user_id)
  end

  # 従業員検索の共通処理
  def find_employees_by_name(name)
    @line_bot_service.find_employees_by_name(name)
  end

  def find_employee_by_line_id(line_id)
    @line_bot_service.find_employee_by_line_id(line_id)
  end

  # メッセージ生成の共通処理
  def generate_error_message(error_text)
    @line_bot_service.generate_error_message(error_text)
  end

  def generate_success_message(success_text)
    @line_bot_service.generate_success_message(success_text)
  end
end
```

### Phase 2: 既存サービスの移行

#### 2.1 ShiftAdditionServiceの移行
```ruby
class ShiftAdditionService < ShiftBaseService
  def create_addition_request(params)
    # 1. バリデーション
    validation_result = validate_addition_params(params)
    return validation_result unless validation_result[:success]

    # 2. ビジネスロジック
    overlap_check_result = check_shift_overlaps(params)
    return overlap_check_result unless overlap_check_result[:success]

    # 3. データベース操作
    create_requests(params)
  end

  private

  def validate_addition_params(params)
    validate_shift_params(params, %i[requester_id target_employee_ids shift_date start_time end_time])
  end

  def check_shift_overlaps(params)
    overlapping_employees = []

    params[:target_employee_ids].each do |target_employee_id|
      overlapping_employee = check_addition_overlap(
        target_employee_id,
        params[:shift_date],
        params[:start_time],
        params[:end_time]
      )

      if overlapping_employee
        overlapping_employees << overlapping_employee
      end
    end

    if overlapping_employees.any?
      return error_response("以下の従業員は指定された時間にシフトが入っています: #{overlapping_employees.join(', ')}")
    end

    success_response("重複チェック完了")
  end

  def create_requests(params)
    # 実際のリクエスト作成処理
  end
end
```

#### 2.2 他のシフトサービスの移行
- ShiftExchangeService
- ShiftDeletionService
- ShiftDisplayService

#### 2.3 LINE Botサービスの移行
- LineShiftAdditionService
- LineShiftExchangeService
- LineShiftDeletionService
- LineShiftDisplayService

### Phase 3: コントローラーの薄層化

#### 3.1 ShiftAdditionsControllerの移行
```ruby
class ShiftAdditionsController < ShiftBaseController
  def create
    # 1. パラメータの準備
    service_params = prepare_shift_params

    # 2. サービスの呼び出し
    result = shift_addition_service.create_addition_request(service_params)

    # 3. レスポンスの処理
    handle_shift_service_response(result)
  end

  private

  def shift_addition_service
    @shift_addition_service ||= ShiftAdditionService.new
  end

  def prepare_shift_params
    {
      requester_id: current_employee_id,
      target_employee_ids: params[:target_employee_ids],
      shift_date: params[:shift_date],
      start_time: params[:start_time],
      end_time: params[:end_time]
    }
  end
end
```

#### 3.2 他のシフトコントローラーの移行
- ShiftExchangesController
- ShiftDeletionsController
- ShiftApprovalsController
- ShiftDisplayController

### Phase 4: テストの修正

#### 4.1 サービス層のテスト
- 基底クラスのテスト
- 各サービスのテスト修正

#### 4.2 コントローラー層のテスト
- 薄層化に伴うテスト修正
- モックの調整

### Phase 5: ドキュメントの更新

#### 5.1 アーキテクチャドキュメントの更新
- サービス層の階層構造
- コントローラー層の責任分離

#### 5.2 開発ガイドの更新
- 新しいサービス追加方法
- コントローラー作成方法

## 期待される効果

### 1. コードの品質向上
- **DRY原則の適用**: 重複コードの排除
- **単一責任原則**: 各クラスの責任が明確
- **テスタビリティ**: ビジネスロジックの独立テスト

### 2. 保守性の向上
- **変更の局所化**: 影響範囲の限定
- **可読性の向上**: 各層の役割が明確
- **拡張性**: 新しい機能の追加が容易

### 3. 開発効率の向上
- **共通処理の再利用**: 開発時間の短縮
- **エラーの減少**: 統一された処理による品質向上
- **チーム開発**: 明確な責任分離による協力しやすさ

## リスクと対策

### 1. リスク
- **既存機能への影響**: リファクタリング中のバグ
- **テストの失敗**: 構造変更によるテスト不整合
- **開発時間の増加**: 一時的な開発速度の低下

### 2. 対策
- **段階的な実装**: 小さな単位での変更
- **テストの充実**: 各段階でのテスト実行
- **ロールバック計画**: 問題発生時の復旧手順

## 実装スケジュール

### Week 1: 基底サービスの作成
- BaseService
- ShiftBaseService
- ShiftValidationService
- LineBaseService

### Week 2: 既存サービスの移行
- シフト関連サービスの移行
- LINE Botサービスの移行

### Week 3: コントローラーの薄層化
- シフト関連コントローラーの移行
- テストの修正

### Week 4: テストとドキュメント
- 全テストの実行と修正
- ドキュメントの更新

## 成功指標

### 1. コードメトリクス
- **重複コードの削減**: 20%以上の削減
- **テストカバレッジ**: 90%以上を維持
- **循環的複雑度**: 各メソッド10以下

### 2. 機能指標
- **既存機能の動作**: 100%の動作保証
- **新機能追加時間**: 30%の短縮
- **バグ発生率**: 20%の削減

### 3. 開発指標
- **コードレビュー時間**: 20%の短縮
- **新規開発者オンボーディング**: 50%の短縮
- **保守性スコア**: 向上

---

このリファクタリング計画に基づいて、段階的に実装を進めていきます。各段階でテストを実行し、品質を保ちながら進めることが重要です。
