# 勤怠管理システム ドキュメント

LINE Bot連携による勤怠管理システムの包括的なドキュメントです。

## ドキュメント一覧

### ユーザー向けドキュメント
- **[ユーザーガイド](USER_GUIDE.md)** - システムの使い方と操作方法
- **[LINE Bot機能](LINE_BOT.md)** - LINE Bot機能の詳細仕様

### 技術仕様書
- **[認証システム仕様書](AUTHENTICATION_SPEC.md)** - 認証フローとセキュリティ
- **[シフト管理システム仕様書](SHIFT_MANAGEMENT_SPEC.md)** - シフト管理機能の詳細
- **[Flex Message仕様書](FLEX_MESSAGE_SPEC.md)** - LINE Bot UI仕様
- **[会話状態管理仕様書](CONVERSATION_STATE_SPEC.md)** - マルチステップ対話の管理
- **[API統合仕様書](API_INTEGRATION_SPEC.md)** - Freee API連携仕様
- **[セキュリティ仕様書](SECURITY_SPEC.md)** - セキュリティ対策と実装
- **[Webアプリケーション仕様書](WEB_APPLICATION_SPEC.md)** - Webアプリ機能の詳細
- **[データベース仕様書](DATABASE_SPEC.md)** - データベース設計と実装
- **[サービスアーキテクチャ仕様書](SERVICE_ARCHITECTURE_SPEC.md)** - サービス層の設計
- **[API仕様書](API_SPEC.md)** - RESTful API仕様
- **[ビュー仕様書](VIEW_SPEC.md)** - フロントエンド設計と実装

### 品質保証
- **[テスト仕様書](TESTING_SPEC.md)** - テスト戦略と実装
- **[デプロイメント仕様書](DEPLOYMENT_SPEC.md)** - 本番環境への展開

### 管理・運用
- **[API仕様書](API.md)** - REST API仕様
- **[アクセス制御仕様書](ACCESS_CONTROL_SPEC.md)** - 権限管理
- **[要件定義書](REQUIREMENTS.md)** - システム要件
- **[セットアップガイド](SETUP.md)** - 開発環境構築
- **[変更履歴](CHANGELOG.md)** - バージョン履歴

## システム概要

### 主要機能
- **認証システム**: LINEアカウントと従業員アカウントの紐付け
- **シフト確認**: 個人・全員のシフト情報確認
- **シフト交代**: シフト交代依頼・承認機能
- **シフト追加**: 新しいシフトの追加依頼（オーナーのみ）
- **欠勤申請**: シフトの欠勤申請・承認機能
- **依頼確認**: 承認待ち依頼の確認・処理

### 技術スタック
- **バックエンド**: Ruby on Rails 8.0.2
- **データベース**: SQLite
- **外部API**: Freee API, LINE Messaging API
- **デプロイ**: Fly.io
- **テスト**: Minitest

## クイックスタート

### 1. 開発環境の構築
```bash
# リポジトリのクローン
git clone <repository-url>
cd freee-Internship

# 依存関係のインストール
bundle install

# データベースのセットアップ
rails db:create
rails db:migrate
rails db:seed

# テストの実行
rails test
```

### 2. 環境変数の設定
```bash
# LINE Bot設定
export LINE_CHANNEL_ACCESS_TOKEN=your_token
export LINE_CHANNEL_SECRET=your_secret

# Freee API設定
export FREEE_ACCESS_TOKEN=your_token

# その他の設定
export RAILS_ENV=development
```

### 3. アプリケーションの起動
```bash
# サーバーの起動
rails server

# バックグラウンドジョブの起動
rails jobs:work
```

## システム構成

### アーキテクチャ
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LINE Bot      │    │   Rails App     │    │   Freee API     │
│                 │◄──►│                 │◄──►│                 │
│  - メッセージ受信│    │ - ビジネスロジック│    │  - 従業員情報    │
│  - Flex Message │    │  - データ管理    │    │  - シフト情報    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   SQLite        │
                       │                 │
                       │  - 従業員情報    │
                       │  - シフト情報    │
                       │  - 会話状態      │
                       └─────────────────┘
```

### サービス構成
- **LineBotService**: メインコントローラー
- **LineAuthenticationService**: 認証処理
- **LineConversationService**: 会話状態管理
- **LineShiftService**: シフト管理
- **LineShiftExchangeService**: シフト交代
- **LineShiftAdditionService**: シフト追加
- **LineShiftDeletionService**: 欠勤申請
- **LineMessageService**: メッセージ生成
- **LineValidationService**: バリデーション
- **LineNotificationService**: 通知処理

## 開発フロー

### 1. 機能開発
```bash
# ブランチの作成
git checkout -b feature/new-feature

# 開発・テスト
rails test

# コミット
git add .
git commit -m "Add new feature"

# プッシュ
git push origin feature/new-feature
```

### 2. テスト実行
```bash
# 全テストの実行
rails test

# 特定のテストの実行
rails test test/services/line_bot_service_test.rb

# カバレッジの確認
rails test:coverage
```

### 3. デプロイメント
```bash
# ステージング環境へのデプロイ
fly deploy --config fly.staging.toml

# 本番環境へのデプロイ
fly deploy
```

## 品質メトリクス

### テスト結果
- **総テスト数**: 341テスト
- **総アサーション数**: 892アサーション
- **成功率**: 100%
- **カバレッジ**: 90%以上

### パフォーマンス
- **レスポンス時間**: 平均200ms以下
- **スループット**: 100リクエスト/秒
- **エラー率**: 1%以下
- **可用性**: 99.9%以上

## セキュリティ

### 主要なセキュリティ対策
- **LINE Webhook署名検証**: HMAC-SHA256による署名検証
- **認証コード**: 6桁ランダム数字、30分有効期限
- **会話状態管理**: 1時間有効期限、自動削除
- **入力値検証**: XSS、SQLインジェクション対策
- **アクセス制御**: 権限ベースのアクセス制御

## サポート

### 開発者向け
- **技術的な質問**: 開発チームにお問い合わせ
- **バグ報告**: GitHub Issuesで報告
- **機能要望**: GitHub Issuesで提案

### ユーザー向け
- **使い方の質問**: ユーザーガイドを参照
- **トラブルシューティング**: ユーザーガイドのトラブルシューティングセクション
- **サポート**: システム管理者にお問い合わせ

## 更新履歴

### 最新バージョン: 1.0.0
- 認証システム
- シフト管理機能
- シフト交代機能
- シフト追加機能
- 欠勤申請機能
- テスト通過率100%の達成
- ドキュメント整備

### 今後の予定
- 打刻リマインダー機能
- シフト変更通知機能
- パフォーマンス最適化
- セキュリティ強化

## ライセンス

このプロジェクトは社内利用のためのシステムです。

**バージョン**: 1.0.0
**メンテナー**: 開発チーム
