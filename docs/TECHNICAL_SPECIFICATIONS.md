# 技術仕様書

勤怠管理システムの包括的な技術仕様書です。

## 概要

勤怠管理システムは、LINE BotとWebアプリケーションを組み合わせた勤怠管理ツールです。従業員のシフト管理、交代申請、欠勤申請などを効率的に行うことができます。

## プロジェクト概要

### ターゲットユーザー
- 学生が多く働いている居酒屋のオーナー・従業員
- グループLINEがあり、そこでシフト交代などの連携を取っている
- シフト交代成立後は、オーナーが手動でシフト予定を書き換える

### 抱えている課題
1. **打刻忘れ** - 特に急に入ったシフトの場合に打刻忘れが多い
2. **退勤打刻忘れが特に多い** - 仕込みで延長することもあり、退勤時刻が不規則になりがち
3. **突発的なシフト変更** - 事前に決めていたシフトからの変更が多く、LINEを遡って正しい勤務時間を追跡する必要

### 本アプリが生める価値
- **メイン価値**: 突発的なシフト交代に対応できる勤怠管理システム
- **サブ価値**: 103万の壁を可視化することによって、計画的な勤務を促し年末の人手不足を解消
- **新たな価値**: 退勤打刻忘れの防止、オーナーによる直接的な勤怠時刻修正、パスワードのみの簡易認証

## 技術スタック

- **フロントエンド**: HTML/CSS/JavaScript（既存UI維持）
- **バックエンド**: Ruby on Rails 8.0.2
- **データベース**: SQLite3（Fly.io永続ボリューム）
- **認証**: カスタム認証システム + freee API連携 + LINE Bot認証
- **メール送信**: Gmail SMTP
- **デプロイ**: Fly.io
- **外部API**: freee API、LINE Messaging API
- **LINE Bot**: シフト管理機能（認証・交代・追加・削除・表示）
- **状態管理**: ConversationState（LINE Bot対話状態）
- **通知**: EmailNotificationService + ActionMailer

## システムアーキテクチャ

### 全体構成

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LINE Bot      │    │  Web App        │    │  Freee API      │
│                 │    │                 │    │                 │
│  - 認証         │    │  - シフト管理   │    │  - 従業員情報   │
│  - シフト確認   │    │  - 申請管理     │    │  - 打刻データ   │
│  - 申請処理     │    │  - 管理者機能   │    │  - 給与情報     │
│  - 状態管理     │    │  - 勤怠打刻     │    │  - データ同期   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Database      │
                    │                 │
                    │  - SQLite3      │
                    │  - シフトデータ │
                    │  - 申請データ   │
                    │  - 対話状態     │
                    │  - 認証コード   │
                    └─────────────────┘
```

### アーキテクチャ設計（モデル中心設計）

#### 設計原則
- **Fat Model, Skinny Controller**: ビジネスロジックはモデル層に集約
- **サービス層の特化**: 外部API連携のみに限定
- **Rails Way完全準拠**: Convention over Configuration

#### 層構造
```
┌─────────────────────────────────────────────────────────────┐
│                    プレゼンテーション層                      │
│  Web Controllers + LINE Bot Services + Views + JavaScript  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      ビジネスロジック層                      │
│  Models (Fat) + Concerns + Validations + State Management  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      外部連携・通知層                        │
│  Freee API + LINE API + Email Services + Clock Services    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        データ層                             │
│  Database (SQLite3) + ActiveRecord + Conversation States   │
└─────────────────────────────────────────────────────────────┘
```

#### 主要コンポーネント

**モデル層（ビジネスロジック集約）**
- `Employee`: 認証・給与計算・打刻処理・従業員検索
- `Shift`: CRUD・重複チェック・バリデーション・月次シフト取得
- `ShiftExchange`: 交代申請・承認・拒否処理・通知送信
- `ShiftAddition`: 追加申請・承認・拒否処理・通知送信
- `ShiftDeletion`: 削除申請・承認・拒否処理・通知送信
- `ShiftBase` (Concern): 共通バリデーション・通知・ステータス管理
- `ConversationState`: LINE Bot対話状態管理
- `VerificationCode`: 認証コード管理
- `LineMessageLog`: LINE Botメッセージログ

**サービス層（外部API特化）**
- `FreeeApiService`: Freee API連携・キャッシュ・レート制限
- `ClockService`: 打刻API連携・リマインダー送信
- `WageService`: 給与API連携
- `EmailNotificationService`: メール通知・認証コード送信
- `LineBaseService`: LINE Bot基盤サービス（認証・状態管理）
- `LineWebhookService`: LINE Webhook処理・イベント振り分け
- `LineShiftExchangeService`: シフト交代処理・Flex Message生成
- `LineShiftAdditionService`: シフト追加処理
- `LineShiftDeletionService`: シフト削除処理
- `LineShiftDisplayService`: シフト表示処理

**コントローラ層（薄層設計）**
- HTTP処理・レスポンス制御のみ
- 各アクションは3メソッド呼び出し以内で完結
- 認証・認可・エラーハンドリングの統一処理

### LINE Bot サービス構成

#### 1. LineBaseService（基盤サービス）
- **責任**: LINE Bot のメインエントリーポイント、メッセージルーティング
- **主要メソッド**: `handle_message`, `handle_postback_event`
- **認証・権限チェック**: 従業員認証・権限確認
- **状態管理**: ConversationStateによる対話状態管理
- **エラーハンドリング**: 統一されたエラー処理

#### 2. LineWebhookService（Webhook処理）
- **責任**: LINE Webhookイベントの受信・処理
- **主要メソッド**: `process_webhook_events`, `process_single_webhook_event`
- **署名検証**: LINE Bot Webhookの署名検証
- **フォールバック対応**: モック・フォールバッククライアント

#### 3. 機能別LINEサービス
- **LineShiftExchangeService**: シフト交代処理・Flex Message生成
- **LineShiftAdditionService**: シフト追加処理（オーナーのみ）
- **LineShiftDeletionService**: シフト削除処理
- **LineShiftDisplayService**: シフト表示処理・フォーマット

## 画面構成

| 画面名 | 役割 | 状況 |
| --- | --- | --- |
| アクセス認証画面 | メールアドレス認証によるアクセス制限。トップページとして機能。 | 完了 |
| 認証コード入力画面 | メールで送信された6桁の認証コードを入力する。 | 完了 |
| ログイン画面 | 従業員の認証を行う。従業員選択とパスワード入力。 | 完了 |
| ダッシュボード | 打刻機能に特化したシンプルなインターフェース。ログイン直後のデフォルト画面。 | 完了 |
| シフトページ | シフト関連の機能を表示。権限に応じて表示内容が異なる。103万ゲージも表示。 | 完了 |
| 勤怠履歴ページ | 詳細な月別勤怠履歴の確認。 | 完了 |
| シフト交代リクエスト画面 | 従業員がシフト交代のリクエストを作成・送信する。 | 完了 |
| シフト交代承認画面 | 従業員が自分宛のシフト交代リクエストを承認または否認する。 | 完了 |
| シフト追加依頼画面 | オーナーが従業員に新しいシフトの追加を依頼する。 | 完了 |
| パスワード変更画面 | パスワードの変更を行う。 | 完了 |
| 初回パスワード設定画面 | 初回ログイン時のパスワード設定を行う。 | 完了 |

## 画面遷移図

### 認証フロー
```
アクセス認証画面
    ↓ (メールアドレス入力)
認証コード入力画面
    ↓ (認証コード入力)
ログイン画面
    ↓ (従業員選択・パスワード入力)
ダッシュボード
```

### メイン機能フロー
```
ダッシュボード
    ├── シフトページ
    │   ├── シフト交代リクエスト画面
    │   ├── シフト交代承認画面
    │   └── シフト追加依頼画面 (オーナーのみ)
    ├── 勤怠履歴ページ
    └── パスワード変更画面
```

### シフト交代フロー
```
シフトページ
    ↓ (交代依頼ボタン)
シフト交代リクエスト画面
    ↓ (依頼送信)
シフト交代承認画面 (対象従業員)
    ↓ (承認/拒否)
シフトページ (結果表示)
```

### シフト追加フロー (オーナーのみ)
```
シフトページ
    ↓ (追加依頼ボタン)
シフト追加依頼画面
    ↓ (依頼送信)
シフト追加承認画面 (対象従業員)
    ↓ (承認/拒否)
シフトページ (結果表示)
```

## データベース設計

### 主要テーブル構成

#### 従業員テーブル (employees)
```sql
CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) UNIQUE NOT NULL,  -- freeeの従業員ID（主キー）
  password_hash VARCHAR(255),              -- パスワードハッシュ（BCrypt）
  role VARCHAR(20) DEFAULT 'employee',     -- 権限管理（'employee' or 'owner'）
  last_login_at TIMESTAMP,                 -- 最終ログイン日時
  password_updated_at TIMESTAMP,           -- パスワード最終更新日時
  line_id VARCHAR(255),                    -- LINEユーザーID
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### シフトテーブル (shifts)
```sql
CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) NOT NULL,         -- 従業員ID
  shift_date DATE NOT NULL,                -- シフト日付
  start_time TIME NOT NULL,                -- 開始時間
  end_time TIME NOT NULL,                  -- 終了時間
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);
```

#### シフト交代テーブル (shift_exchanges)
```sql
CREATE TABLE shift_exchanges (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(36) UNIQUE NOT NULL,  -- リクエストID（UUID）
  requester_id VARCHAR(7) NOT NULL,        -- 申請者ID
  approver_id VARCHAR(7) NOT NULL,         -- 承認者ID
  shift_id INTEGER NOT NULL,               -- シフトID
  status VARCHAR(20) DEFAULT 'pending',    -- ステータス
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id),
  FOREIGN KEY (approver_id) REFERENCES employees(employee_id),
  FOREIGN KEY (shift_id) REFERENCES shifts(id)
);
```

#### シフト追加テーブル (shift_additions)
```sql
CREATE TABLE shift_additions (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(36) UNIQUE NOT NULL,  -- リクエストID（UUID）
  requester_id VARCHAR(7) NOT NULL,        -- 申請者ID
  target_employee_id VARCHAR(7) NOT NULL,  -- 対象従業員ID
  shift_date DATE NOT NULL,                -- シフト日付
  start_time TIME NOT NULL,                -- 開始時間
  end_time TIME NOT NULL,                  -- 終了時間
  status VARCHAR(20) DEFAULT 'pending',    -- ステータス
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (requester_id) REFERENCES employees(employee_id),
  FOREIGN KEY (target_employee_id) REFERENCES employees(employee_id)
);
```

#### 対話状態テーブル (conversation_states)
```sql
CREATE TABLE conversation_states (
  id SERIAL PRIMARY KEY,
  line_user_id VARCHAR(255) NOT NULL,      -- LINEユーザーID
  state_data TEXT,                         -- 状態データ（JSON）
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 認証コードテーブル (verification_codes)
```sql
CREATE TABLE verification_codes (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) NOT NULL,         -- 従業員ID
  code VARCHAR(6) NOT NULL,                -- 認証コード
  expires_at TIMESTAMP NOT NULL,           -- 有効期限
  used_at TIMESTAMP,                       -- 使用日時
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);
```

#### LINEメッセージログテーブル (line_message_logs)
```sql
CREATE TABLE line_message_logs (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) NOT NULL,         -- 従業員ID
  line_user_id VARCHAR(255) NOT NULL,      -- LINEユーザーID
  message_type VARCHAR(20) NOT NULL,       -- メッセージタイプ
  message_content TEXT,                    -- メッセージ内容
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);
```

## API仕様

### ベースURL
- 開発環境: `http://localhost:3000`
- 本番環境: `https://freee-internship.fly.dev`

### タイムゾーン
- **設定**: Asia/Tokyo (JST +09:00)
- **時刻処理**: すべての時刻処理で`Time.current`を使用
- **打刻機能**: 日本時間で正確な時刻記録

### 認証

#### セッション認証
- ログイン後にセッションCookieで認証状態を維持
- 未認証の場合はログインページにリダイレクト

#### APIキー認証（GitHub Actions用）
- `X-API-Key`ヘッダーによる認証
- 打刻忘れアラート処理専用

### 主要エンドポイント

#### 認証関連
- `POST /auth/login` - ログイン
- `POST /auth/logout` - ログアウト
- `POST /auth/send_verification_code` - 認証コード送信
- `POST /auth/verify_code` - 認証コード検証
- `POST /auth/setup_initial_password` - 初期パスワード設定

#### シフト管理
- `GET /shifts` - シフト一覧表示
- `GET /shifts/data` - シフトデータ取得
- `POST /shift_exchanges` - シフト交代依頼作成
- `POST /shift_additions` - シフト追加依頼作成
- `POST /shift_deletions` - シフト削除依頼作成
- `GET /shift/approvals` - シフト承認一覧
- `POST /shift/approve` - シフト承認
- `POST /shift/reject` - シフト却下

#### 勤怠管理
- `GET /attendance` - 勤怠管理ページ
- `POST /attendance/clock_in` - 出勤打刻
- `POST /attendance/clock_out` - 退勤打刻
- `GET /attendance/clock_status` - 打刻状況取得
- `GET /attendance/attendance_history` - 勤怠履歴取得

#### 給与管理
- `GET /wages` - 給与管理ページ
- `GET /wages/data` - 給与データ取得

#### LINE Bot
- `POST /webhook/callback` - LINE Bot Webhook

#### 打刻忘れアラート
- `POST /clock_reminder/trigger` - アラート実行（APIキー認証必要）

## 権限管理

### オーナー権限の決定について
**重要**: オーナー権限は**シードデータ作成時**に決定され、その後は固定されます。

- 環境変数`OWNER_EMPLOYEE_ID`が設定されている場合：指定された従業員IDがオーナーとして設定されます
- 環境変数`OWNER_EMPLOYEE_ID`が設定されていない場合：すべての従業員が従業員権限として設定されます
- シードデータ作成後は、データベースの`role`カラムで権限が管理されます

### 権限別機能

| 機能 | オーナー | 従業員 | 備考 |
| --- | --- | --- | --- |
| シフトページ | ○ | ○ | 権限に応じて表示内容が異なる |
| 勤怠打刻 | ○ | ○ | 全従業員が利用可能 |
| シフト交代リクエスト | ○ | ○ | 全従業員が利用可能 |
| シフト交代承認 | ○ | ○ | 全従業員が利用可能 |
| シフト追加依頼 | ○ | × | オーナーのみ利用可能 |
| シフト削除依頼 | ○ | ○ | 全従業員が利用可能 |
| パスワード変更 | ○ | ○ | 全従業員が利用可能 |
| 103万の壁ゲージ表示 | ○ | ○ | 全従業員が利用可能 |
| LINE Bot認証 | ○ | ○ | 全従業員が利用可能 |
| LINE Botシフト管理 | ○ | ○ | 権限に応じて機能が異なる |

## 外部サービス連携

### freee API連携
- **従業員情報取得**: 従業員一覧、詳細情報
- **打刻データ送信**: 出勤・退勤時刻の送信
- **給与情報取得**: 103万の壁ゲージ用データ
- **キャッシュ機能**: 5分間のAPI結果キャッシュ
- **レート制限**: 1秒間隔でのAPI呼び出し制限

### LINE Messaging API
- **Webhook受信**: メッセージ・Postbackイベント
- **メッセージ送信**: テキスト・Flex Message
- **認証機能**: 従業員アカウントとの紐付け
- **署名検証**: Webhookの署名検証
- **フォールバック対応**: モック・フォールバッククライアント

### Gmail SMTP
- **認証コード送信**: 6桁のランダム数字
- **通知メール**: シフト依頼・承認結果
- **リマインダー**: 打刻忘れアラート
- **メール認証**: アクセス制限用メール認証

### GitHub Actions
- **定期実行**: 打刻忘れアラート（日本時間の毎時0分、15分、30分、45分）
- **API呼び出し**: HTTP API経由でのアラート実行
- **APIキー認証**: 専用APIキーによる認証

## セキュリティ

### アクセス制限
- **メールアドレス認証**: `@freee.co.jp`ドメイン + 環境変数指定
- **認証コード**: 6桁のランダム数字（10分間有効）
- **セッション管理**: 24時間有効な認証状態
- **LINE Bot認証**: 従業員アカウントとの紐付け

### データ保護
- **パスワードハッシュ**: BCryptによる暗号化
- **SQLインジェクション対策**: パラメータ化クエリ
- **CSRF保護**: Rails標準のCSRFトークン
- **入力値検証**: モデルバリデーションによる検証

### APIセキュリティ
- **署名検証**: LINE Bot Webhookの署名検証
- **APIキー認証**: GitHub Actions用の専用APIキー
- **レート制限**: 適切なレート制限の実装
- **パラメータ改ざん防止**: Strong Parameters + 追加検証
- **権限昇格攻撃対策**: 多層防御による権限チェック

## デプロイメント

### Fly.io設定
- **アプリケーション名**: freee-internship
- **リージョン**: hkg (香港)
- **マシン仕様**: 1 CPU, 256MB RAM
- **自動起動・停止**: 無料枠対応

### 環境変数
- **必須設定**: `FREEE_ACCESS_TOKEN`, `FREEE_COMPANY_ID`, `OWNER_EMPLOYEE_ID`
- **既に設定済み**: Gmail、LINE Bot、アクセス制限等
- **設定方法**: `flyctl secrets set` コマンド

### データベース
- **本番環境**: SQLite3（Fly.io永続ボリューム）
- **開発環境**: SQLite3（ローカルファイル）
- **マイグレーション**: デプロイ時に自動実行

## 監視・ログ

### ログ出力
- **Rails標準ログ**: アプリケーションログ
- **エラーログ**: 例外・エラーの詳細記録
- **アクセスログ**: HTTPリクエストの記録

### 監視項目
- **アプリケーション状態**: Fly.ioダッシュボード
- **GitHub Actions**: 打刻忘れアラートの実行状況
- **LINE Bot**: Webhook受信・送信状況

## パフォーマンス

### 最適化
- **N+1問題解決**: includes/preloadの適切な使用
- **API呼び出し最適化**: キャッシュ・バッチ処理
- **データベース最適化**: インデックス・クエリ最適化

### スケーラビリティ
- **無料枠対応**: Fly.io無料枠での動作
- **自動起動・停止**: コスト最適化
- **効率的なリソース使用**: 最小限のリソースで動作

## テスト

### テスト戦略
- **TDD手法**: Red, Green, Refactoring
- **テストカバレッジ**: 100%のテスト通過率
- **統合テスト**: 機能別のテストファイル構成

### テスト結果
- **総テスト数**: 414テスト
- **成功**: 414テスト
- **失敗**: 0テスト
- **エラー**: 0テスト
- **アサーション数**: 1072アサーション
- **成功率**: 100%

### テストカバレッジ
- **コントローラーテスト**: 全アクションのテスト
- **モデルテスト**: 全モデルのバリデーション・メソッドテスト
- **サービステスト**: 外部API連携・LINE Bot機能テスト
- **統合テスト**: エンドツーエンドの機能テスト
- **エラーハンドリングテスト**: 例外処理・エラーケースのテスト

## 変更履歴

### 最新の主要変更
- **LINE Bot統合**: シフト管理機能の完全実装
- **マルチチャネル対応**: WebとLINE Botの統一されたビジネスロジック
- **状態管理**: ConversationStateによる対話状態管理
- **認証システム**: メール認証 + LINE Bot認証の統合
- **通知システム**: EmailNotificationServiceによる統一通知
- **セキュリティ強化**: 多層防御・権限昇格攻撃対策
- **オーナー権限の決定方式**: シードデータ作成時に固定
- **環境変数ベースの設定**: 柔軟な設定管理
- **ドキュメント整備**: 引き渡し用ドキュメントの充実

詳細な変更履歴は [CHANGELOG.md](CHANGELOG.md) を参照してください。
