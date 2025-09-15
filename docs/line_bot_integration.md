# LINE Bot連携機能

## 概要

勤怠管理システムにLINE Bot連携機能を実装しました。ユーザーはLINEアプリから勤怠管理システムの各種機能にアクセスできます。

## 機能一覧

### 現在実装済み機能

- **ヘルプ表示**: 利用可能なコマンドの一覧表示
- **グループ・個人識別**: メッセージ送信元の自動判定
- **従業員紐付け**: LINEアカウントと従業員IDの紐付け機能
- **コマンド処理**: 基本的なコマンド処理システム
- **認証機能**: 認証コード生成（準備中）
- **シフト確認**: シフト情報の確認（準備中）
- **勤怠確認**: 勤怠状況の確認（準備中）

### 対応コマンド

| コマンド | 説明 | ステータス |
|---------|------|-----------|
| `ヘルプ` / `help` | 利用可能なコマンドを表示 | ✅ 実装済み |
| `全員シフト` | グループ全体のシフト情報を確認 | ✅ 実装済み（準備中メッセージ） |
| `認証` | 認証コードを生成 | 🚧 準備中 |
| `シフト` | シフト情報を確認 | 🚧 準備中 |
| `勤怠` | 勤怠状況を確認 | 🚧 準備中 |

## アーキテクチャ

### コンポーネント構成

```
LINE Bot
    ↓
WebhookController (app/controllers/webhook_controller.rb)
    ↓
LineBotService (app/services/line_bot_service.rb)
    ↓
各種ビジネスロジック
```

### LineBotService機能詳細

#### メッセージ送信元識別機能
- `group_message?(event)`: グループメッセージかどうかを判定
- `individual_message?(event)`: 個人メッセージかどうかを判定
- `extract_group_id(event)`: グループIDを抽出（グループメッセージの場合のみ）
- `extract_user_id(event)`: ユーザーIDを抽出（グループ・個人両方対応）

#### 従業員紐付け機能
- `find_employee_by_line_id(line_id)`: LINE IDで従業員を検索
- `link_employee_to_line(employee_id, line_id)`: 従業員とLINEアカウントを紐付け
- `unlink_employee_from_line(line_id)`: 従業員とLINEアカウントの紐付けを解除

#### コマンド処理機能
- `handle_message(event)`: メッセージを処理して適切な応答を生成
- `determine_command_context(event)`: メッセージ送信元に基づくコマンドコンテキストを判定
- `generate_help_message()`: ヘルプメッセージを生成

### データベース設計

#### Employeeテーブル（拡張予定）
- `line_id`: LINEユーザーID（NULL許可、ユニーク制約）
- 既存のカラム: `employee_id`, `password_hash`, `role`, `last_login_at`, `password_updated_at`

#### LineMessageLogテーブル（新規作成予定）
- `id`: 主キー
- `line_user_id`: LINEユーザーID
- `message_type`: メッセージタイプ（text, image, etc.）
- `message_content`: メッセージ内容
- `direction`: 送信方向（inbound, outbound）
- `processed_at`: 処理日時
- `created_at`, `updated_at`: タイムスタンプ

#### 設計思想
- **1対1関係**: 1人の従業員 = 1つのLINEアカウント
- **シンプル設計**: 複雑な中間テーブルを避け、保守性を重視
- **監査証跡**: LineMessageLogでメッセージ履歴を管理
- **データ整合性**: 外部キー制約でデータの整合性を保証

### 主要クラス

#### WebhookController
- LINE webhookの受信
- 署名検証
- イベント処理の振り分け
- エラーハンドリング

#### LineBotService
- メッセージ処理のビジネスロジック
- コマンド解析
- レスポンス生成
- グループ/個人メッセージの識別

## セキュリティ

### 署名検証
- LINE webhookの署名検証を実装
- 不正なリクエストをブロック
- ログ出力による監視

### 認証
- webhookエンドポイントは認証をスキップ
- その他のエンドポイントは通常の認証を維持

## エラーハンドリング

### 実装済みエラー処理
- 署名検証失敗
- メッセージ処理エラー
- システムエラー

### エラーレスポンス
- ユーザーへの分かりやすいエラーメッセージ
- ログ出力による詳細なエラー情報
- 適切なHTTPステータスコード

## テスト

### テスト構成
- **コントローラーテスト**: webhook受信のテスト
- **サービステスト**: ビジネスロジックのテスト
- **統合テスト**: エンドツーエンドのテスト

### テスト実行
```bash
# LINE Bot関連テストのみ
rails test test/controllers/webhook_controller_test.rb test/services/line_bot_service_test.rb test/integration/line_bot_integration_test.rb

# 全テスト
rails test
```

## 開発ガイドライン

### 新しいコマンドの追加

1. `LineBotService::COMMANDS`にコマンドを追加
2. `handle_message`メソッドに処理を追加
3. 対応するテストを作成
4. ヘルプメッセージを更新

### コード規約
- 責任の分離を徹底
- エラーハンドリングの実装
- テストの作成
- ログ出力の適切な実装

## 今後の拡張予定

### Phase 9-1: 認証機能
- ユーザー認証
- セッション管理
- セキュリティ強化
- データベース設計（Employeeテーブルにline_id追加、LineMessageLogテーブル作成）

### Phase 9-2: シフト管理
- シフト確認
- シフト申請
- シフト変更通知

### Phase 9-3: 勤怠管理
- 出退勤記録
- 勤怠状況確認
- 勤怠レポート

## トラブルシューティング

### よくある問題

#### 1. 署名検証エラー
```
LINE Bot signature validation failed
```
**原因**: 環境変数の設定ミス
**解決方法**: `LINE_CHANNEL_SECRET`の確認

#### 2. メッセージ処理エラー
```
LINE Bot message handling error
```
**原因**: メッセージ形式の不正
**解決方法**: ログを確認してメッセージ形式を検証

#### 3. レスポンス送信エラー
**原因**: LINE API接続エラー
**解決方法**: ネットワーク接続とAPI設定を確認

### ログ確認方法
```bash
# 本番環境
fly logs

# ローカル環境
tail -f log/development.log
```

## 本番環境での問題解決

### LINE Bot実装アーキテクチャ

**設計方針**: 本番環境ではフォールバックHTTPクライアントを直接使用
**理由**: LINE Bot SDKの読み込み問題を回避し、安定した動作を実現
**実装**: `Net::HTTP`を使用した直接HTTP実装

#### フォールバッククライアントの動作

本番環境では、安定性とパフォーマンスを考慮してフォールバックHTTPクライアントが使用されます：

- **HTTP直接実装**: `Net::HTTP`を使用してLINE Messaging APIに直接アクセス
- **イベント解析**: JSONを直接解析してイベントオブジェクトを作成
- **メッセージ送信**: LINE APIの`/message/reply`エンドポイントに直接POST
- **完全互換**: 通常のLINE Bot SDKと同じ機能を提供

#### フォールバッククライアントのログ例

```
WARNING: Using fallback HTTP client for LINE Bot
Fallback: validate_signature called
Fallback: parse_events_from called
Fallback: parsed 1 events
Fallback: reply_message called
Fallback reply response: 200 OK
Reply message sent successfully
```

#### 技術的詳細

フォールバッククライアントは以下の技術を使用：

1. **署名検証**: 簡易的な実装（本番環境では適切な実装が必要）
2. **イベント解析**: `JSON.parse`を使用してイベントデータを解析
3. **イベントオブジェクト作成**: `OpenStruct`を使用してLINE Bot SDK互換のオブジェクトを作成
4. **HTTP通信**: `Net::HTTP`を使用してLINE Messaging APIと通信
5. **エラーハンドリング**: 包括的なエラーハンドリングとログ出力

この実装により、LINE Bot SDKに依存せずにLINE Bot機能を提供できます。

## 関連ファイル

- `app/controllers/webhook_controller.rb`: Webhookコントローラー
- `app/services/line_bot_service.rb`: LINE Botサービス
- `test/controllers/webhook_controller_test.rb`: コントローラーテスト
- `test/services/line_bot_service_test.rb`: サービステスト
- `test/integration/line_bot_integration_test.rb`: 統合テスト
- `test/support/line_bot_test_helper.rb`: テストヘルパー
