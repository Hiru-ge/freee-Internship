# LINE Bot アーキテクチャ設計書

## 概要

本ドキュメントは、LINE Bot の責務分離後のアーキテクチャ設計について説明します。巨大な `LineBotService` クラス（2,303行）を9つの専門サービスクラスに分割し、単一責任原則に基づいた設計を実現しました。

## アーキテクチャ概要

### 設計原則

1. **単一責任原則 (Single Responsibility Principle)**
   - 各サービスクラスは明確な責任を持つ
   - 機能ごとに独立したクラスに分離

2. **依存性注入 (Dependency Injection)**
   - 遅延ロードパターンによる効率的な初期化
   - 循環依存の回避

3. **テスタビリティ (Testability)**
   - 各機能の独立したテスト実行が可能
   - モック化しやすい設計

4. **保守性 (Maintainability)**
   - 変更影響範囲の限定
   - コードの可読性向上

## サービス構成

### 1. LineBotService（メインコントローラー）

**責任**: LINE Bot のメインエントリーポイント、メッセージルーティング

**主要メソッド**:
- `handle_message(event)` - メッセージ処理のエントリーポイント
- `handle_postback_event(event)` - Postbackイベントの処理
- `handle_request_check_command(event)` - リクエスト確認コマンドの処理

**依存関係**: 全サービスクラス（遅延ロード）

### 2. LineAuthenticationService（認証サービス）

**責任**: LINE アカウントと従業員アカウントの紐付け認証

**主要メソッド**:
- `handle_auth_command(event)` - 認証コマンドの処理
- `handle_employee_name_input(line_user_id, message_text)` - 従業員名入力処理
- `handle_verification_code_input(line_user_id, employee_id, message_text)` - 認証コード入力処理
- `search_employees_by_name(employee_name)` - 従業員名検索
- `generate_verification_code_for_employee(employee_id)` - 認証コード生成

**データベース操作**:
- `Employee` モデルとの連携
- `VerificationCode` モデルとの連携

### 3. LineConversationService（会話状態管理サービス）

**責任**: マルチステップの対話処理における会話状態の管理

**主要メソッド**:
- `get_conversation_state(line_user_id)` - 会話状態の取得
- `set_conversation_state(line_user_id, state)` - 会話状態の設定
- `clear_conversation_state(line_user_id)` - 会話状態のクリア
- `handle_stateful_message(line_user_id, message_text, state)` - 状態付きメッセージの処理

**管理する状態**:
- `waiting_for_employee_name` - 従業員名入力待ち
- `waiting_for_verification_code` - 認証コード入力待ち
- `waiting_for_shift_date` - シフト日付入力待ち
- `waiting_for_shift_selection` - シフト選択待ち
- `waiting_for_employee_selection_exchange` - 従業員選択待ち（シフト交代）
- `waiting_for_confirmation_exchange` - 確認待ち（シフト交代）
- `waiting_for_shift_addition_date` - シフト追加日付入力待ち
- `waiting_for_shift_addition_time` - シフト追加時間入力待ち
- `waiting_for_shift_addition_employee` - シフト追加対象従業員選択待ち
- `waiting_for_shift_addition_confirmation` - シフト追加確認待ち

### 4. LineShiftService（シフト管理サービス）

**責任**: シフト情報の取得と表示

**主要メソッド**:
- `handle_shift_command(event)` - 個人シフト確認コマンドの処理
- `handle_all_shifts_command(event)` - 全員シフト確認コマンドの処理
- `get_group_shift_info(employees)` - グループシフト情報の取得

**データベース操作**:
- `Shift` モデルとの連携
- `Employee` モデルとの連携

### 5. LineShiftExchangeService（シフト交代サービス）

**責任**: シフト交代リクエストの作成、承認、拒否処理

**主要メソッド**:
- `handle_shift_exchange_command(event)` - シフト交代コマンドの処理
- `handle_approval_postback(line_user_id, postback_data, action)` - 承認Postbackの処理
- `handle_exchange_status_command(event)` - シフト交代状況確認コマンドの処理
- `handle_cancel_request_command(event)` - 依頼キャンセルコマンドの処理
- `handle_shift_date_input(line_user_id, message_text)` - シフト交代日付入力の処理
- `handle_shift_selection_input(line_user_id, message_text, state)` - シフト選択入力の処理
- `handle_employee_selection_input_exchange(line_user_id, message_text, state)` - 従業員選択入力の処理
- `handle_confirmation_input(line_user_id, message_text, state)` - 確認入力の処理
- `create_shift_exchange_request(line_user_id, shift_id, target_employee_id)` - シフト交代リクエストの作成

**データベース操作**:
- `ShiftExchange` モデルとの連携
- `Shift` モデルとの連携
- `Employee` モデルとの連携

### 6. LineShiftAdditionService（シフト追加サービス）

**責任**: シフト追加リクエストの作成、承認、拒否処理

**主要メソッド**:
- `handle_shift_addition_command(event)` - シフト追加コマンドの処理
- `handle_shift_addition_approval_postback(line_user_id, postback_data, action)` - シフト追加承認Postbackの処理
- `handle_shift_addition_date_input(line_user_id, message_text)` - シフト追加日付入力の処理
- `handle_shift_addition_time_input(line_user_id, message_text, state)` - シフト追加時間入力の処理
- `handle_shift_addition_employee_input(line_user_id, message_text, state)` - シフト追加対象従業員入力の処理
- `handle_shift_addition_confirmation_input(line_user_id, message_text, state)` - シフト追加確認入力の処理
- `create_shift_addition_request(line_user_id, shift_date, start_time, end_time, target_employee_ids)` - シフト追加リクエストの作成

**データベース操作**:
- `ShiftAddition` モデルとの連携
- `Shift` モデルとの連携
- `Employee` モデルとの連携

### 7. LineMessageService（メッセージ生成サービス）

**責任**: 各種メッセージの生成（Flex Message、テキストメッセージ）

**主要メソッド**:
- `generate_help_message(event)` - ヘルプメッセージの生成
- `generate_shift_flex_message_for_date(shifts, date)` - シフトFlex Messageの生成
- `generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)` - 承認待ちリクエストFlex Messageの生成
- `generate_shift_addition_response(addition_request, status)` - シフト追加レスポンスの生成
- `generate_text_message(text)` - テキストメッセージの生成
- `generate_error_message(message)` - エラーメッセージの生成
- `generate_success_message(message)` - 成功メッセージの生成

### 8. LineValidationService（バリデーションサービス）

**責任**: 各種入力値の検証

**主要メソッド**:
- `validate_shift_date(date_string)` - シフト日付の検証
- `validate_shift_time(start_time_string, end_time_string)` - シフト時間の検証
- `validate_employee_id_format(employee_id)` - 従業員ID形式の検証
- `validate_employee_name(employee_name)` - 従業員名の検証
- `validate_verification_code(code)` - 認証コードの検証
- `parse_employee_selection(message_text, available_employees)` - 従業員選択の解析
- `validate_shift_overlap(employee_id, date, start_time, end_time)` - シフト重複の検証
- `validate_date_range(start_date, end_date)` - 日付範囲の検証
- `validate_time_range(start_time, end_time)` - 時間範囲の検証
- `validate_request_id(request_id)` - リクエストIDの検証
- `validate_message_text(message_text)` - メッセージテキストの検証
- `validate_numeric_input(input, min, max)` - 数値入力の検証
- `validate_selection(selection, options)` - 選択肢の検証
- `validate_confirmation_input(input)` - 確認入力の検証

### 9. LineNotificationService（通知サービス）

**責任**: LINE メッセージとメール通知の送信

**主要メソッド**:
- `send_shift_exchange_approval_notification(exchange_request)` - シフト交代承認通知の送信
- `send_shift_exchange_rejection_notification(exchange_request)` - シフト交代拒否通知の送信
- `send_shift_exchange_request_notification(exchange_request)` - シフト交代依頼通知の送信
- `send_shift_addition_approval_notification(addition_request)` - シフト追加承認通知の送信
- `send_shift_addition_rejection_notification(addition_request)` - シフト追加拒否通知の送信
- `send_shift_addition_request_notification(addition_request)` - シフト追加依頼通知の送信
- `send_verification_code_notification(employee, verification_code)` - 認証コード通知の送信
- `send_authentication_success_notification(employee)` - 認証成功通知の送信
- `send_line_message(line_user_id, message)` - LINE メッセージの送信
- `send_flex_message(line_user_id, flex_message)` - Flex Messageの送信
- `send_group_notification(group_id, message)` - グループ通知の送信

**外部連携**:
- LINE Bot API
- メール送信（SMTP）

### 10. LineUtilityService（ユーティリティサービス）

**責任**: 共通的なユーティリティ機能

**主要メソッド**:
- `extract_user_id(event)` - ユーザーIDの抽出
- `extract_group_id(event)` - グループIDの抽出
- `group_message?(event)` - グループメッセージの判定
- `employee_already_linked?(line_user_id)` - 従業員リンクの確認
- `find_employee_by_line_id(line_id)` - LINE IDによる従業員検索
- `generate_request_id` - リクエストIDの生成
- `format_date(date)` - 日付のフォーマット
- `format_time(time)` - 時間のフォーマット
- `normalize_employee_name(name)` - 従業員名の正規化
- `search_employees_by_name(name)` - 従業員名による検索
- `get_available_employees_for_shift(date, start_time, end_time)` - シフト可能従業員の取得
- `get_overlapping_employees_for_shift(date, start_time, end_time)` - 重複シフト従業員の取得
- `log_message(level, message)` - ログメッセージの出力

## データフロー

### 1. 認証フロー

```
ユーザー → LineBotService → LineAuthenticationService → LineNotificationService
                ↓
        LineConversationService (状態管理)
                ↓
        データベース (Employee, VerificationCode)
```

### 2. シフト交代フロー

```
ユーザー → LineBotService → LineShiftExchangeService → LineConversationService
                ↓                    ↓
        LineMessageService    LineValidationService
                ↓                    ↓
        LineNotificationService   データベース (ShiftExchange, Shift)
```

### 3. シフト追加フロー

```
ユーザー → LineBotService → LineShiftAdditionService → LineConversationService
                ↓                    ↓
        LineMessageService    LineValidationService
                ↓                    ↓
        LineNotificationService   データベース (ShiftAddition, Shift)
```

## 依存関係図

```
LineBotService
├── LineAuthenticationService
├── LineConversationService
│   ├── LineAuthenticationService
│   ├── LineShiftExchangeService
│   ├── LineShiftAdditionService
│   └── LineValidationService
├── LineShiftService
├── LineShiftExchangeService
│   ├── LineValidationService
│   └── LineNotificationService
├── LineShiftAdditionService
│   ├── LineValidationService
│   └── LineNotificationService
├── LineMessageService
├── LineValidationService
├── LineNotificationService
└── LineUtilityService
```

## 設計パターン

### 1. 遅延ロードパターン

各サービスクラスは遅延ロードで初期化され、循環依存を回避しています。

```ruby
def conversation_service
  @conversation_service ||= LineConversationService.new
end
```

### 2. 委譲パターン

`LineBotService` は各専門サービスに処理を委譲し、単一責任原則を実現しています。

```ruby
def handle_message(event)
  # 会話状態をチェック
  state = conversation_service.get_conversation_state(line_user_id)
  if state
    return conversation_service.handle_stateful_message(line_user_id, message_text, state)
  end
  
  # コマンド処理
  command = COMMANDS[message_text]
  case command
  when :auth
    auth_service.handle_auth_command(event)
  when :shift
    shift_service.handle_shift_command(event)
  # ...
  end
end
```

### 3. 状態管理パターン

`LineConversationService` が会話状態を管理し、マルチステップの対話処理を実現しています。

```ruby
def handle_stateful_message(line_user_id, message_text, state)
  current_state = state['state'] || state[:step] || state['step']
  
  case current_state
  when 'waiting_for_employee_name'
    return auth_service.handle_employee_name_input(line_user_id, message_text)
  when 'waiting_for_shift_date'
    return exchange_service.handle_shift_date_input(line_user_id, message_text)
  # ...
  end
end
```

## テスト戦略

### 1. 単体テスト

各サービスクラスは独立してテスト可能です。

```ruby
# 例: LineAuthenticationService のテスト
test "should handle employee name input" do
  service = LineAuthenticationService.new
  result = service.handle_employee_name_input(@line_user_id, "テスト太郎")
  assert_includes result, "認証コード"
end
```

### 2. 統合テスト

`LineBotService` を通じた統合テストも実行可能です。

```ruby
# 例: シフト交代フローの統合テスト
test "should handle complete shift exchange flow" do
  # 1. シフト交代コマンド送信
  # 2. 日付入力
  # 3. シフト選択
  # 4. 従業員選択
  # 5. 確認
  # 6. 結果確認
end
```

## パフォーマンス考慮事項

### 1. 遅延ロード

サービスクラスは必要時のみ初期化され、メモリ効率を向上させています。

### 2. データベースクエリ最適化

各サービスで適切なクエリ最適化を行っています。

### 3. キャッシュ戦略

会話状態はデータベースに保存され、適切な有効期限管理を行っています。

## セキュリティ考慮事項

### 1. 認証・認可

- LINE アカウントと従業員アカウントの紐付け認証
- 適切な権限チェック

### 2. 入力値検証

- `LineValidationService` による包括的な入力値検証
- SQLインジェクション対策

### 3. 機密情報管理

- 環境変数による機密情報の管理
- 認証コードの適切な有効期限管理

## 今後の拡張性

### 1. 新機能追加

新しい機能を追加する際は、適切なサービスクラスに追加するか、新しいサービスクラスを作成します。

### 2. 外部API連携

`LineNotificationService` の拡張により、他の通知チャネルとの連携が可能です。

### 3. データベース変更

各サービスが独立しているため、データベーススキーマの変更時の影響を最小限に抑えられます。

## まとめ

このアーキテクチャ設計により、以下の成果を実現しました：

1. **保守性の向上**: 機能ごとの独立したクラスにより、変更影響範囲を限定
2. **テスタビリティの向上**: 各機能の独立したテスト実行が可能
3. **可読性の向上**: 明確な責任分離により、コードの理解が容易
4. **拡張性の向上**: 新機能追加時の影響を最小化
5. **パフォーマンスの向上**: 遅延ロードとクエリ最適化による効率化

この設計により、LINE Bot の機能拡張と保守が大幅に改善され、長期的な開発効率の向上が期待できます。
