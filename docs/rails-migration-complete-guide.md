# Rails移行完全ガイド

## 1. 概要

Google Apps Scriptベースの勤怠管理システムをRuby on Rails + Herokuに完全移行するための包括的なガイドです。

## 2. 移行の背景

### 2.1. 現在の課題
- **Google Apps Scriptの制約**: 302リダイレクト問題が根本的に解決困難
- **タイムアウト問題**: 6分の実行時間制限でWebhook処理が不安定
- **外部API制限**: 1日のAPI呼び出し数制限
- **レスポンス時間**: 不安定な応答時間

### 2.2. Rails移行の利点
- **安定したWebhook処理**: Herokuでの安定したLINE Webhook処理
- **タイムアウト問題の解決**: 6分制限の解消
- **スケーラビリティ**: 将来的な機能拡張に対応可能
- **既存スキル活用**: Django/Rails経験を最大限活用

## 3. 技術スタック

### 3.1. 移行前（Google Apps Script）
```
Google Apps Script (GAS)
├── フロントエンド: HTML/CSS/JavaScript
├── バックエンド: Google Apps Script (JavaScript)
├── データベース: Google Sheets
├── 認証: カスタム認証システム
└── デプロイ: Google Apps Script
```

### 3.2. 移行後（Rails）
```
Ruby on Rails 7.0
├── フロントエンド: HTML/CSS/JavaScript (既存維持)
├── バックエンド: Ruby on Rails
├── データベース: PostgreSQL (Heroku)
├── 認証: LINE認証 + カスタム認証
├── デプロイ: Heroku
└── 外部API: Google Sheets API (既存データ連携)
```

## 4. 移行計画

### 4.1. Phase 1: 基盤構築（2時間）
- [ ] Railsアプリケーションの作成
- [ ] 必要なgemの設定
- [ ] 基本的なWebhookエンドポイントの実装
- [ ] Herokuへのデプロイ
- [ ] LINE Webhook URLの設定・検証

### 4.2. Phase 2: 既存機能完全移行（4.5時間）✅ **完了**
- [x] データベース設計・実装
- [x] 認証フローの完全移行
- [x] シフト管理機能の完全移行
- [x] 勤怠・給与管理機能の完全移行

### 4.3. Phase 3: 高度な機能実装（1.5時間）✅ **完了**
- [x] シフト交代機能の実装
- [x] 自動通知機能の実装

### 4.4. Phase 4: 最終調整（1時間）
- [ ] 動作確認・テスト
- [ ] ドキュメント更新

## 5. データベース設計

### 5.1. 主要テーブル
- **employees**: 従業員情報
- **line_users**: LINEユーザー情報
- **shifts**: シフト情報
- **shift_exchanges**: シフト交代管理
- **attendance_records**: 勤怠記録
- **verification_codes**: 認証コード
- **salary_calculations**: 給与計算（103万の壁）

**詳細**: [データベーススキーマ設計書](./database-schema-design.md)

### 5.2. データ移行戦略
1. **既存Google Sheetsデータの分析**
2. **PostgreSQLスキーマの作成**
3. **データ変換スクリプトの作成**
4. **段階的なデータ移行**
5. **データ整合性の検証**

## 6. 機能移行マッピング

### 6.1. 認証機能
```
現在: GAS認証システム
├── パスワードハッシュ化
├── セッション管理
└── 権限チェック

移行後: Rails認証システム
├── LINE認証 + 従業員ID紐付け
├── 認証コード方式
├── セッション管理 (Rails session)
└── 権限チェック (before_action)
```

### 6.2. シフト管理機能
```
現在: Google Sheets直接操作
├── シフト表の読み書き
├── シフト交代管理
└── シフト確認

移行後: Rails + PostgreSQL
├── シフトモデルでの管理
├── シフト交代ワークフロー
├── API経由での確認
└── Google Sheets同期
```

### 6.3. 勤怠管理機能
```
現在: Google Sheets + freee API
├── 勤怠記録の管理
├── freee API連携
└── 給与計算

移行後: Rails + 外部API連携
├── 勤怠記録の管理
├── freee API連携 (既存維持)
├── 給与計算ロジック
└── 103万の壁ゲージ
```

## 7. API設計

### 7.1. Webhookエンドポイント
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # LINE Webhook
  post '/webhook', to: 'webhook#callback'
  
  # 内部API
  namespace :api do
    namespace :v1 do
      resources :employees, only: [] do
        member do
          get :shifts
          get :attendance
          get :salary_info
        end
      end
    end
  end
end
```

### 7.2. 外部API連携
```ruby
# app/services/google_sheets_service.rb
class GoogleSheetsService
  def self.get_shift_data
    # 既存のGoogle Sheets API連携
  end
  
  def self.update_shift_data(data)
    # シフトデータの更新
  end
end

# app/services/freee_api_service.rb
class FreeeApiService
  def self.get_attendance_data
    # 既存のfreee API連携
  end
end
```

## 8. デプロイ構成

### 8.1. Heroku構成
```
Heroku App
├── Web Dyno (1x)
├── Worker Dyno (1x) - Sidekiq
├── PostgreSQL (Mini)
└── Redis (Mini) - ジョブキュー
```

### 8.2. 環境変数
```bash
# Heroku環境変数
LINE_CHANNEL_ACCESS_TOKEN=xxx
LINE_CHANNEL_SECRET=xxx
GOOGLE_SHEETS_API_KEY=xxx
FREEE_ACCESS_TOKEN=xxx
FREEE_COMPANY_ID=xxx
REDIS_URL=xxx
```

## 9. 移行手順

### 9.1. Phase 1: 基盤構築
```bash
# 1. Railsアプリケーション作成
rails new line-webhook-rails --database=postgresql --skip-test
cd line-webhook-rails

# 2. 必要なgemの追加
# Gemfileに以下を追加:
gem 'line-bot-api'
gem 'dotenv-rails'
gem 'httparty'
gem 'mail'
gem 'sidekiq'
gem 'redis'

# 3. gemのインストール
bundle install

# 4. 基本的なWebhook実装
rails generate controller Webhook callback

# 5. Herokuデプロイ
heroku create your-app-name
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini
git add .
git commit -m "Initial Rails app for LINE webhook"
git push heroku main
```

### 9.2. Phase 2: 既存機能移行
```bash
# 1. データベース設計・実装
rails generate model Employee employee_id:string name:string email:string role:string base_pay:integer password_hash:string
rails generate model LineUser line_user_id:string employee_id:string display_name:string is_group:boolean authenticated_at:datetime
rails generate model Shift employee_id:string shift_date:date start_time:time end_time:time is_modified:boolean
rails generate model ShiftExchange request_id:string requester_id:string approver_id:string shift_id:integer status:string
rails generate model AttendanceRecord employee_id:string work_date:date clock_in_time:datetime clock_out_time:datetime break_duration:integer total_work_hours:decimal daily_wage:integer
rails generate model VerificationCode line_user_id:string employee_id:string code:string expires_at:datetime used_at:datetime

# 2. マイグレーション実行
rails db:migrate

# 3. モデル・リレーション実装
# app/models/employee.rb
# app/models/line_user.rb
# app/models/shift.rb
# など

# 4. 認証フロー実装
# app/services/authentication_service.rb
# app/controllers/webhook_controller.rb

# 5. シフト管理機能実装
# app/services/shift_service.rb
# app/services/google_sheets_service.rb
```

### 9.3. Phase 3: 高度な機能実装
```bash
# 1. シフト交代機能実装
# app/services/shift_exchange_service.rb
# app/jobs/shift_notification_job.rb

# 2. 自動通知機能実装
# app/services/attendance_reminder_service.rb
# app/services/salary_alert_service.rb
# app/jobs/attendance_reminder_job.rb
# app/jobs/salary_alert_job.rb

# 3. Sidekiq設定
# config/schedule.rb (whenever gem使用)
```

## 10. テスト・検証

### 10.1. 機能テスト
- [ ] LINE Webhookの動作確認
- [ ] 認証フローの動作確認
- [ ] シフト確認機能の動作確認
- [ ] 勤怠確認機能の動作確認
- [ ] 103万の壁ゲージの動作確認

### 10.2. パフォーマンステスト
- [ ] Webhook応答時間 < 1秒
- [ ] データベースクエリの最適化
- [ ] メモリ使用量の監視

### 10.3. セキュリティテスト
- [ ] 認証・認可の動作確認
- [ ] データの暗号化確認
- [ ] 不正アクセスの防止確認

## 11. 運用・監視

### 11.1. ログ管理
```ruby
# config/environments/production.rb
config.log_level = :info
config.log_formatter = ::Logger::Formatter.new

# アプリケーションログ
Rails.logger.info "Webhook received: #{event.type}"

# エラーログ
Rails.logger.error "Error processing webhook: #{error.message}"
```

### 11.2. 監視項目
- レスポンス時間
- エラー率
- メモリ使用量
- データベース接続数
- Sidekiqジョブの処理状況

### 11.3. アラート設定
```ruby
# app/services/monitoring_service.rb
class MonitoringService
  def self.check_health
    # ヘルスチェック処理
  end
  
  def self.send_alert(message)
    # アラート送信処理
  end
end
```

## 12. リスク管理

### 12.1. 技術的リスク
- **Herokuの制限**: 無料プランの制限事項
- **LINE API制限**: メッセージ送信数の制限
- **データ移行**: 既存データの移行

### 12.2. 対策
- 制限事項の事前確認
- 段階的な移行
- バックアップの確保
- ロールバック計画の準備

## 13. 成功指標

### 13.1. 技術指標
- Webhook応答時間 < 1秒
- エラー率 < 1%
- 稼働率 > 99%

### 13.2. 機能指標
- 認証成功率 > 95%
- メッセージ応答率 > 98%
- 既存機能の完全移行

## 14. 今後の拡張性

### 14.1. 機能拡張
- 勤怠時刻修正機能
- 欠勤登録機能
- 統計・レポート機能
- 多言語対応

### 14.2. 技術拡張
- パーティショニングの導入
- 読み取り専用レプリカの構築
- キャッシュ戦略の実装
- マイクロサービス化

## 15. 参考資料

- [Rails公式ガイド](https://guides.rubyonrails.org/)
- [LINE Bot SDK for Ruby](https://github.com/line/line-bot-sdk-ruby)
- [Heroku公式ドキュメント](https://devcenter.heroku.com/)
- [LINE Messaging API](https://developers.line.biz/ja/docs/messaging-api/)
- [PostgreSQL公式ドキュメント](https://www.postgresql.org/docs/)
- [Sidekiq公式ドキュメント](https://sidekiq.org/)

この移行により、既存のGoogle Apps Scriptベースシステムの制約を解決し、安定したRails + Herokuベースの勤怠管理システムを実現できます。
