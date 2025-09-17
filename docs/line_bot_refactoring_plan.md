# LINE Bot リファクタリング計画書

## 概要

現在のLineBotService（2,294行、92メソッド）は巨大なクラスとなっており、単一責任原則（SRP）に違反している。保守性・可読性・テスタビリティの向上を目的として、責任の分離とバックエンド処理の統合を行う。

## 現状の問題

### 1. 巨大なクラス問題
- **2,294行、92メソッド**の巨大なLineBotService
- 単一責任原則（SRP）の重大な違反
- 保守性・可読性の著しい低下

### 2. 複数の責任が混在
- 認証処理
- シフト確認処理
- シフト交代処理
- シフト追加処理
- メッセージ生成処理
- 会話状態管理
- Postback処理
- メール通知処理

### 3. バックエンド処理の重複
- LINE処理とWebアプリ処理で同じビジネスロジックが重複
- 保守性の低下
- バグ修正時の影響範囲の拡大

## リファクタリング目標

### 1. 責任の分離
- 各サービスクラスの責任を明確化
- 単一責任原則の遵守
- 依存関係の整理

### 2. バックエンド処理の統合
- LINE処理とWebアプリ処理の共通化
- ビジネスロジックの一元化
- 保守性の向上

### 3. コード品質の向上
- 可読性の向上
- テスタビリティの向上
- 拡張性の向上

## リファクタリング計画

### Phase 1: 責任の分離（優先度：🔴 最高）
**期間**: 2-3週間
**工数**: 16時間

#### 1.1 認証関連サービスの分離
**工数**: 3時間

```ruby
# 新規作成予定
class LineAuthenticationService
  # 認証フロー管理
  # 認証コード生成・検証
  # 従業員検索
  # 会話状態管理
end
```

**移行対象メソッド**:
- `handle_auth_command`
- `handle_employee_name_input`
- `handle_verification_code_input`
- `generate_verification_code_for_employee`
- `search_employees_by_name`
- `handle_multiple_employee_matches`

#### 1.2 シフト関連サービスの分離
**工数**: 2時間

```ruby
# 新規作成予定
class LineShiftService
  # シフト確認処理
  # シフト情報取得
  # シフト表示フォーマット
end
```

**移行対象メソッド**:
- `handle_shift_command`
- `handle_all_shifts_command`
- `get_personal_shift_info`
- `get_group_shift_info`
- `get_daily_shift_info`
- `format_shift_info`

#### 1.3 シフト交代サービスの分離
**工数**: 4時間

```ruby
# 新規作成予定
class LineShiftExchangeService
  # シフト交代依頼処理
  # 承認・否認処理
  # 状況確認処理
  # キャンセル処理
end
```

**移行対象メソッド**:
- `handle_shift_exchange_command`
- `handle_shift_date_input`
- `handle_shift_selection_input`
- `handle_employee_selection_input`
- `handle_confirmation_input`
- `handle_approval_postback`
- `handle_exchange_status_command`
- `handle_cancel_request_command`
- `create_shift_exchange_request`
- `cancel_shift_exchange_request`

#### 1.4 シフト追加サービスの分離
**工数**: 3時間

```ruby
# 新規作成予定
class LineShiftAdditionService
  # シフト追加依頼処理
  # 承認・否認処理
  # 重複チェック処理
end
```

**移行対象メソッド**:
- `handle_shift_addition_command`
- `handle_shift_addition_date_input`
- `handle_shift_addition_time_input`
- `handle_shift_addition_employee_input`
- `handle_shift_addition_confirmation_input`
- `handle_shift_addition_approval_postback`
- `create_shift_addition_request`

#### 1.5 メッセージ生成サービスの分離
**工数**: 2時間

```ruby
# 新規作成予定
class LineMessageService
  # Flex Message生成
  # テキストメッセージ生成
  # ヘルプメッセージ生成
end
```

**移行対象メソッド**:
- `generate_help_message`
- `generate_shift_flex_message_for_date`
- `generate_pending_requests_flex_message`
- `generate_shift_addition_response`

#### 1.6 会話状態管理サービスの分離
**工数**: 2時間

```ruby
# 新規作成予定
class LineConversationService
  # 会話状態管理
  # 状態遷移処理
  # 入力検証処理
end
```

**移行対象メソッド**:
- `get_conversation_state`
- `set_conversation_state`
- `clear_conversation_state`
- `handle_stateful_message`
- `handle_message_with_state`

### Phase 2: 共通処理の抽出（優先度：🟡 重要）
**期間**: 1週間
**工数**: 8時間

#### 2.1 バリデーションサービスの作成
**工数**: 3時間

```ruby
# 新規作成予定
class LineValidationService
  # 日付検証
  # 時間検証
  # 従業員名検証
  # 入力値検証
end
```

**移行対象メソッド**:
- `validate_shift_date`
- `validate_shift_time`
- `valid_employee_id_format?`
- `parse_employee_selection`
- `find_employees_by_name`

#### 2.2 通知サービスの統合
**工数**: 3時間

```ruby
# 新規作成予定
class LineNotificationService
  # LINE通知
  # メール通知
  # 通知テンプレート管理
end
```

**移行対象メソッド**:
- `send_approval_notification_to_requester`
- `send_shift_exchange_request_notification`
- `send_shift_exchange_request_email_notification`
- `send_shift_exchange_approved_email_notification`
- `send_shift_exchange_denied_email_notification`
- `send_shift_addition_notifications`
- `send_shift_addition_approval_email`
- `send_shift_addition_rejection_email`

#### 2.3 共通ユーティリティサービスの作成
**工数**: 2時間

```ruby
# 新規作成予定
class LineUtilityService
  # 日付・時間フォーマット
  # 従業員情報取得
  # 共通処理
end
```

**移行対象メソッド**:
- `extract_user_id`
- `extract_group_id`
- `group_message?`
- `individual_message?`
- `employee_already_linked?`
- `get_authentication_status`
- `determine_role_from_freee`
- `generate_request_id`

### Phase 3: バックエンド処理の統合（優先度：🟡 重要）
**期間**: 2週間
**工数**: 12時間

#### 3.1 シフト交代処理の統合
**工数**: 6時間

**現状の問題**:
- `ShiftExchangesController`と`LineBotService`で同じビジネスロジックが重複
- シフト交代依頼作成、承認・否認処理が重複

**統合計画**:
```ruby
# 新規作成予定
class ShiftExchangeService
  # シフト交代依頼作成（LINE・Web共通）
  # 承認・否認処理（LINE・Web共通）
  # 状況確認処理（LINE・Web共通）
  # キャンセル処理（LINE・Web共通）
end
```

**統合対象**:
- `ShiftExchangesController#create`
- `ShiftApprovalsController#approve`、`#reject`
- `LineBotService`のシフト交代関連メソッド

#### 3.2 シフト追加処理の統合
**工数**: 4時間

**現状の問題**:
- シフト追加依頼作成、承認・否認処理が重複

**統合計画**:
```ruby
# 新規作成予定
class ShiftAdditionService
  # シフト追加依頼作成（LINE・Web共通）
  # 承認・否認処理（LINE・Web共通）
  # 重複チェック処理（LINE・Web共通）
end
```

#### 3.3 認証処理の統合
**工数**: 2時間

**現状の問題**:
- 認証処理がLINE専用になっている

**統合計画**:
```ruby
# 新規作成予定
class AuthenticationService
  # 認証フロー管理（LINE・Web共通）
  # 認証コード生成・検証（LINE・Web共通）
  # 従業員検索（LINE・Web共通）
end
```

### Phase 4: コントローラーの簡素化（優先度：🟢 通常）
**期間**: 1週間
**工数**: 4時間

#### 4.1 LineBotServiceの簡素化
**工数**: 2時間

```ruby
# リファクタリング後
class LineBotService
  def initialize
    @auth_service = LineAuthenticationService.new
    @shift_service = LineShiftService.new
    @exchange_service = LineShiftExchangeService.new
    @addition_service = LineShiftAdditionService.new
    @message_service = LineMessageService.new
    @conversation_service = LineConversationService.new
    @validation_service = LineValidationService.new
    @notification_service = LineNotificationService.new
    @utility_service = LineUtilityService.new
  end

  def handle_message(event)
    # 簡潔なルーティング処理のみ
    case determine_command_type(event)
    when :postback
      handle_postback_event(event)
    when :command
      handle_command_event(event)
    when :stateful
      handle_stateful_event(event)
    end
  end

  private

  def determine_command_type(event)
    # コマンドタイプの判定
  end

  def handle_postback_event(event)
    # Postback処理のルーティング
  end

  def handle_command_event(event)
    # コマンド処理のルーティング
  end

  def handle_stateful_event(event)
    # 会話状態処理のルーティング
  end
end
```

#### 4.2 Webコントローラーの簡素化
**工数**: 2時間

**統合後のコントローラー**:
```ruby
# リファクタリング後
class ShiftExchangesController < ApplicationController
  def create
    result = ShiftExchangeService.create_exchange_request(
      current_employee_id,
      exchange_params
    )
    
    if result[:success]
      redirect_to shifts_path, notice: result[:message]
    else
      redirect_to new_shift_exchange_path, alert: result[:message]
    end
  end
end

class ShiftApprovalsController < ApplicationController
  def approve
    result = ShiftExchangeService.approve_exchange(
      current_employee_id,
      params[:id]
    )
    
    if result[:success]
      redirect_to shift_approvals_path, notice: result[:message]
    else
      redirect_to shift_approvals_path, alert: result[:message]
    end
  end
end
```

## 実装手順

### 1. 準備段階
1. 既存テストの実行と結果確認
2. リファクタリング対象メソッドの特定
3. 依存関係の分析

### 2. 段階的実装
1. **Phase 1**: 責任の分離（各サービスを順次作成）
2. **Phase 2**: 共通処理の抽出
3. **Phase 3**: バックエンド処理の統合
4. **Phase 4**: コントローラーの簡素化

### 3. テスト実行
各段階で以下を実行：
- 既存テストの実行
- 新規サービスの単体テスト作成
- 統合テストの実行
- 手動テストの実行

## 期待される効果

### 1. 保守性の向上
- 各サービスの責任が明確
- 変更の影響範囲が限定
- バグの特定・修正が容易

### 2. テスタビリティの向上
- 各サービスの単体テストが容易
- モック・スタブの使用が簡単
- テストの実行速度向上

### 3. 可読性の向上
- コードの意図が明確
- 新規開発者の理解が容易
- ドキュメント化が簡単

### 4. 拡張性の向上
- 新機能の追加が容易
- 既存機能の修正が安全
- コードの再利用性向上

### 5. バックエンド処理の統合効果
- ビジネスロジックの一元化
- バグ修正時の影響範囲の限定
- 機能追加時の重複実装の回避

## リスク管理

### 1. 既存機能への影響
- 各段階で既存テストを実行
- リファクタリング前後で動作が一致することを確認
- 段階的な実装により影響範囲を限定

### 2. テストの維持
- 既存のテストを維持
- 新規サービスのテストを追加
- 統合テストの実行

### 3. パフォーマンスへの影響
- 各段階でパフォーマンステストを実行
- 必要に応じて最適化を実施

## 工数見積もり

| フェーズ | 工数 | 期間 | 優先度 |
|---------|------|------|--------|
| Phase 1: 責任の分離 | 16時間 | 2-3週間 | 🔴 最高 |
| Phase 2: 共通処理の抽出 | 8時間 | 1週間 | 🟡 重要 |
| Phase 3: バックエンド処理の統合 | 12時間 | 2週間 | 🟡 重要 |
| Phase 4: コントローラーの簡素化 | 4時間 | 1週間 | 🟢 通常 |
| **合計** | **40時間** | **6-7週間** | - |

## まとめ

このリファクタリング計画により、以下の効果が期待されます：

1. **コード品質の大幅向上**: 2,294行の巨大クラスを適切なサイズのサービスに分割
2. **保守性の向上**: 責任の分離により変更の影響範囲を限定
3. **バックエンド処理の統合**: LINE処理とWebアプリ処理の重複を解消
4. **開発効率の向上**: 新機能追加時の重複実装を回避

リファクタリングは長期的な開発効率向上に不可欠であり、高度な機能実装よりも優先して実施することを強く推奨します。
