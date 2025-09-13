# エラーハンドリング統一・改善 実装ドキュメント

## 概要

フェーズ7-1として、勤怠管理システムのエラーハンドリングを統一・改善しました。t-wadaのTDD手法に従って実装し、ユーザーフレンドリーなエラーメッセージの提供と一貫したエラー処理を実現しました。

## 実装期間

- **開始日**: 2025年1月
- **完了日**: 2025年1月
- **実装時間**: 3時間（見積時間通り）
- **実装手法**: t-wadaのTDD（テスト駆動開発）

## 実装内容

### 1. ErrorHandlerモジュールの作成

#### ファイル: `app/controllers/concerns/error_handler.rb`

統一されたエラーハンドリングを提供するモジュールを新規作成しました。

**主要機能:**
- 統一されたエラーメッセージの定数定義
- バリデーション、API、認証、一般エラーのハンドリング
- 機密情報のサニタイズ機能
- 統一されたログ記録機能

**エラーメッセージタイプ:**
```ruby
ERROR_MESSAGES = {
  validation: {
    required: '必須項目を入力してください',
    format: '入力形式が正しくありません',
    length: '文字数が制限を超えています',
    invalid: '無効な値が入力されています'
  },
  authorization: {
    login_required: 'ログインが必要です',
    permission_denied: 'このページにアクセスする権限がありません',
    session_expired: 'セッションがタイムアウトしました。再度ログインしてください。',
    invalid_session: 'セッションが無効です'
  },
  api: {
    connection_failed: 'システムエラーが発生しました。しばらく時間をおいてから再度お試しください。',
    timeout: 'システムが混雑しています。しばらく時間をおいてから再度お試しください。',
    server_error: 'サーバーエラーが発生しました。システム管理者にお問い合わせください。'
  },
  general: {
    unknown: '予期しないエラーが発生しました。システム管理者にお問い合わせください。',
    maintenance: 'システムメンテナンス中です。しばらく時間をおいてから再度アクセスしてください。'
  }
}
```

**主要メソッド:**
- `handle_validation_error(field_name, message, redirect_path = nil)`
- `handle_api_error(error, context = '', redirect_path = nil)`
- `handle_authorization_error(message, redirect_path = nil)`
- `handle_unknown_error(redirect_path = nil)`
- `handle_success(message)`
- `handle_warning(message)`
- `handle_info(message)`

### 2. ApplicationControllerの改善

#### ファイル: `app/controllers/application_controller.rb`

**変更内容:**
- ErrorHandlerモジュールのinclude追加
- 既存のhandle_api_errorメソッドをErrorHandlerの統一処理に変更

**変更前:**
```ruby
def handle_api_error(error, context = '')
  error_message = "#{context}エラー: #{error.message}"
  Rails.logger.error error_message
  Rails.logger.error "Error class: #{error.class}"
  Rails.logger.error "Error backtrace: #{error.backtrace.join('\n')}" if error.backtrace
  error_message
end
```

**変更後:**
```ruby
include ErrorHandler

def handle_api_error(error, context = '')
  super(error, context)
end
```

### 3. AuthControllerのエラーハンドリング改善

#### ファイル: `app/controllers/auth_controller.rb`

**変更内容:**
- ErrorHandlerモジュールのinclude追加
- フラッシュメッセージの統一（`flash[:alert]` → `flash[:error]`）
- 統一されたエラーハンドリングメソッドの使用

**主な改善点:**
- SQLインジェクション対策での統一されたエラーメッセージ
- ログイン成功時の統一された成功メッセージ
- パスワード設定が必要な場合の統一された警告メッセージ

### 4. InputValidationモジュールの改善

#### ファイル: `app/controllers/concerns/input_validation.rb`

**変更内容:**
- 空の値のバリデーション処理を改善
- フラッシュメッセージの統一（`flash[:alert]` → `flash[:error]`）

**主な改善点:**
- `validate_password_length`: 空のパスワードの場合に適切なエラーメッセージを表示
- `validate_employee_id_format`: 空の従業員IDの場合に適切なエラーメッセージを表示

**変更前:**
```ruby
def validate_password_length(password, redirect_path)
  return true if password.blank?  # 空の値はスキップ
  # ...
end
```

**変更後:**
```ruby
def validate_password_length(password, redirect_path)
  if password.blank?
    flash[:error] = 'パスワードを入力してください'
    redirect_to redirect_path
    return false
  end
  # ...
end
```

### 5. レイアウトファイルの改善

#### ファイル: `app/views/layouts/application.html.erb`

**変更内容:**
- 統一されたフラッシュメッセージタイプの対応
- 後方互換性の維持

**対応メッセージタイプ:**
- `flash[:success]` - 成功メッセージ
- `flash[:error]` - エラーメッセージ
- `flash[:warning]` - 警告メッセージ
- `flash[:info]` - 情報メッセージ
- `flash[:notice]` - 後方互換性のため残存
- `flash[:alert]` - 後方互換性のため残存

### 6. ShiftExchangesControllerの改善

#### ファイル: `app/controllers/shift_exchanges_controller.rb`

**変更内容:**
- ErrorHandlerモジュールのinclude追加
- 統一されたエラーハンドリングの使用

## テスト実装

### 1. ErrorHandlerモジュールのテスト

#### ファイル: `test/controllers/concerns/error_handler_test.rb`

**テスト内容:**
- バリデーションエラーのハンドリング
- APIエラーのハンドリング
- 認証エラーのハンドリング
- 成功・警告・情報メッセージのハンドリング
- フォールバックエラーメッセージの提供

**テスト結果:** 7テスト全て通過

### 2. 統合テスト

#### ファイル: `test/controllers/error_handling_simple_test.rb`

**テスト内容:**
- 空の従業員IDでのエラーハンドリング
- 空のパスワードでのエラーハンドリング
- SQLインジェクション攻撃の試行に対する適切な処理
- XSS攻撃の試行に対する適切な処理
- セキュリティヘッダーの維持

**テスト結果:** 5テスト全て通過

### 3. 既存テストの修正

#### ファイル: `test/controllers/input_validation_test.rb`

**修正内容:**
- `flash[:alert]` → `flash[:error]` への統一

## セキュリティ向上

### 1. 機密情報の露出防止

**実装内容:**
- エラーメッセージのサニタイズ機能
- パスワード、トークン、キーなどの機密情報の除去
- ファイルパスの詳細情報の除去

**サニタイズ対象:**
```ruby
def sanitize_error_message(message)
  # パスワード関連の情報を除去
  sanitized.gsub!(/password[=:]\s*\S+/i, 'password=***')
  sanitized.gsub!(/token[=:]\s*\S+/i, 'token=***')
  sanitized.gsub!(/key[=:]\s*\S+/i, 'key=***')
  sanitized.gsub!(/secret[=:]\s*\S+/i, 'secret=***')
  
  # ファイルパスの詳細を除去
  sanitized.gsub!(/\/[^\s]*\//, '/***/')
end
```

### 2. セキュリティヘッダーの維持

エラー発生時でも以下のセキュリティヘッダーが適切に設定されることを確認:
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`

## ユーザビリティ向上

### 1. 統一されたエラーメッセージ

**改善前の問題:**
- 画面によって異なるエラーメッセージ
- 技術的な詳細の露出
- ユーザーが対処できない情報の表示

**改善後の効果:**
- 全画面で一貫したエラーメッセージ
- ユーザーフレンドリーな表現
- 対処方法が明確なメッセージ

### 2. 適切なフォールバック処理

**実装内容:**
- エラー発生時の適切なリダイレクト
- ユーザーへの適切な通知
- システムの安定性維持

## パフォーマンス向上

### 1. ログ記録の最適化

**改善内容:**
- 統一されたログ記録機能
- 適切なログレベルの設定
- 機密情報の除去によるログの安全性向上

### 2. エラー処理の効率化

**改善内容:**
- 重複するエラーハンドリングコードの削減
- 統一された処理による保守性向上
- DRY原則の適用

## テスト結果

### 全体テスト結果
```
Running 154 tests in parallel using 16 processes
154 runs, 328 assertions, 0 failures, 0 errors, 0 skips
```

### 個別テスト結果
- **ErrorHandlerモジュールテスト**: 7テスト全て通過
- **統合テスト**: 5テスト全て通過
- **既存テスト**: 修正後全て通過

## 今後の拡張性

### 1. 新しいエラータイプの追加

ErrorHandlerモジュールは拡張可能な設計となっており、新しいエラータイプを簡単に追加できます。

### 2. 多言語対応

エラーメッセージの定数化により、将来的な多言語対応が容易になります。

### 3. カスタマイズ可能なエラーハンドリング

各コントローラーでErrorHandlerのメソッドをオーバーライドすることで、カスタマイズされたエラーハンドリングが可能です。

## まとめ

フェーズ7-1の実装により、以下の成果を達成しました:

1. **統一されたエラーハンドリング**: 全システムで一貫したエラー処理
2. **ユーザビリティの向上**: 分かりやすく対処可能なエラーメッセージ
3. **セキュリティの強化**: 機密情報の露出防止とセキュリティヘッダーの維持
4. **保守性の向上**: DRY原則の適用と統一されたコード構造
5. **テストカバレッジの確保**: TDD手法による高品質な実装

この実装により、ユーザーエクスペリエンスが大幅に改善され、開発者にとっても保守しやすいシステムになりました。
