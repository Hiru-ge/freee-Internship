# 勤怠管理システム (Attendance Management System)

勤怠管理・シフト管理・給与管理を行うRailsアプリケーションです。

## 概要

このシステムは、従業員の勤怠管理、シフト管理、給与状況確認を行うWebアプリケーションです。GAS（Google Apps Script）からRuby on Railsに完全移行しました。

## 主な機能

### 認証システム
- **ログイン/ログアウト**: 従業員IDとパスワードによる認証
- **初回パスワード設定**: 新規従業員のパスワード初期設定
- **パスワード変更**: セキュアなパスワード変更機能
- **パスワード忘れ**: メールによるパスワードリセット
- **アクセス制御**: メールアドレス認証によるアクセス制限

### シフト管理
- **シフト確認**: 月間シフト表の表示
- **シフト交代依頼**: 他の従業員への交代依頼
- **シフト追加依頼**: 新しいシフトの追加申請
- **欠勤申請**: 自分のシフトの欠勤申請（未来のシフトのみ） ✅ **新機能**
- **シフト承認**: 管理者によるシフト依頼の承認/否認

### 勤怠管理
- **打刻機能**: 出勤・退勤・休憩の打刻（日本時間で正確な時刻記録）
- **勤怠状況確認**: 日別・月別勤怠記録の表示
- **勤怠統計**: 勤務時間の集計と表示
- **タイムゾーン対応**: Asia/Tokyoタイムゾーンでの正確な時刻処理
- **打刻忘れアラート**: 出勤・退勤打刻忘れの自動検知とメール通知 ✅ **実装完了**
- **ダッシュボード**: 勤怠状況の一覧表示と打刻操作

### 給与管理
- **103万の壁ゲージ**: 年収103万円の壁を視覚的に表示
- **時間帯別時給計算**: 深夜・早朝・休日等の時給計算
- **給与データ表示**: freee APIから取得した給与情報の表示
- **従業員一覧**: 給与管理用の従業員情報表示

### freee API連携
- **従業員情報取得**: リアルタイムでの従業員データ同期
- **給与データ取得**: 最新の給与情報の取得
- **組織情報取得**: 部署・役職情報の取得

### LINE Bot連携 ✅ **実装完了**
- **認証システム**: 従業員名入力による認証コード生成・LINEアカウント紐付け
- **シフト管理**: シフト確認、シフト交代依頼、シフト追加依頼
- **欠勤申請**: シフトの欠勤申請・承認機能 ✅ **新機能**
- **シフト確認**: 個人・全従業員のシフト情報確認（認証必要）
- **シフト交代機能**: Flex Message形式のシフトカード表示と交代依頼
- **シフト交代承認**: Flex Message形式の承認待ちリクエスト表示と承認・拒否処理
- **承認後通知**: 承認・拒否時に申請者にプッシュメッセージ送信
- **ヘルプ表示**: コンテキスト対応の利用可能コマンド表示
- **会話状態管理**: 複数ターンにまたがる認証フローの管理
- **セキュリティ**: 認証チェック機能、グループ・個人チャットの適切な分離
- **データベース設計**: Employeeテーブルにline_id追加、ConversationStateテーブル作成
- **不要機能削除**: 未使用機能の削除によるユーザビリティ向上（Phase 14-1完了）

### メール通知
- **シフト依頼通知**: シフト交代・追加依頼の自動通知
- **承認結果通知**: シフト承認/否認結果の通知
- **システム通知**: 重要なシステム更新の通知

### セキュリティ機能
- **セッションタイムアウト**: 24時間の自動セッション期限切れ
- **CSRF保護**: クロスサイトリクエストフォージェリ攻撃の防止
- **セキュリティヘッダー**: XSS、クリックジャッキング等の攻撃防止
- **入力値検証**: サーバーサイドでの厳格な入力値チェック

### パフォーマンス最適化
- **N+1問題解決**: データベースクエリの大幅削減
- **API呼び出し最適化**: freee APIの重複呼び出し削減
- **キャッシュ戦略**: 5分間のデータキャッシュ機能
- **レート制限**: API制限への適切な対応

## 技術スタック

- **Backend**: Ruby on Rails 8.0.2
- **Database**: SQLite (全環境)
- **Bot**: LINE Bot API (line-bot-api gem)
- **External APIs**: freee API, Google Sheets API
- **Deployment**: Fly.io (無料枠対応)
- **Testing**: Minitest (TDD approach)

## セットアップ

### 前提条件

- Ruby 3.2.2以上
- SQLite 3.0以上
- LINE Bot アカウント
- freee API アカウント
- Fly.io アカウント (本番デプロイ用)

### インストール

1. リポジトリのクローン
```bash
git clone <repository-url>
cd freee-Internship
```

2. 依存関係のインストール
```bash
bundle install
```

3. 環境変数の設定
```bash
# .envファイルを作成
touch .env
```

以下の内容を`.env`ファイルに記述してください：
```bash
# freee API設定
FREEE_ACCESS_TOKEN=your_freee_access_token_here
FREEE_COMPANY_ID=your_freee_company_id_here

# Gmail SMTP設定
GMAIL_USERNAME=your_gmail_address@gmail.com
GMAIL_APP_PASSWORD=your_gmail_app_password_here

# アプリケーション設定
RAILS_ENV=development
```

4. データベースの作成とマイグレーション
```bash
rails db:create
rails db:migrate
```

5. サーバーの起動
```bash
rails server
```

## 環境変数

以下の環境変数を`.env`ファイルに設定してください：

### 認証システム用
- `FREEE_ACCESS_TOKEN`: freee API アクセストークン
- `FREEE_COMPANY_ID`: freee API 会社ID
- `GMAIL_USERNAME`: Gmail送信用のメールアドレス
- `GMAIL_APP_PASSWORD`: Gmail送信用のアプリパスワード

### LINE Bot用 ✅ **実装完了**
- `LINE_CHANNEL_SECRET`: LINE Bot チャンネルシークレット
- `LINE_CHANNEL_TOKEN`: LINE Bot チャンネルトークン

### Google Sheets用（将来実装予定）
- `GOOGLE_SHEETS_CREDENTIALS_PATH`: Google Sheets API認証情報のパス
- `GOOGLE_SHEETS_SPREADSHEET_ID`: Google Sheets スプレッドシートID

## デプロイ

Fly.ioへのデプロイ手順：

1. Fly.io CLIのインストール
2. Fly.ioアプリの作成
3. 環境変数の設定
4. デプロイの実行

```bash
# Fly.io CLIのインストール
curl -L https://fly.io/install.sh | sh

# アプリの作成
fly apps create your-app-name

# 環境変数の設定
fly secrets set FREEE_ACCESS_TOKEN=your_token -a your-app-name
fly secrets set FREEE_COMPANY_ID=your_company_id -a your-app-name
fly secrets set GMAIL_USERNAME=your_email -a your-app-name
fly secrets set GMAIL_APP_PASSWORD=your_app_password -a your-app-name

# デプロイの実行
fly deploy
```

詳細なデプロイ手順は [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) を参照してください。

## テスト実装

### テストスイート概要
- **総テスト数**: 414テスト
- **アサーション数**: 1072アサーション
- **成功率**: 100%
- **テストファイル数**: 6ファイル（統合後）
- **機能見直し後のテスト最適化完了**
- **欠勤申請機能のテスト充実化完了**

### 統合されたテストファイル構成
- **`line_bot_service_test.rb`** (3,631行、120テスト): LINE Bot関連の全機能テスト（欠勤申請機能含む）
- **`shift_deletion_service_test.rb`** (337行、13テスト): 欠勤申請サービステスト
- **`line_shift_deletion_service_test.rb`** (176行、8テスト): LINE欠勤申請サービステスト
- **`line_message_service_test.rb`** (256行、10テスト): LINEメッセージサービステスト
- **`line_conversation_service_test.rb`** (222行、13テスト): LINE会話状態管理テスト
- **`shift_services_test.rb`** (580行、19テスト): シフト管理・パフォーマンス最適化テスト
- **`clock_services_test.rb`** (416行、20テスト): 時計・通知・賃金サービステスト
- **`security_test.rb`** (433行、39テスト): セキュリティ・認証・コントローラーテスト
- **`error_handling_test.rb`** (172行、複数テスト): エラーハンドリングテスト
- **`access_control_service_test.rb`** (200行、12テスト): アクセス制限機能テスト

### テスト実行方法
```bash
# 全テスト実行
rails test

# 統合後のテストファイル実行
rails test test/services/line_bot_service_test.rb
rails test test/services/shift_services_test.rb
rails test test/services/clock_services_test.rb
rails test test/controllers/security_test.rb
rails test test/controllers/error_handling_test.rb

# 特定のテストメソッド実行
rails test test/services/line_bot_service_test.rb -n test_should_handle_shift_exchange_command
```

### 統合の効果
- **テストファイル数**: 11ファイル → 10ファイル（機能別に最適化）
- **関連機能の集約**: 機能ごとにテストが整理され、保守性が向上
- **テスト通過率の維持**: 100%のテスト通過率を維持
- **欠勤申請機能のテスト充実**: 44テストケース、168アサーションを追加

詳細なテスト仕様については [TESTING.md](docs/TESTING.md) を参照してください。

### 打刻忘れアラートの定期実行

本番環境では、GitHub Actionsにより打刻忘れアラートが自動実行されます：

```yaml
# .github/workflows/clock-reminder.yml
on:
  schedule:
    - cron: '15,30,45,0 * * * *'  # 毎時0分、15分、30分、45分に実行（日本時間 JST）
```

**アラート仕様**:
- **出勤打刻忘れ**: シフト開始時刻を過ぎて1時間以内に出勤打刻がない場合にメール通知
- **退勤打刻忘れ**: シフト終了時刻を過ぎて1時間以内に退勤打刻がない場合にメール通知

**手動実行**:
```bash
# 本番環境で手動実行
fly ssh console -a your-app-name -C "bundle exec rails clock_reminder:check_all"

# GitHub Actionsで手動実行
# GitHubのActionsタブから「Clock Reminder Check」を手動実行
```

**注意**: fly.ioの無料枠では一定時間アクセスがないとマシンが停止するため、GitHub Actionsを使用して定期実行を行います。

## 開発状況

- ✅ Rails移行完了
- ✅ 認証システム完全移行
- ✅ シフト管理システム完全移行
- ✅ セキュリティ機能強化完了
- ✅ パフォーマンス最適化完了
- ✅ 勤怠管理システム完全移行
- ✅ 給与管理システム完全移行
- ✅ freee API連携完了
- ✅ メール通知システム完了（Gmail SMTP対応）
- ✅ UI/UXデザイン改善完了
- ✅ Fly.ioデプロイ完了
- ✅ LINE Bot連携基本機能完了（Phase 9-0）
- ✅ LINE Bot連携コマンドシステム完了（Phase 9-1）
- ✅ LINE Bot連携シフト交代機能完了（Phase 9-2）
- ✅ 不要機能削除完了（Phase 14-1）
- ✅ 機能見直し完了（Phase 14-2）
- ✅ リファクタリング完了（Phase 14-3）
- ✅ 実装クリーンアップ完了（Phase 14-4）
- ✅ アクセス制限機能完了（Phase 14-5）
- ✅ 欠勤申請機能完了（Phase 14-6）
- ✅ 欠勤申請機能のLINE連携完了（Phase 14-7）
- ✅ アプリケーション本体リファクタリング完了（Phase 16-1〜16-4）
  - ✅ コントローラーファイル統合・分離と適切な共通化（Phase 16-1）
  - ✅ コード品質改善とConcern最適化（Phase 16-2）
  - ✅ 保守性向上（可読性向上とファイル構造最適化）（Phase 16-3）
  - ✅ サービス層リファクタリング（LINE Bot関連サービス再構成、重複メソッド統合）（Phase 16-4）

## アーキテクチャ

### コントローラー構成（Phase 16-3完了後）
```
1. 基底（ApplicationController）
   - 認証・セッション・エラーハンドリングのConcern統合
   - 共通処理の一元化（38行）

2. 共通機能ディレクトリ（concerns/）
   - Authentication: 認証・認可・セッション管理（315行）
   - Security: セキュリティヘッダー設定（24行）
   - FreeeApiHelper: API連携・ユーティリティ（45行）
   - ErrorHandler: エラーハンドリング・バリデーション（195行）
   - InputValidation: 入力値検証（436行）
   - ServiceResponseHandler: サービスレスポンス処理（93行）

3. 勤怠打刻（AttendanceController）
   - 出勤・退勤打刻機能
   - ダッシュボード表示機能

4. 勤怠リマインダー（ClockReminderController）
   - 打刻忘れアラート機能

5. シフト表示（ShiftDisplayController）
   - シフトカレンダー表示
   - シフトデータ取得API

6. シフト交代（ShiftExchangesController）
   - シフト交代依頼の作成・管理

7. シフト追加（ShiftAdditionsController）
   - シフト追加依頼の作成・管理

8. シフト削除（ShiftDeletionsController）
   - 欠勤申請の作成・管理

9. シフト承認（ShiftApprovalsController）
   - シフト依頼の承認・否認
   - API機能

10. 給与（WagesController）
    - 給与情報表示
    - 従業員一覧取得

11. 認証・アクセス制御（AuthController）
    - ログイン・ログアウト機能
    - アクセス制御機能
    - ホームページ機能

12. LINEbot（WebhookController）
    - LINE Bot Webhook処理
```

### 設計原則
- **単一責任原則**: 各コントローラーは明確な責任範囲を持つ
- **DRY原則**: 共通処理はConcernに分離（完全に実装済み）
- **KISS原則**: シンプルで理解しやすい構造
- **透明性**: コントローラー名から機能が明確に分かる

### 共通化の現状
- **完了**: ApplicationControllerの分割、InputValidationの共通化、FreeeApiServiceの共通インスタンス化
- **完了**: Concernの粒度見直しと統合・再配置（9個から6個に最適化）
- **完了**: Concern内メソッドの適切な配置（責任範囲に基づく配置）
- **完了**: 共通化Concernの作成と適用（Authorization、FreeeApiHelper、ServiceResponseHandler）
- **完了**: 可読性向上（『リーダブル・コード』の「コードの整形」観点に基づく改善）
- **完了**: ファイル構造最適化（KISS原則に基づく構造の最適化）
- **今後の課題**: 依存関係の整理、循環依存の解消、インターフェースの定義、設定管理の統一

### テスト品質
- **テスト通過率**: 100% (436 runs, 1057 assertions, 0 failures, 0 errors, 0 skips)
- **テストカバレッジ**: 全コントローラー・サービス・モデルの100%カバレッジ
- **テスト品質**: 意味のあるテストに改善済み
- **Phase 16-4完了**: サービス層リファクタリング完了（LINE Bot関連サービス再構成、重複メソッド統合、テストファイル復元・統合、可読性向上、定義順改善）
- **Phase 16-5完了**: モデル・ヘルパー・Mailerリファクタリング完了（可読性向上、ヘルパーファイル削除、責任範囲の明確化）

## ドキュメント

- [デプロイガイド](DEPLOYMENT_GUIDE.md) - Fly.ioへのデプロイ手順とトラブルシューティング
- [実装状況](docs/implementation-status.md) - 現在の実装状況と進捗
- [セキュリティ強化](docs/security-enhancement.md) - セキュリティ機能の詳細
- [パフォーマンス最適化](docs/performance-optimization.md) - N+1問題解決とAPI最適化
- [データベース設計](docs/schema-database.md) - データベーススキーマと設計思想
- [API仕様書](docs/api-specification.md) - 外部API連携の仕様
- [セットアップガイド](docs/setup-guide.md) - 開発環境の構築手順
- [LINE Bot連携](docs/line-integration.md) - LINE Bot機能の詳細
- [LINE Bot データベース設計](docs/line_bot_database_design.md) - LINE Bot連携のデータベース設計
- [LINE Bot デプロイ手順](docs/line_bot_deployment.md) - LINE Botのデプロイと設定
- [LINE Bot API仕様](docs/line_bot_api_spec.md) - LINE Bot APIの仕様書
- [コンポーネント依存関係](docs/COMPONENT_DEPENDENCIES.md) - アプリケーション機能とコンポーネント依存関係
- [変更履歴](docs/CHANGELOG.md) - システムの変更履歴

詳細な実装状況は `docs/` ディレクトリ内のドキュメントを参照してください。

## ライセンス

MIT License
