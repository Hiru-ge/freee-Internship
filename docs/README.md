# ドキュメント一覧

勤怠管理システムのドキュメント一覧です。

## システム概要
- [README.md](../README.md) - プロジェクト概要とセットアップガイド
- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - Fly.ioデプロイガイド

## 実装・開発関連
- [implementation-status.md](implementation-status.md) - 全体の実装状況レポート
- [implementation-details.md](implementation-details.md) - 実装詳細
- [timezone-fix-documentation.md](timezone-fix-documentation.md) - タイムゾーン修正ドキュメント
- [refactoring-completion-report.md](refactoring-completion-report.md) - リファクタリング完了報告

## システム仕様
- [requirement.md](requirement.md) - 要件定義
- [api-specification.md](api-specification.md) - API仕様書
- [database-schema-design.md](database-schema-design.md) - データベース設計
- [authentication-system.md](authentication-system.md) - 認証システム仕様

## LINE Bot連携
- [line-integration.md](line-integration.md) - LINE Bot連携機能概要
- [line_bot_api_spec.md](line_bot_api_spec.md) - LINE Bot API仕様
- [line_bot_deployment.md](line_bot_deployment.md) - LINE Botデプロイ手順

## テスト関連
- [test-specification.md](test-specification.md) - テスト仕様書

## 最新の更新

### 2025年1月 - タイムゾーン修正完了
- **修正内容**: 打刻機能のタイムゾーン不一致問題を修正
- **実装手法**: TDD（テスト駆動開発）
- **成果**: 4テスト、9アサーション、すべて成功
- **影響**: 打刻機能の時刻記録精度向上、勤怠管理の信頼性向上

### 2025年1月 - シフト交代承認・否認機能修正完了
- **修正内容**: Webアプリ上でのシフト交代リクエスト承認・否認機能の不具合修正
- **実装手法**: TDD（テスト駆動開発）
- **成果**: 5テスト、30アサーション、すべて成功
- **影響**: 外部キー制約エラー、認証エラー、権限チェックエラーの解決

### 2025年9月 - 本番環境デプロイ完了
- **デプロイ先**: Fly.io
- **データベース**: SQLite3
- **成果**: 本番環境での稼働開始

## ドキュメント更新履歴

| 日付 | 更新内容 | 更新者 |
|------|----------|--------|
| 2025年1月 | タイムゾーン修正ドキュメント追加 | AI Assistant |
| 2025年1月 | シフト交代機能修正ドキュメント更新 | AI Assistant |
| 2025年9月 | 本番環境デプロイ関連ドキュメント追加 | AI Assistant |
| 2025年1月 | 包括的ドキュメント整備完了 | AI Assistant |

## 注意事項

- すべてのドキュメントは最新の実装状況を反映しています
- 実装変更時は関連ドキュメントの更新を忘れずに行ってください
- セキュリティ関連の情報は適切に管理してください