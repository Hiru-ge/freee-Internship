# LINE Bot連携機能

## 概要

勤怠管理システムにLINE Bot連携機能を実装しました。ユーザーはLINEアプリから勤怠管理システムの各種機能にアクセスできます。

## 機能一覧

### 現在実装済み機能

- **ヘルプ表示**: 利用可能なコマンドの一覧表示
- **認証機能**: 認証コード生成（準備中）
- **シフト確認**: シフト情報の確認（準備中）
- **勤怠確認**: 勤怠状況の確認（準備中）

### 対応コマンド

| コマンド | 説明 | ステータス |
|---------|------|-----------|
| `ヘルプ` / `help` | 利用可能なコマンドを表示 | ✅ 実装済み |
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

## 関連ファイル

- `app/controllers/webhook_controller.rb`: Webhookコントローラー
- `app/services/line_bot_service.rb`: LINE Botサービス
- `test/controllers/webhook_controller_test.rb`: コントローラーテスト
- `test/services/line_bot_service_test.rb`: サービステスト
- `test/integration/line_bot_integration_test.rb`: 統合テスト
- `test/support/line_bot_test_helper.rb`: テストヘルパー
