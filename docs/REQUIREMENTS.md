# 要件定義

突発的なシフト交代が頻発する小規模飲食店を救う勤怠管理システムの要件定義です。

## 🎯 プロジェクト概要

### ターゲットユーザー
- 学生が多く働いている居酒屋のオーナー・従業員
- グループLINEがあり、そこでシフト交代などの連携を取っている
- シフト交代成立後は、オーナーが手動でシフト予定を書き換える

### 抱えている課題
1. **打刻忘れ** - 特に急に入ったシフトの場合に打刻忘れが多い
2. **退勤打刻忘れが特に多い** - 仕込みで延長することもあり、退勤時刻が不規則になりがち
3. **突発的なシフト変更** - 事前に決めていたシフトからの変更が多く、LINEを遡って正しい勤務時間を追跡する必要
4. **勤怠時刻修正の手間** - オーナーが勤怠時刻を修正するために、管理会社にメールする必要
5. **認証の複雑さ** - パスワード+顔認証の二段階認証が面倒

### 本アプリが生める価値
- **メイン価値**: 突発的なシフト交代に対応できる勤怠管理システム
- **サブ価値**: 103万の壁を可視化することによって、計画的な勤務を促し年末の人手不足を解消
- **新たな価値**: 退勤打刻忘れの防止、オーナーによる直接的な勤怠時刻修正、パスワードのみの簡易認証

## 🏗️ 技術スタック

- **フロントエンド**: HTML/CSS/JavaScript（既存UI維持）
- **バックエンド**: Ruby on Rails 8.0.2
- **データベース**: SQLite3（Fly.io）
- **認証**: カスタム認証システム + freee API連携 ✅
- **メール送信**: Gmail SMTP ✅
- **デプロイ**: Fly.io ✅
- **外部API**: freee API ✅、LINE Messaging API ✅
- **LINE Bot**: シフト管理機能 ✅

## 📱 画面構成

| 画面名 | 役割 | 実装状況 |
| --- | --- | --- |
| ログイン画面 | 従業員の認証を行う。従業員選択とパスワード入力。 | ✅ 完了 |
| ダッシュボード | 打刻機能に特化したシンプルなインターフェース。ログイン直後のデフォルト画面。 | ✅ 完了 |
| シフトページ | シフト関連の機能を表示。権限に応じて表示内容が異なる。103万ゲージも表示。 | ✅ 完了 |
| 勤怠履歴ページ | 詳細な月別勤怠履歴の確認。 | ✅ 完了 |
| シフト交代リクエスト画面 | 従業員がシフト交代のリクエストを作成・送信する。 | ✅ 完了 |
| シフト交代承認画面 | 従業員が自分宛のシフト交代リクエストを承認または否認する。 | ✅ 完了 |
| シフト追加依頼画面 | オーナーが従業員に新しいシフトの追加を依頼する。 | ✅ 完了 |
| パスワード変更画面 | パスワードの変更を行う。 | ✅ 完了 |
| 初回パスワード設定画面 | 初回ログイン時のパスワード設定を行う。 | ✅ 完了 |

## 🔧 機能仕様

### 1. シフト変更機能

従業員間でシフトの交代依頼・承認を行い、スプレッドシート上のシフト表を自動で更新する。

- **リクエストフロー**: シフト管理画面からシフト交代リクエスト画面へ遷移
- **承認フロー**: シフト管理画面の「自分へのリクエスト一覧」または通知メール経由でアクセス
- **ステータス定義**: 承認、否認
- **メール通知**: リクエスト送信時、対象者にメールで通知

### 2. シフト追加機能

オーナーが従業員に新しいシフトの追加を依頼し、従業員が承認・否認を行う機能。

- **権限**: オーナーのみがシフト追加依頼を発行
- **リクエストフロー**: オーナーがシフト追加依頼画面で従業員、日付、時間を選択
- **承認フロー**: 依頼された従業員が承認・否認を行う
- **ステータス定義**: 申請中、承認済み、否認済み
- **メール通知**: リクエスト送信時、依頼された従業員に通知
- **重複チェック**: 依頼された従業員が指定時間に既にシフトが入っている場合はエラー

### 3. 打刻忘れアラート機能

- **仕様**: スプレッドシート上のシフト予定時刻とfreee上での打刻状況を比較し、打刻忘れを検知して通知
- **出勤打刻アラート**: シフト予定開始時刻から15分経過しても出勤打刻がない場合、対象従業員にメールで通知
- **退勤打刻リマインダー**: 退勤予定時刻から15分間隔で退勤打刻が完了していない場合、対象従業員にメールで通知
- **実装状況**: ✅ 完了（2025年9月18日）

### 4. 103万の壁ゲージ機能

- **仕様**: 年間給与の見込み額を算出し、103万円に対する達成度合いをゲージで可視化
- **表示場所**: ダッシュボード（今月の勤怠履歴のみ）、シフトページ（権限に応じて給与ゲージ）
- **計算ロジック**: freee人事労務APIから取得できる`base_pay`を時給として利用
- **実装状況**: ✅ 完了

### 5. 認証簡易化機能

- **仕様**: 二段階認証（パスワード+顔認証）を廃止し、パスワードのみでログイン
- **セキュリティ**: 強固なパスワードポリシー、SHA-256によるハッシュ化
- **利便性**: シンプルで高速なログイン実現
- **実装状況**: ✅ 完了

### 6. 権限管理機能

本アプリケーションでは、以下の2つの権限レベルを設定しています。

- **従業員権限**: 基本的な勤怠管理機能を利用可能
- **オーナー権限**: 従業員権限に加え、管理機能を利用可能

#### 権限別利用可能機能

| 機能 | 従業員 | オーナー | 備考 |
|------|--------|----------|------|
| ダッシュボード | ○ | ○ | 打刻機能と今月の勤怠履歴 |
| シフトページ | ○ | ○ | 権限に応じて表示内容が異なる |
| 勤怠打刻 | ○ | ○ | 全従業員が利用可能 |
| シフト交代リクエスト | ○ | ○ | 全従業員が利用可能 |
| シフト交代承認 | ○ | ○ | 全従業員が利用可能 |
| シフト追加依頼 | × | ○ | オーナーのみ利用可能 |
| パスワード変更 | ○ | ○ | 全従業員が利用可能 |
| 103万の壁ゲージ表示 | ○ | ○ | 全従業員が利用可能 |

#### 権限判定方法

- **オーナー判定**: 従業員名が「店長 太郎」の場合
- **従業員判定**: オーナー以外の全従業員

## 🗄️ データ構造

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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### シフトテーブル (shifts)
```sql
CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  shift_date DATE NOT NULL,                  -- シフト日付
  start_time TIME NOT NULL,                  -- 開始時間
  end_time TIME NOT NULL,                    -- 終了時間
  is_modified BOOLEAN DEFAULT FALSE,         -- シフト変更フラグ
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### シフト交代管理テーブル (shift_exchanges)
```sql
CREATE TABLE shift_exchanges (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(36) UNIQUE NOT NULL,    -- UUID
  requester_id VARCHAR(7) REFERENCES employees(employee_id),
  approver_id VARCHAR(7) REFERENCES employees(employee_id),
  shift_id INTEGER REFERENCES shifts(id),
  status VARCHAR(20) DEFAULT 'pending',      -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 勤怠記録テーブル (attendance_records)
```sql
CREATE TABLE attendance_records (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  work_date DATE NOT NULL,                   -- 勤務日
  clock_in_time TIMESTAMP,                   -- 出勤時刻
  clock_out_time TIMESTAMP,                  -- 退勤時刻
  break_duration INTEGER DEFAULT 0,          -- 休憩時間（分）
  total_work_hours DECIMAL(4,2),             -- 総労働時間
  daily_wage INTEGER,                         -- 日給
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### LINEユーザーテーブル (line_users)
```sql
CREATE TABLE line_users (
  id SERIAL PRIMARY KEY,
  line_user_id VARCHAR(100) UNIQUE NOT NULL,  -- LINEユーザーID
  employee_id VARCHAR(7) REFERENCES employees(employee_id),
  display_name VARCHAR(100),                  -- LINE表示名
  is_group BOOLEAN DEFAULT FALSE,             -- グループLINEかどうか
  authenticated_at TIMESTAMP,                 -- 認証完了日時
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 📊 実装状況

### 完了済みフェーズ

#### Phase 2-1: 認証システム移行 ✅ **完了**
- [x] ログイン機能の実装
- [x] ログアウト機能の実装
- [x] パスワード変更機能の実装
- [x] 認証コード機能の実装

#### Phase 2-2: ダッシュボード機能移行 ✅ **完了**
- [x] ダッシュボードの実装
- [x] 打刻機能の実装
- [x] 勤怠履歴表示
- [x] 月次ナビゲーション

#### Phase 2-3: シフト管理機能移行 ✅ **完了**
- [x] シフトページの実装
- [x] シフト表示・確認機能
- [x] 月次ナビゲーション

#### Phase 2-4: シフト交代機能移行 ✅ **完了**
- [x] シフト交代リクエスト機能
- [x] シフト交代承認機能
- [x] シフト追加依頼機能

#### Phase 2-5: 給与管理機能移行 ✅ **完了**
- [x] 103万の壁ゲージ機能
- [x] 給与計算機能

#### Phase 10: LINE Bot責務分離 ✅ **完了**
- [x] `LineBotService`（2,303行）を9つの専門サービスクラスに分割
- [x] 単一責任原則に基づいた設計の実現
- [x] 234テスト、720アサーション、100%成功

#### Phase 13: WebとLINEバックエンド処理統合 ✅ **完了**
- [x] 共通サービスの作成
- [x] 重複コードの削除と共通化
- [x] 418テスト、1196アサーション、100%成功

### 技術的成果

#### セキュリティ
- bcryptによるパスワードハッシュ化
- 認証コードの有効期限管理（10分間）
- セッション管理の適切な実装
- 機密情報の環境変数分離

#### パフォーマンス
- freee APIのページネーション対応
- 従業員情報の動的取得
- 適切なキャッシュ戦略

#### ユーザビリティ
- GAS時代と完全に同じUI/UX
- 3段階パスワードリセット機能
- 直感的な認証フロー

## 🔮 今後の展望

### 勤怠時刻修正機能
オーナーが従業員の勤怠時刻を直接修正できる機能
- 修正可能項目：出勤時刻、退勤時刻、休憩時間
- 修正履歴の記録
- freee連携での自動更新

### 欠勤の登録
病欠などで急遽休むこともあるはずなので、「欠勤登録(シフト取り消し)」ができたらいいかもしれない

## 📞 サポート

問題が発生した場合は、[CHANGELOG.md](CHANGELOG.md) で最新の変更内容を確認するか、開発チームにお問い合わせください。
