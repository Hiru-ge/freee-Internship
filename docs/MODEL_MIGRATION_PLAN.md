# モデル中心設計移行計画書

## 概要

本ドキュメントは、現在のサービス中心アーキテクチャをモデル中心設計に移行するための計画を記載します。
**目標**: コントローラから3つのメソッド呼び出しで完結する理想的な設計の実現

## 移行の基本方針

### 1. 単一リソース処理の完全モデル移行
- CRUD操作とビジネスロジックをモデルに集約
- サービス層は外部API連携・複数モデル横断処理のみに限定
- コントローラは薄層化（バリデーション・ビジネスロジック排除）

### 2. 理想的なコントローラ設計
```ruby
# 理想形: 3つのメソッド呼び出しで完結
def create
  @resource = Resource.build_from_params(params)
  @resource.save_with_notifications!
  redirect_to success_path, notice: @resource.success_message
rescue Resource::ValidationError => e
  flash.now[:error] = e.message
  render :new
end
```

### 3. 責務の再定義
- **モデル**: 単一リソースの全ライフサイクル（CRUD・バリデーション・ビジネスロジック・状態管理）
- **サービス**: 外部API連携・メール送信・複数モデル横断の複雑な処理のみ
- **コントローラ**: HTTP処理・レスポンス制御・フラッシュメッセージのみ

## 大幅移行項目一覧

### 優先度S（最高）: サービス層の単一リソース処理をモデルに大移行

#### 1. ShiftAddition完全モデル移行
**現状**: `ShiftAdditionService` (230行) - ほぼ全処理がサービス層
**移行先**: `ShiftAddition`モデル
```ruby
class ShiftAddition < ApplicationRecord
  # 現在のサービス処理をモデルメソッドに移行
  def self.create_request_for(requester_id:, target_employee_ids:, shift_date:, start_time:, end_time:)
    # バリデーション・重複チェック・作成・通知を一括処理
  end

  def approve_by!(approver_id)
    # 承認処理・シフト作成・通知を一括処理
  end

  def reject_by!(approver_id)
    # 拒否処理・通知を一括処理
  end

  def self.status_for_employee(employee_id)
    # 状況取得処理
  end
end
```

#### 2. ShiftExchange完全モデル移行
**現状**: `ShiftExchangeService` (221行) - ほぼ全処理がサービス層
**移行先**: `ShiftExchange`モデル
```ruby
class ShiftExchange < ApplicationRecord
  def self.create_request_for(applicant_id:, approver_ids:, shift_date:, start_time:, end_time:)
    # バリデーション・重複チェック・シフト作成・リクエスト作成・通知
  end

  def approve_by!(approver_id)
    # シフト付け替え・他リクエスト拒否・通知
  end

  def reject_by!(approver_id)
    # 拒否処理・通知
  end

  def cancel_by!(requester_id)
    # キャンセル処理
  end
end
```

#### 3. ShiftDeletion完全モデル移行
**現状**: `ShiftDeletionService` (49行) - 全処理がサービス層
**移行先**: `ShiftDeletion`モデル
```ruby
class ShiftDeletion < ApplicationRecord
  def self.create_request_for(shift_id:, requester_id:, reason:)
    # バリデーション・作成・通知を一括処理
  end

  def approve_by!(approver_id)
    # シフト削除・承認・通知を一括処理
  end

  def reject_by!(approver_id)
    # 拒否処理・通知
  end
end
```

#### 4. Shift CRUD操作の完全モデル移行
**現状**: `ShiftDisplayService` (376行) - CRUD操作がサービス層
**移行先**: `Shift`モデル
```ruby
class Shift < ApplicationRecord
  def self.create_with_validation(employee_id:, shift_date:, start_time:, end_time:)
    # バリデーション・重複チェック・作成を一括処理
  end

  def update_with_validation(shift_data)
    # バリデーション・更新を一括処理
  end

  def destroy_with_validation
    # 削除可能性チェック・削除を一括処理
  end

  def self.overlaps_with?(employee_id, date, start_time, end_time)
    # 重複チェック（ShiftValidationServiceから移行）
  end
end
```

### 優先度A（高）: 認証・従業員管理の完全モデル移行

#### 5. Employee認証・管理の完全モデル移行
**現状**: `AuthService` (44行) - 認証処理がサービス層
**移行先**: `Employee`モデル
```ruby
class Employee < ApplicationRecord
  has_secure_password

  def self.authenticate_login(employee_id, password)
    # 認証・従業員作成・ログイン時刻更新を一括処理
  end

  def self.setup_initial_password(employee_id, password)
    # 初期パスワード設定処理
  end

  def change_password!(current_password, new_password)
    # パスワード変更処理
  end

  def self.search_by_name(name)
    # 従業員検索（LineBaseServiceから移行）
  end

  # バリデーション統合
  validates :password, length: { minimum: 8, maximum: 128 }
  validates :employee_id, presence: true, uniqueness: true, format: { with: /\A\d+\z/ }
  validate :password_complexity, if: :password_changed?
end
```

### 優先度B（中）: 共通処理の整理

#### 6. 重複チェック・バリデーションの統合
**現状**:
- `ShiftValidationService` (168行) - 重複チェック専用サービス
- `InputValidation` Concern - コントローラ層バリデーション
- `BaseService` - サービス層バリデーション

**移行先**: 各モデルのvalidationとクラスメソッド
```ruby
# 共通バリデーションConcern
module ShiftValidatable
  extend ActiveSupport::Concern

  included do
    validates :shift_date, presence: true
    validates :start_time, :end_time, presence: true
    validate :future_date_only, :end_time_after_start_time, :no_time_overlap
  end

  def no_time_overlap
    # 重複チェックバリデーション
  end
end
```

#### 7. 通知処理の分離
**現状**: 各サービスで`EmailNotificationService`を呼び出し
**移行後**: モデルのコールバックまたは専用メソッドで処理
```ruby
class ShiftAddition < ApplicationRecord
  after_update :send_status_notification, if: :saved_change_to_status?

  private

  def send_status_notification
    # 状態変更時の通知処理
  end
end
```

## 移行手順（大幅リファクタリング）

### Phase 1: ShiftAddition完全モデル移行（1-2日）
1. `ShiftAddition.create_request_for`メソッド実装
2. `approve_by!`・`reject_by!`メソッド実装
3. `ShiftAdditionService`の削除
4. コントローラの薄層化（3メソッド呼び出しに簡素化）

### Phase 2: ShiftExchange完全モデル移行（1-2日）
1. `ShiftExchange.create_request_for`メソッド実装
2. `approve_by!`・`reject_by!`・`cancel_by!`メソッド実装
3. `ShiftExchangeService`の削除
4. コントローラの薄層化

### Phase 3: ShiftDeletion・Shift CRUD移行（1-2日）
1. `ShiftDeletion.create_request_for`・承認拒否メソッド実装
2. `Shift.create_with_validation`等のCRUDメソッド実装
3. `ShiftDeletionService`・`ShiftDisplayService`の削除
4. `ShiftValidationService`の統合

### Phase 4: Employee認証・バリデーション統合（1日）
1. `Employee.authenticate_login`等の認証メソッド実装
2. 全バリデーションのモデル移行
3. `AuthService`・`InputValidation`の削除
4. コントローラ・Concernの大幅簡素化

### Phase 5: 最終整理・テスト修正（1日）
1. 不要サービス・Concernの完全削除
2. テスト修正（モデル中心テストに変更）
3. ドキュメント更新
4. 最終動作確認

## 移行による劇的効果

### 1. アーキテクチャの根本改善
- **サービス層の90%削除**: 18サービス → 3サービス（外部API・メール・複雑横断処理のみ）
- **コントローラの超薄層化**: 平均70-80行削減、3メソッド呼び出しで完結
- **モデル中心設計**: 単一リソース処理の完全集約

### 2. 開発効率の大幅向上
- **新機能追加**: モデルメソッド追加のみで完結
- **バグ修正**: 単一箇所での修正で済む
- **テスト**: モデルテストが中心、統合テスト簡素化

### 3. Rails Way完全準拠
- **Fat Model, Skinny Controller**: 理想的な実装
- **Convention over Configuration**: Rails慣例に完全準拠
- **Single Responsibility**: 各層の責務が明確

### 4. 具体的な削減効果
- **削除対象サービス（6個）**:
  - `ShiftAdditionService` (230行) → `ShiftAddition`モデルに統合
  - `ShiftExchangeService` (221行) → `ShiftExchange`モデルに統合
  - `ShiftDeletionService` (49行) → `ShiftDeletion`モデルに統合
  - `ShiftDisplayService` (376行) → `Shift`モデルに統合
  - `ShiftValidationService` (168行) → 各モデルのvalidationに統合
  - `AuthService` (44行) → `Employee`モデルに統合
- **大幅簡素化Concern（2個）**:
  - `InputValidation` (437行) → 各モデルのvalidationに移行
  - `Authentication` (316行) → `Employee`モデルに統合
- **コントローラ行数削減**:
  - `ShiftAdditionsController`: 48行 → 15行（70%削減）
  - `AuthController`: 374行 → 50行（87%削減）
  - `ShiftExchangesController`: 71行 → 20行（72%削減）
- **総削減効果**: 約1,900行のコード削減、18サービス → 3サービス（83%削減）

## 注意点

### 1. 既存テストへの影響
- バリデーションエラーメッセージの変更
- テストデータの調整が必要
- モックの見直し

### 2. 互換性の維持
- 段階的移行による影響最小化
- 既存APIの動作保証
- フラッシュメッセージの一貫性

### 3. パフォーマンス考慮
- N+1クエリの回避
- バリデーション実行タイミング
- キャッシュ戦略の見直し

## 完了基準（モデル中心設計）

1. **サービス層の大幅削減**: 単一リソース処理サービスが全て削除されている
2. **コントローラの理想形**: 各アクションが3メソッド呼び出し以内で完結している
3. **モデル中心**: 全CRUD・バリデーション・ビジネスロジックがモデルに集約されている
4. **テスト通過**: 既存テストが100%通過している（モデル中心テストに変更済み）
5. **パフォーマンス維持**: 処理速度が劣化していない
6. **ドキュメント同期**: 新アーキテクチャが正確に反映されている

## 理想的なコントローラ例（移行後）

### ShiftAdditionsController（3メソッド呼び出し）
```ruby
class ShiftAdditionsController < ApplicationController
  def create
    @requests = ShiftAddition.create_request_for(**shift_addition_params)
    @requests.send_notifications!
    redirect_to shifts_path, notice: @requests.success_message
  rescue ShiftAddition::ValidationError => e
    flash.now[:error] = e.message
    render :new
  end

  def approve
    @request = ShiftAddition.find(params[:id])
    @request.approve_by!(current_employee_id)
    redirect_to shift_approvals_path, notice: "承認しました"
  rescue ShiftAddition::AuthorizationError => e
    redirect_to shift_approvals_path, alert: e.message
  end

  private

  def shift_addition_params
    params.require(:shift_addition).permit(:requester_id, :shift_date, :start_time, :end_time, target_employee_ids: [])
  end
end
```

### ShiftExchangesController（3メソッド呼び出し）
```ruby
class ShiftExchangesController < ApplicationController
  def create
    @requests = ShiftExchange.create_request_for(**exchange_params)
    @requests.send_notifications!
    redirect_to shifts_path, notice: @requests.success_message
  rescue ShiftExchange::ValidationError => e
    flash.now[:error] = e.message
    render :new
  end

  def approve
    @request = ShiftExchange.find(params[:id])
    @request.approve_by!(current_employee_id)
    redirect_to shift_approvals_path, notice: "承認しました"
  end
end
```

### AuthController（2メソッド呼び出し）
```ruby
class AuthController < ApplicationController
  def create
    @employee = Employee.authenticate_login(params[:employee_id], params[:password])
    session[:employee_id] = @employee.employee_id
    redirect_to dashboard_path, notice: "ログインしました"
  rescue Employee::AuthenticationError => e
    flash.now[:alert] = e.message
    render :login
  end
end
```
