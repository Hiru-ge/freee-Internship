# LINE Bot サービスリファレンス

## 概要

本ドキュメントは、責務分離後のLINE Botサービスクラスの詳細なリファレンスです。各サービスクラスのメソッド、パラメータ、戻り値について説明します。

## サービス一覧

### 1. LineBotService（メインコントローラー）

**ファイル**: `app/services/line_bot_service.rb`

**責任**: LINE Bot のメインエントリーポイント、メッセージルーティング

#### 主要メソッド

##### `handle_message(event)`
**説明**: メッセージ処理のエントリーポイント

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String または Hash（Flex Message）

**処理フロー**:
1. Postbackイベントの場合は `handle_postback_event` に委譲
2. 会話状態をチェックし、状態がある場合は `conversation_service.handle_stateful_message` に委譲
3. コマンド処理を各専門サービスに委譲

##### `handle_postback_event(event)`
**説明**: Postbackイベントの処理

**パラメータ**:
- `event` (Hash): LINE Bot Postbackイベントオブジェクト

**戻り値**: String

**処理フロー**:
1. 認証チェック
2. Postbackデータの解析
3. 各専門サービスに委譲

##### `handle_request_check_command(event)`
**説明**: リクエスト確認コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: Hash（Flex Message）

**処理フロー**:
1. 認証チェック
2. 承認待ちリクエストの取得
3. Flex Messageの生成

### 2. LineAuthenticationService（認証サービス）

**ファイル**: `app/services/line_authentication_service.rb`

**責任**: LINE アカウントと従業員アカウントの紐付け認証

#### 主要メソッド

##### `handle_auth_command(event)`
**説明**: 認証コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. グループメッセージの場合はエラー
2. 既に認証済みの場合は成功メッセージ
3. 従業員名入力待ちの状態に設定

##### `handle_employee_name_input(line_user_id, message_text)`
**説明**: 従業員名入力処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `message_text` (String): 入力された従業員名

**戻り値**: String

**処理フロー**:
1. 従業員名の検索
2. 該当なしの場合はエラーメッセージ
3. 1件の場合は認証コード生成
4. 複数の場合は選択肢を表示

##### `handle_verification_code_input(line_user_id, employee_id, message_text)`
**説明**: 認証コード入力処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `employee_id` (String): 従業員ID
- `message_text` (String): 入力された認証コード

**戻り値**: String

**処理フロー**:
1. 認証コードの検証
2. 有効な場合はLINE アカウントと従業員アカウントを紐付け
3. 成功メッセージの返却

##### `search_employees_by_name(employee_name)`
**説明**: 従業員名検索

**パラメータ**:
- `employee_name` (String): 検索する従業員名

**戻り値**: Array<Employee>

**処理フロー**:
1. 部分一致検索
2. 結果の配列を返却

##### `generate_verification_code_for_employee(employee_id)`
**説明**: 認証コード生成

**パラメータ**:
- `employee_id` (String): 従業員ID

**戻り値**: String

**処理フロー**:
1. 6桁の認証コード生成
2. データベースに保存
3. メール送信
4. 認証コード入力待ちの状態に設定

### 3. LineConversationService（会話状態管理サービス）

**ファイル**: `app/services/line_conversation_service.rb`

**責任**: マルチステップの対話処理における会話状態の管理

#### 主要メソッド

##### `get_conversation_state(line_user_id)`
**説明**: 会話状態の取得

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID

**戻り値**: Hash または nil

**処理フロー**:
1. データベースから有効な状態を取得
2. 状態ハッシュを返却

##### `set_conversation_state(line_user_id, state)`
**説明**: 会話状態の設定

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `state` (Hash): 設定する状態

**戻り値**: Boolean

**処理フロー**:
1. 既存の状態を削除
2. 新しい状態を保存
3. 成功/失敗を返却

##### `clear_conversation_state(line_user_id)`
**説明**: 会話状態のクリア

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID

**戻り値**: Boolean

**処理フロー**:
1. 既存の状態を削除
2. 成功/失敗を返却

##### `handle_stateful_message(line_user_id, message_text, state)`
**説明**: 状態付きメッセージの処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `message_text` (String): メッセージテキスト
- `state` (Hash): 現在の会話状態

**戻り値**: String または Hash（Flex Message）

**処理フロー**:
1. 現在の状態を取得
2. 状態に応じて適切なサービスに委譲
3. 結果を返却

#### 管理する状態

- `waiting_for_employee_name`: 従業員名入力待ち
- `waiting_for_verification_code`: 認証コード入力待ち
- `waiting_for_shift_date`: シフト日付入力待ち
- `waiting_for_shift_selection`: シフト選択待ち
- `waiting_for_employee_selection_exchange`: 従業員選択待ち（シフト交代）
- `waiting_for_confirmation_exchange`: 確認待ち（シフト交代）
- `waiting_for_shift_addition_date`: シフト追加日付入力待ち
- `waiting_for_shift_addition_time`: シフト追加時間入力待ち
- `waiting_for_shift_addition_employee`: シフト追加対象従業員選択待ち
- `waiting_for_shift_addition_confirmation`: シフト追加確認待ち

### 4. LineShiftService（シフト管理サービス）

**ファイル**: `app/services/line_shift_service.rb`

**責任**: シフト情報の取得と表示

#### 主要メソッド

##### `handle_shift_command(event)`
**説明**: 個人シフト確認コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. 認証チェック
2. 従業員情報の取得
3. 今月のシフト情報の取得
4. メッセージの生成

##### `handle_all_shifts_command(event)`
**説明**: 全員シフト確認コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. 認証チェック
2. 全従業員の取得
3. 今月のシフト情報の取得
4. メッセージの生成

##### `get_group_shift_info(employees)`
**説明**: グループシフト情報の取得

**パラメータ**:
- `employees` (Array<Employee>): 従業員の配列

**戻り値**: String

**処理フロー**:
1. 各従業員のシフト情報を取得
2. メッセージの生成

### 5. LineShiftExchangeService（シフト交代サービス）

**ファイル**: `app/services/line_shift_exchange_service.rb`

**責任**: シフト交代リクエストの作成、承認、拒否処理

#### 主要メソッド

##### `handle_shift_exchange_command(event)`
**説明**: シフト交代コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. 認証チェック
2. グループメッセージの確認
3. 日付入力待ちの状態に設定

##### `handle_approval_postback(line_user_id, postback_data, action)`
**説明**: 承認Postbackの処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `postback_data` (String): Postbackデータ
- `action` (String): アクション（approve/reject）

**戻り値**: String

**処理フロー**:
1. リクエストの検索
2. 承認の場合はシフトの所有者を変更
3. 拒否の場合はステータスを更新
4. 結果メッセージの返却

##### `handle_exchange_status_command(event)`
**説明**: シフト交代状況確認コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. 認証チェック
2. 申請者のリクエストを取得
3. 状況メッセージの生成

##### `handle_shift_date_input(line_user_id, message_text)`
**説明**: シフト交代日付入力の処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `message_text` (String): 入力された日付

**戻り値**: String または Hash（Flex Message）

**処理フロー**:
1. 日付形式の検証
2. 過去の日付のチェック
3. シフトの検索
4. Flex Messageの生成

##### `create_shift_exchange_request(line_user_id, shift_id, target_employee_id)`
**説明**: シフト交代リクエストの作成

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `shift_id` (String): シフトID
- `target_employee_id` (String): 対象従業員ID

**戻り値**: String

**処理フロー**:
1. 重複リクエストのチェック
2. リクエストの作成
3. 通知の送信

### 6. LineShiftAdditionService（シフト追加サービス）

**ファイル**: `app/services/line_shift_addition_service.rb`

**責任**: シフト追加リクエストの作成、承認、拒否処理

#### 主要メソッド

##### `handle_shift_addition_command(event)`
**説明**: シフト追加コマンドの処理

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. 認証チェック
2. グループメッセージの確認
3. オーナー権限のチェック
4. 日付入力待ちの状態に設定

##### `handle_shift_addition_approval_postback(line_user_id, postback_data, action)`
**説明**: シフト追加承認Postbackの処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `postback_data` (String): Postbackデータ
- `action` (String): アクション（approve/reject）

**戻り値**: String

**処理フロー**:
1. リクエストの検索
2. 承認の場合はシフトの作成または更新
3. 拒否の場合はステータスを更新
4. 結果メッセージの返却

##### `handle_shift_addition_date_input(line_user_id, message_text)`
**説明**: シフト追加日付入力の処理

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `message_text` (String): 入力された日付

**戻り値**: String

**処理フロー**:
1. 日付形式の検証
2. 過去の日付のチェック
3. 時間入力待ちの状態に設定

##### `create_shift_addition_request(line_user_id, shift_date, start_time, end_time, target_employee_ids)`
**説明**: シフト追加リクエストの作成

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `shift_date` (Date): シフト日付
- `start_time` (Time): 開始時間
- `end_time` (Time): 終了時間
- `target_employee_ids` (Array<String>): 対象従業員IDの配列

**戻り値**: String

**処理フロー**:
1. 重複シフトのチェック
2. リクエストの作成
3. 通知の送信

### 7. LineMessageService（メッセージ生成サービス）

**ファイル**: `app/services/line_message_service.rb`

**責任**: 各種メッセージの生成（Flex Message、テキストメッセージ）

#### 主要メソッド

##### `generate_help_message(event)`
**説明**: ヘルプメッセージの生成

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. グループ/個人メッセージの判定
2. 適切なヘルプメッセージの生成

##### `generate_shift_flex_message_for_date(shifts, date)`
**説明**: シフトFlex Messageの生成

**パラメータ**:
- `shifts` (Array<Shift>): シフトの配列
- `date` (Date): 日付

**戻り値**: Hash（Flex Message）

**処理フロー**:
1. シフト情報の整理
2. Flex Messageの生成

##### `generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)`
**説明**: 承認待ちリクエストFlex Messageの生成

**パラメータ**:
- `pending_exchange_requests` (Array<ShiftExchange>): 承認待ちシフト交代リクエスト
- `pending_addition_requests` (Array<ShiftAddition>): 承認待ちシフト追加リクエスト

**戻り値**: Hash（Flex Message）

**処理フロー**:
1. リクエスト情報の整理
2. Flex Messageの生成

##### `generate_text_message(text)`
**説明**: テキストメッセージの生成

**パラメータ**:
- `text` (String): テキスト

**戻り値**: Hash（LINE Bot メッセージ）

**処理フロー**:
1. テキストメッセージオブジェクトの生成

### 8. LineValidationService（バリデーションサービス）

**ファイル**: `app/services/line_validation_service.rb`

**責任**: 各種入力値の検証

#### 主要メソッド

##### `validate_shift_date(date_string)`
**説明**: シフト日付の検証

**パラメータ**:
- `date_string` (String): 日付文字列

**戻り値**: Hash（検証結果）

**処理フロー**:
1. 日付形式の検証
2. 過去の日付のチェック
3. 結果の返却

##### `validate_shift_time(start_time_string, end_time_string)`
**説明**: シフト時間の検証

**パラメータ**:
- `start_time_string` (String): 開始時間文字列
- `end_time_string` (String): 終了時間文字列

**戻り値**: Hash（検証結果）

**処理フロー**:
1. 時間形式の検証
2. 開始時間 < 終了時間のチェック
3. 結果の返却

##### `validate_employee_name(employee_name)`
**説明**: 従業員名の検証

**パラメータ**:
- `employee_name` (String): 従業員名

**戻り値**: Hash（検証結果）

**処理フロー**:
1. 空文字のチェック
2. 長さのチェック
3. 文字種のチェック
4. 結果の返却

##### `validate_shift_overlap(employee_id, date, start_time, end_time)`
**説明**: シフト重複の検証

**パラメータ**:
- `employee_id` (String): 従業員ID
- `date` (Date): 日付
- `start_time` (Time): 開始時間
- `end_time` (Time): 終了時間

**戻り値**: Hash（検証結果）

**処理フロー**:
1. 既存シフトの検索
2. 重複のチェック
3. 結果の返却

### 9. LineNotificationService（通知サービス）

**ファイル**: `app/services/line_notification_service.rb`

**責任**: LINE メッセージとメール通知の送信

#### 主要メソッド

##### `send_shift_exchange_approval_notification(exchange_request)`
**説明**: シフト交代承認通知の送信

**パラメータ**:
- `exchange_request` (ShiftExchange): シフト交代リクエスト

**戻り値**: Boolean

**処理フロー**:
1. 申請者への通知
2. 承認者への通知
3. メール通知の送信

##### `send_line_message(line_user_id, message)`
**説明**: LINE メッセージの送信

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `message` (Hash): メッセージオブジェクト

**戻り値**: Boolean

**処理フロー**:
1. LINE Bot APIの呼び出し
2. 結果の返却

##### `send_flex_message(line_user_id, flex_message)`
**説明**: Flex Messageの送信

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID
- `flex_message` (Hash): Flex Messageオブジェクト

**戻り値**: Boolean

**処理フロー**:
1. Flex Messageの送信
2. 結果の返却

### 10. LineUtilityService（ユーティリティサービス）

**ファイル**: `app/services/line_utility_service.rb`

**責任**: 共通的なユーティリティ機能

#### 主要メソッド

##### `extract_user_id(event)`
**説明**: ユーザーIDの抽出

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String

**処理フロー**:
1. イベントからユーザーIDを抽出
2. 結果の返却

##### `extract_group_id(event)`
**説明**: グループIDの抽出

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: String または nil

**処理フロー**:
1. イベントからグループIDを抽出
2. 結果の返却

##### `group_message?(event)`
**説明**: グループメッセージの判定

**パラメータ**:
- `event` (Hash): LINE Bot イベントオブジェクト

**戻り値**: Boolean

**処理フロー**:
1. イベントタイプの確認
2. 結果の返却

##### `employee_already_linked?(line_user_id)`
**説明**: 従業員リンクの確認

**パラメータ**:
- `line_user_id` (String): LINE ユーザーID

**戻り値**: Boolean

**処理フロー**:
1. データベースでの確認
2. 結果の返却

##### `find_employee_by_line_id(line_id)`
**説明**: LINE IDによる従業員検索

**パラメータ**:
- `line_id` (String): LINE ユーザーID

**戻り値**: Employee または nil

**処理フロー**:
1. データベースでの検索
2. 結果の返却

##### `format_date(date)`
**説明**: 日付のフォーマット

**パラメータ**:
- `date` (Date): 日付

**戻り値**: String

**処理フロー**:
1. 日付のフォーマット
2. 結果の返却

##### `format_time(time)`
**説明**: 時間のフォーマット

**パラメータ**:
- `time` (Time): 時間

**戻り値**: String

**処理フロー**:
1. 時間のフォーマット
2. 結果の返却

## エラーハンドリング

### 共通エラーパターン

1. **認証エラー**: 未認証ユーザーのアクセス
2. **権限エラー**: 権限のない操作
3. **入力値エラー**: 不正な入力値
4. **データベースエラー**: データベース操作の失敗
5. **外部APIエラー**: LINE Bot APIやメール送信の失敗

### エラーメッセージの統一

各サービスで統一されたエラーメッセージを使用：

- 認証エラー: "認証が必要です。「認証」と入力して認証を行ってください。"
- 権限エラー: "この操作を実行する権限がありません。"
- 入力値エラー: "入力値が正しくありません。"
- データベースエラー: "データの処理中にエラーが発生しました。"

## テスト戦略

### 単体テスト

各サービスクラスは独立してテスト可能：

```ruby
# 例: LineAuthenticationService のテスト
test "should handle employee name input" do
  service = LineAuthenticationService.new
  result = service.handle_employee_name_input(@line_user_id, "テスト太郎")
  assert_includes result, "認証コード"
end
```

### 統合テスト

`LineBotService` を通じた統合テスト：

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

### 遅延ロード

サービスクラスは必要時のみ初期化：

```ruby
def conversation_service
  @conversation_service ||= LineConversationService.new
end
```

### データベースクエリ最適化

各サービスで適切なクエリ最適化を実装。

### キャッシュ戦略

会話状態はデータベースに保存され、適切な有効期限管理を実装。

## セキュリティ考慮事項

### 認証・認可

- LINE アカウントと従業員アカウントの紐付け認証
- 適切な権限チェック

### 入力値検証

- `LineValidationService` による包括的な入力値検証
- SQLインジェクション対策

### 機密情報管理

- 環境変数による機密情報の管理
- 認証コードの適切な有効期限管理

## まとめ

このサービスリファレンスにより、各サービスクラスの詳細な仕様を理解し、適切な使用方法を把握できます。責務分離により、各サービスが明確な責任を持ち、保守性とテスタビリティが大幅に向上しました。
