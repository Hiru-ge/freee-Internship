# アクセス制限機能仕様書（Phase 14-5）

## 概要

勤怠管理システムに、特定のメールアドレスからのみアクセス可能にする機能を実装します。トップページでメールアドレス認証を行い、認証されたユーザーのみがシステムにアクセスできるようにします。

## 機能要件

### 1. メールアドレス認証システム

#### 1.1 トップページ認証
- **認証フロー**：
  1. ユーザーがトップページにアクセス
  2. メールアドレス入力フォームが表示される
  3. ユーザーがメールアドレスを入力・送信
  4. システムがメールアドレスを検証
  5. 認証成功時：認証コードをメール送信
  6. 認証失敗時：エラーメッセージ表示

#### 1.2 認証コード検証
- **認証コード送信**：
  - 6桁のランダムな数字
  - 有効期限：10分間
  - メール送信：`AuthMailer`を使用
- **認証コード入力**：
  - 認証コード入力フォーム表示
  - 入力されたコードの検証
  - 認証成功時：セッションに認証情報保存

### 2. 許可メールアドレス

#### 2.1 特定メールアドレス
以下の1つのメールアドレスを環境変数で管理：
- `okita2710@gmail.com`

#### 2.2 ドメイン許可
- `@freee.co.jp`で終わるメールアドレスは全て許可

#### 2.3 環境変数設定
```bash
# 許可メールアドレス（カンマ区切り）
ALLOWED_EMAIL_ADDRESSES=okita2710@gmail.com
```

#### 2.4 テスト環境での注意事項
- **テスト時は@freee.co.jpドメインへのメール送信を禁止**
- テスト用のダミーメールアドレスを使用
- メール送信をモック化してテスト実行

### 3. アクセス制御

#### 3.1 保護対象
- 全てのページ（トップページ以外）
- 既存のログイン認証の前に実行
- APIエンドポイントも含む

#### 3.2 認証状態管理
- **セッション情報**：
  - `session[:email_authenticated] = true`
  - `session[:authenticated_email] = email`
  - `session[:email_auth_expires_at] = 24時間後`

#### 3.3 アクセス拒否時の動作
- トップページにリダイレクト
- エラーメッセージ表示
- ログ出力（セキュリティ監査用）

## 技術仕様

### 1. アーキテクチャ

#### 1.1 サービス層
```ruby
class AccessControlService
  # メールアドレス検証
  def self.allowed_email?(email)
  end
  
  # 認証コード生成・送信
  def self.send_verification_code(email)
  end
  
  # 認証コード検証
  def self.verify_code(email, code)
  end
end
```

#### 1.2 コントローラー層
```ruby
class AccessControlController < ApplicationController
  # トップページ（メールアドレス入力）
  def index
  end
  
  # メールアドレス認証
  def authenticate_email
  end
  
  # 認証コード検証
  def verify_code
  end
end
```

#### 1.3 モデル層
```ruby
class EmailVerificationCode < ApplicationRecord
  # 認証コード管理
end
```

### 2. データベース設計

#### 2.1 EmailVerificationCodeテーブル
```ruby
create_table :email_verification_codes do |t|
  t.string :email, null: false
  t.string :code, null: false
  t.datetime :expires_at, null: false
  t.datetime :created_at, null: false
  t.datetime :updated_at, null: false
end

add_index :email_verification_codes, :email
add_index :email_verification_codes, :code
add_index :email_verification_codes, :expires_at
```

### 3. ルーティング

```ruby
Rails.application.routes.draw do
  # アクセス制限関連
  root 'access_control#index'
  post 'access_control/authenticate_email', as: :authenticate_email
  post 'access_control/verify_code', as: :verify_code
  
  # 既存のルーティング
  # ...
end
```

### 4. ミドルウェア統合

#### 4.1 ApplicationController
```ruby
class ApplicationController < ActionController::Base
  before_action :require_email_authentication
  before_action :require_login
  
  private
  
  def require_email_authentication
    # メールアドレス認証チェック
  end
end
```

## 実装ステップ

### Phase 1: 基盤構築
1. **環境変数設定**
   - `.env`ファイルに`ALLOWED_EMAIL_ADDRESSES`追加
   - `config/env.example`更新

2. **データベース設計**
   - `EmailVerificationCode`モデル作成
   - マイグレーション実行

3. **ルーティング設定**
   - アクセス制限関連ルート追加

### Phase 2: サービス層実装（TDD）
1. **AccessControlService**
   - `allowed_email?`メソッド
   - `send_verification_code`メソッド
   - `verify_code`メソッド

2. **テスト実装**
   - 単体テスト
   - 統合テスト

### Phase 3: コントローラー実装
1. **AccessControlController**
   - トップページ表示
   - メールアドレス認証
   - 認証コード検証

2. **ビュー実装**
   - メールアドレス入力フォーム
   - 認証コード入力フォーム
   - エラーメッセージ表示

### Phase 4: 統合・テスト
1. **ApplicationController統合**
   - `require_email_authentication`実装
   - 既存認証との統合

2. **エラーハンドリング**
   - アクセス拒否時の処理
   - ログ出力

3. **テスト実装**
   - 統合テスト
   - エンドツーエンドテスト

## セキュリティ考慮事項

### 1. 認証コード
- **強度**：6桁のランダム数字
- **有効期限**：10分間
- **使用回数**：1回のみ（使用後削除）

### 2. セッション管理
- **有効期限**：24時間
- **セキュリティ**：HTTPS必須
- **ログアウト**：明示的なログアウト処理

### 3. ログ出力
- **アクセス試行**：全てのアクセス試行をログ
- **認証失敗**：メールアドレスとタイムスタンプ
- **セキュリティ監査**：定期的なログ確認

## テスト仕様

### 1. 単体テスト
- `AccessControlService`の各メソッド
- メールアドレス検証ロジック
- 認証コード生成・検証

### 2. 統合テスト
- 認証フロー全体
- エラーハンドリング
- セッション管理

### 3. エンドツーエンドテスト
- ユーザーシナリオ
- アクセス制限の動作確認
- エラーケースの動作確認

## 運用・保守

### 1. 監視
- 認証失敗の監視
- 異常なアクセスパターンの検知
- ログの定期確認

### 2. メンテナンス
- 許可メールアドレスの更新
- 認証コードの有効期限調整
- セキュリティアップデート

## 今後の拡張

### 1. 機能拡張
- 2段階認証の追加
- IPアドレス制限
- 時間帯制限

### 2. 管理機能
- 管理者画面での許可メールアドレス管理
- アクセスログの可視化
- 認証統計の表示

---

