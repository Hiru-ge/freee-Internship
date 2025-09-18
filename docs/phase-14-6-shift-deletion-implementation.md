# Phase 14-6: 欠勤申請機能実装ドキュメント

## 概要
Phase 14-6では、欠勤申請（シフト削除）機能をt-wadaのTDD（Red, Green, Refactoring）アプローチで実装しました。従業員が自分のシフトを欠勤申請し、オーナーが承認・否認できる機能を提供します。

## 実装アプローチ
- **TDD**: Red, Green, Refactoringのサイクルで実装
- **既存パターン準拠**: シフト交代・追加機能と同様の構造
- **UI/UX統一**: 他のフォームと一貫したデザイン
- **通知システム統合**: 既存のメール通知システムを活用

## 実装内容

### 1. データベース設計
- **ShiftDeletionモデル**: 欠勤申請のデータ構造
- **マイグレーション**: `20250918153359_create_shift_deletions.rb`
- **フィールド**:
  - `request_id`: 一意のリクエストID
  - `requester_id`: 申請者の従業員ID
  - `shift_id`: 対象シフトのID
  - `reason`: 欠勤理由
  - `status`: 申請状態（pending/approved/rejected）
  - `responded_at`: 応答日時

### 2. モデル実装
- **ShiftDeletion**: バリデーション、スコープ、メソッド
- **Shift**: `display_name`メソッド追加
- **バリデーション**:
  - 必須項目チェック
  - ステータス値の妥当性
  - リクエストIDの一意性

### 3. コントローラー実装
- **ShiftDeletionsController**: 申請フォームと作成処理
- **ShiftApprovalsController**: 承認・否認処理の拡張
- **AuthorizationCheck**: 権限チェック機能の拡張

### 4. サービス層実装
- **ShiftDeletionService**: ビジネスロジックの集約
  - `create_deletion_request`: 申請作成
  - `approve_deletion_request`: 申請承認
  - `reject_deletion_request`: 申請拒否
- **UnifiedNotificationService**: 通知機能の統合

### 5. ビュー実装
- **申請フォーム**: シフト選択式、未来のシフトのみ表示
- **承認画面**: 既存の承認画面に欠勤申請を統合
- **UI/UX改善**:
  - テキストエリアの拡大
  - セレクトボックスの幅調整
  - 統一されたフォームデザイン

### 6. 通知機能
- **メール通知**: 申請、承認、拒否の3種類
- **テンプレート統一**: 既存のメールデザインパターンに準拠
- **LINE通知**: 無効化（要求に応じて）

### 7. テスト実装
- **モデルテスト**: バリデーション、スコープ、メソッド
- **コントローラーテスト**: 申請、承認、拒否の動作確認
- **統合テスト**: エンドツーエンドの動作確認

## 技術仕様

### データベーススキーマ
```sql
CREATE TABLE shift_deletions (
  id BIGINT PRIMARY KEY,
  request_id VARCHAR NOT NULL UNIQUE,
  requester_id VARCHAR NOT NULL,
  shift_id BIGINT NOT NULL REFERENCES shifts(id),
  reason TEXT NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'pending',
  responded_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### API エンドポイント
- `GET /shift_deletions/new`: 申請フォーム表示
- `POST /shift_deletions`: 申請作成
- `POST /shift_approvals/approve`: 申請承認
- `POST /shift_approvals/reject`: 申請拒否

### 権限管理
- **申請**: 自分のシフトのみ申請可能
- **承認**: オーナーのみ承認・拒否可能
- **過去のシフト**: 申請不可（バリデーション）

## 実装ファイル一覧

### 新規作成ファイル
- `app/models/shift_deletion.rb`
- `app/controllers/shift_deletions_controller.rb`
- `app/views/shift_deletions/new.html.erb`
- `app/services/shift_deletion_service.rb`
- `app/views/shift_mailer/shift_deletion_request.html.erb`
- `app/views/shift_mailer/shift_deletion_approved.html.erb`
- `app/views/shift_mailer/shift_deletion_denied.html.erb`
- `db/migrate/20250918153359_create_shift_deletions.rb`
- `test/models/shift_deletion_test.rb`
- `test/controllers/shift_deletions_controller_test.rb`
- `test/controllers/shift_approvals_controller_test.rb`

### 修正ファイル
- `config/routes.rb`: ルート追加
- `app/controllers/shift_approvals_controller.rb`: 承認処理拡張
- `app/controllers/concerns/authorization_check.rb`: 権限チェック拡張
- `app/services/unified_notification_service.rb`: 通知機能拡張
- `app/services/email_notification_service.rb`: メール通知拡張
- `app/mailers/shift_mailer.rb`: メーラーメソッド追加
- `app/models/shift.rb`: display_nameメソッド追加
- `app/views/shifts/index.html.erb`: 申請ボタン追加
- `app/views/shift_approvals/index.html.erb`: 申請表示追加
- `app/assets/stylesheets/application.css`: スタイル調整

## テスト結果
- **総テスト数**: 27テスト
- **アサーション数**: 72アサーション
- **成功率**: 100%（0失敗、0エラー）

## 機能仕様

### 申請フロー
1. 従業員がシフトページから「欠勤申請」ボタンをクリック
2. 申請フォームで対象シフトと理由を入力
3. 申請送信後、オーナーにメール通知
4. オーナーが承認画面で申請を確認・処理
5. 申請者に結果をメール通知

### 制約事項
- 未来のシフトのみ申請可能
- 自分のシフトのみ申請可能
- 重複申請は不可
- オーナーのみ承認・拒否可能

### 通知内容
- **申請通知**: オーナーに申請内容を通知
- **承認通知**: 申請者に承認結果を通知
- **拒否通知**: 申請者に拒否結果を通知

## 今後の改善点
- 申請理由のテンプレート化
- 申請履歴の表示機能
- 一括承認機能
- 申請期限の設定

## 関連ドキュメント
- [todo.md](../todo.md): タスク管理
- [README.md](../README.md): プロジェクト概要
- [Phase 14-6実装記録](../docs/phase-14-6-implementation-log.md): 詳細な実装ログ
