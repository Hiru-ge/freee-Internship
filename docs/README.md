# 勤怠管理システム

## 概要

このシステムは、freee人事労務と連携した勤怠管理・シフト管理システムです。LINE BotとWebアプリケーションを組み合わせて、効率的な勤怠管理を実現します。

## セットアップ手順

### 1. 前提条件

- **freee人事労務アカウント**: 従業員・給与データ取得用

**注意**:
- その他の環境変数（Gmail、LINE Bot、Fly.io等）は既に設定済みです
- fly.ioでの動作確認について：fly.io上では、freeeアクセストークン（6時間で失効）を使用しているため、長時間の動作確認は困難です。本格的な動作確認は、独自のfreee APIトークンを取得してから行ってください

### オーナー権限の決定について
**重要**: オーナー権限は**シードデータ作成時**に決定され、その後は固定されます。

- 環境変数`OWNER_EMPLOYEE_ID`が設定されている場合：指定された従業員IDがオーナーとして設定されます
- 環境変数`OWNER_EMPLOYEE_ID`が設定されていない場合：すべての従業員が従業員権限として設定されます
- シードデータ作成後は、データベースの`role`カラムで権限が管理されます

### 2. freee人事労務での準備

1. **従業員登録**
   - 従業員名は自由に設定可能（「店長太郎」「テスト太郎」などの制約なし）
   - 実際のメールアドレスで登録
   - オーナー1名、従業員2-3名を推奨

2. **freee API設定**
   - [freee API管理画面](https://secure.freee.co.jp/oauth/applications)でアプリケーション作成
   - アクセストークンを生成
   - 会社IDを確認

### 3. 環境変数設定

環境変数は以下の方法で設定できます：

#### 開発環境の場合
`.env`ファイルで以下の**3つの環境変数のみ**を設定：

```bash
# freee API設定（必須）
FREEE_ACCESS_TOKEN=取得したアクセストークン
FREEE_COMPANY_ID=取得した会社ID

# オーナー設定（必須）
OWNER_EMPLOYEE_ID=オーナーの従業員ID
```

#### 本番環境（Fly.io）の場合
```bash
# freee API設定（必須）
flyctl secrets set FREEE_ACCESS_TOKEN="取得したアクセストークン"
flyctl secrets set FREEE_COMPANY_ID="取得した会社ID"
flyctl secrets set OWNER_EMPLOYEE_ID="オーナーの従業員ID"
```

**注意**: 環境変数はGitHub以外の方法（直接的な設定）で渡すことを推奨します

### 4. システム起動

```bash
# 依存関係のインストール
bundle install

# データベースのセットアップ
rails db:create
rails db:migrate
rails db:seed

# サーバーの起動
rails server
```

## 主要機能

### Webアプリケーション
- ログイン・認証機能
- シフト管理（確認、追加、編集）
- 勤怠打刻（出勤・退勤）
- 給与管理（103万の壁ゲージ）
- シフト交代・追加依頼

### LINE Bot
- 個人チャットでの認証
- シフト確認
- シフト交代依頼
- 欠勤申請
- 管理者機能（オーナーのみ）

### メール通知
- 認証コード送信
- シフト依頼通知
- 承認・拒否結果通知

## ドキュメント

- [セットアップガイド](SETUP_GUIDE.md)
- [引き渡しチェックリスト](HANDOVER_CHECKLIST.md)
- [API仕様書](API_DOCUMENTATION.md)
- [システム仕様書](SYSTEM_SPECIFICATIONS.md)

## トラブルシューティング

### よくある問題

1. **freee API接続エラー**
   - アクセストークンと会社IDを確認
   - freee API管理画面で新しいトークンを生成

2. **オーナー権限エラー**
   - `OWNER_EMPLOYEE_ID`が正しく設定されているか確認
   - freee人事労務で正しい従業員IDを確認

### デバッグ手順

```bash
# ログの確認
tail -f log/development.log

# 環境変数の確認
rails console
ENV["FREEE_ACCESS_TOKEN"]
ENV["OWNER_EMPLOYEE_ID"]

# データベースの確認
rails console
Employee.all
Employee.where(role: "owner")
```

## セキュリティ

- `.env`ファイルをGitにコミットしない
- 本番環境の認証情報を開発環境で使用しない
- 定期的にパスワードを変更する
- アクセスログを定期的に確認する

## サポート

問題が発生した場合は、トラブルシューティングガイドを参照してください。

---

**注意**: このシステムは完全に汎用的に設計されており、任意のfreee会社で柔軟に運用できます。従業員名やIDの制約はありません。
