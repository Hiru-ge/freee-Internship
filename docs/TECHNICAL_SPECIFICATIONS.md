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
- **データベース**: SQLite3（Fly.io）
- **認証**: カスタム認証システム + freee API連携
- **メール送信**: Gmail SMTP
- **デプロイ**: Fly.io
- **外部API**: freee API、LINE Messaging API
- **LINE Bot**: シフト管理機能

## システムアーキテクチャ

### 全体構成

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LINE Bot      │    │  Web App        │    │  Freee API      │
│                 │    │                 │    │                 │
│  - 認証         │    │  - シフト管理   │    │  - 従業員情報   │
│  - シフト確認   │    │  - 申請管理     │    │  - データ同期   │
│  - 申請処理     │    │  - 管理者機能   │    │                 │
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
                    └─────────────────┘
```

### サービス構成

#### 1. LineBotService（メインコントローラー）
- **責任**: LINE Bot のメインエントリーポイント、メッセージルーティング
- **主要メソッド**: `handle_message`, `handle_postback_event`, `handle_request_check_command`

#### 2. LineAuthenticationService（認証サービス）
- **責任**: LINE アカウントと従業員アカウントの紐付け認証
- **主要メソッド**: `handle_auth_command`, `handle_employee_name_input`, `handle_verification_code_input`

#### 3. LineConversationService（会話状態管理サービス）
- **責任**: マルチステップの対話処理における会話状態の管理
- **管理する状態**: 従業員名入力待ち、認証コード入力待ち、シフト日付入力待ちなど

#### 4. LineShiftService（シフト管理サービス）
- **責任**: シフト情報の取得と表示
- **主要メソッド**: `handle_shift_command`, `handle_all_shifts_command`

#### 5. LineShiftExchangeService（シフト交代サービス）
- **責任**: シフト交代リクエストの作成、承認、拒否処理
- **主要メソッド**: `handle_shift_exchange_command`, `handle_approval_postback`

#### 6. LineShiftAdditionService（シフト追加サービス）
- **責任**: シフト追加リクエストの作成、承認、拒否処理

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
  password_hash VARCHAR(255) NOT NULL,     -- パスワードハッシュ（唯一のローカル情報）
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

#### シフト管理
- `GET /shifts` - シフト一覧表示
- `GET /shifts/data` - シフトデータ取得
- `POST /shift_exchanges` - シフト交代依頼作成
- `POST /shift_additions` - シフト追加依頼作成

#### 勤怠管理
- `POST /dashboard/clock_in` - 出勤打刻
- `POST /dashboard/clock_out` - 退勤打刻
- `GET /dashboard/clock_status` - 打刻状況取得

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
| シフト追加依頼 | × | ○ | オーナーのみ利用可能 |
| パスワード変更 | ○ | ○ | 全従業員が利用可能 |
| 103万の壁ゲージ表示 | ○ | ○ | 全従業員が利用可能 |

## 外部サービス連携

### freee API連携
- **従業員情報取得**: 従業員一覧、詳細情報
- **打刻データ送信**: 出勤・退勤時刻の送信
- **給与情報取得**: 103万の壁ゲージ用データ

### LINE Messaging API
- **Webhook受信**: メッセージ・Postbackイベント
- **メッセージ送信**: テキスト・Flex Message
- **認証機能**: 従業員アカウントとの紐付け

### Gmail SMTP
- **認証コード送信**: 6桁のランダム数字
- **通知メール**: シフト依頼・承認結果
- **リマインダー**: 打刻忘れアラート

### GitHub Actions
- **定期実行**: 打刻忘れアラート（日本時間の毎時0分、15分、30分、45分）
- **API呼び出し**: HTTP API経由でのアラート実行

## セキュリティ

### アクセス制限
- **メールアドレス認証**: `@freee.co.jp`ドメイン + 環境変数指定
- **認証コード**: 6桁のランダム数字（10分間有効）
- **セッション管理**: 24時間有効な認証状態

### データ保護
- **パスワードハッシュ**: BCryptによる暗号化
- **SQLインジェクション対策**: パラメータ化クエリ
- **CSRF保護**: Rails標準のCSRFトークン

### APIセキュリティ
- **署名検証**: LINE Bot Webhookの署名検証
- **APIキー認証**: GitHub Actions用の専用APIキー
- **レート制限**: 適切なレート制限の実装

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

## 変更履歴

### 最新の主要変更
- **オーナー権限の決定方式**: シードデータ作成時に固定
- **環境変数ベースの設定**: 柔軟な設定管理
- **ドキュメント整備**: 引き渡し用ドキュメントの充実

詳細な変更履歴は [CHANGELOG.md](CHANGELOG.md) を参照してください。
