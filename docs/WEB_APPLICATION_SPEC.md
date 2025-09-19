# Webアプリケーション仕様書

勤怠管理システムのWebアプリケーション機能の詳細仕様です。

## 🎯 概要

従業員がWebブラウザからアクセスして利用する勤怠管理システムの機能仕様です。

## 🏗️ アーキテクチャ

### 技術スタック
- **フロントエンド**: HTML/CSS/JavaScript
- **バックエンド**: Ruby on Rails 8.0.2
- **データベース**: PostgreSQL
- **認証**: カスタム認証システム
- **外部API**: Freee API連携
- **デプロイ**: Fly.io

### ディレクトリ構造
```
app/
├── controllers/          # コントローラー
├── models/              # データモデル
├── views/               # ビューテンプレート
├── services/            # ビジネスロジック
├── helpers/             # ヘルパーメソッド
├── assets/              # 静的ファイル
└── jobs/                # バックグラウンドジョブ
```

## 🔐 認証システム

### 認証フロー
```
1. アクセス認証画面
2. メールアドレス入力
3. 認証コード生成・送信
4. 認証コード入力
5. ダッシュボード表示
```

### 認証コントローラー
```ruby
class AuthController < ApplicationController
  def index
    # アクセス認証画面の表示
  end

  def verify_email
    # メールアドレス認証
  end

  def verify_code
    # 認証コード検証
  end

  def logout
    # ログアウト処理
  end
end
```

### 認証サービス
```ruby
class AuthService
  def send_verification_code(email)
    # 認証コード生成・送信
  end

  def verify_verification_code(email, code)
    # 認証コード検証
  end

  def find_employee_by_email(email)
    # 従業員検索
  end
end
```

## 📊 ダッシュボード

### ダッシュボード機能
- **打刻機能**: 出勤・退勤打刻
- **勤怠状況**: 当日の勤怠状況表示
- **勤怠履歴**: 月別勤怠履歴の表示
- **給与情報**: 103万の壁ゲージ表示

### ダッシュボードコントローラー
```ruby
class DashboardController < ApplicationController
  def index
    @employee = current_employee
    @clock_service = ClockService.new(current_employee_id)
    @clock_status = @clock_service.get_clock_status
  end

  def clock_in
    # 出勤打刻
  end

  def clock_out
    # 退勤打刻
  end

  def clock_status
    # 打刻状態取得
  end

  def attendance_history
    # 勤怠履歴取得
  end
end
```

### 打刻機能
```ruby
class ClockService
  def clock_in
    # 出勤打刻処理
  end

  def clock_out
    # 退勤打刻処理
  end

  def get_clock_status
    # 打刻状態の取得
  end

  def get_attendance_for_month(year, month)
    # 月次勤怠データの取得
  end
end
```

## 📅 シフト管理

### シフト管理機能
- **シフト確認**: 月間シフト表の表示
- **シフト交代依頼**: 他の従業員への交代依頼
- **シフト追加依頼**: 新しいシフトの追加申請
- **欠勤申請**: 自分のシフトの欠勤申請
- **シフト承認**: 管理者によるシフト依頼の承認/否認

### シフトコントローラー
```ruby
class ShiftsController < ApplicationController
  def index
    # シフト一覧表示
  end

  def show
    # 個別シフト表示
  end

  def new
    # 新規シフト作成
  end

  def create
    # シフト作成処理
  end

  def edit
    # シフト編集
  end

  def update
    # シフト更新処理
  end

  def destroy
    # シフト削除処理
  end
end
```

### シフト交代機能
```ruby
class ShiftExchangesController < ApplicationController
  def index
    # 交代依頼一覧
  end

  def create
    # 交代依頼作成
  end

  def approve
    # 交代依頼承認
  end

  def reject
    # 交代依頼拒否
  end
end
```

### シフト追加機能
```ruby
class ShiftAdditionsController < ApplicationController
  def index
    # 追加依頼一覧
  end

  def create
    # 追加依頼作成
  end

  def approve
    # 追加依頼承認
  end

  def reject
    # 追加依頼拒否
  end
end
```

### 欠勤申請機能
```ruby
class ShiftDeletionsController < ApplicationController
  def index
    # 欠勤申請一覧
  end

  def create
    # 欠勤申請作成
  end

  def approve
    # 欠勤申請承認
  end

  def reject
    # 欠勤申請拒否
  end
end
```

## 💰 給与管理

### 給与管理機能
- **103万の壁ゲージ**: 年収103万円の壁を視覚的に表示
- **時間帯別時給計算**: 深夜・早朝・休日等の時給計算
- **給与データ表示**: Freee APIから取得した給与情報の表示

### 給与コントローラー
```ruby
class WagesController < ApplicationController
  def index
    # 給与情報表示
  end

  def show
    # 個別給与詳細
  end

  def monthly
    # 月次給与情報
  end
end
```

### 給与サービス
```ruby
class WageService
  def calculate_monthly_wage(employee_id, month, year)
    # 月次給与計算
  end

  def get_employee_wage_info(employee_id, month, year)
    # 従業員給与情報取得
  end

  def get_all_employees_wages(month, year)
    # 全従業員給与情報取得
  end
end
```

## 🔧 アクセス制御

### アクセス制御機能
- **メールアドレス認証**: 登録済みメールアドレスのみアクセス可能
- **認証コード認証**: 6桁の認証コードによる二段階認証
- **セッション管理**: セッションによる認証状態管理

### アクセス制御コントローラー
```ruby
class AccessControlController < ApplicationController
  def index
    # アクセス制御画面
  end

  def verify_email
    # メールアドレス認証
  end

  def verify_code
    # 認証コード認証
  end
end
```

### アクセス制御サービス
```ruby
class AccessControlService
  def send_verification_code(email)
    # 認証コード送信
  end

  def verify_verification_code(email, code)
    # 認証コード検証
  end

  def find_employee_by_email(email)
    # 従業員検索
  end
end
```

## 📧 通知システム

### 通知機能
- **メール通知**: 認証コード送信、打刻忘れアラート
- **LINE通知**: シフト変更通知、承認依頼通知
- **統合通知**: メール・LINE通知の統合管理

### 通知サービス
```ruby
class EmailNotificationService
  def send_verification_code(email, code)
    # 認証コード送信
  end

  def send_clock_reminder(employee_id)
    # 打刻忘れアラート
  end
end

class UnifiedNotificationService
  def send_shift_change_notification(employee_id, message)
    # シフト変更通知
  end

  def send_approval_request_notification(employee_id, message)
    # 承認依頼通知
  end
end
```

## 🕐 打刻忘れアラート

### 打刻忘れアラート機能
- **出勤打刻忘れ**: 出勤時刻を過ぎても打刻がない場合のアラート
- **退勤打刻忘れ**: 退勤時刻を過ぎても打刻がない場合のアラート
- **自動通知**: メール・LINEによる自動通知

### 打刻忘れアラートコントローラー
```ruby
class ClockReminderController < ApplicationController
  def index
    # 打刻忘れアラート一覧
  end

  def send_reminder
    # 打刻忘れアラート送信
  end
end
```

### 打刻忘れアラートサービス
```ruby
class ClockReminderService
  def check_forgotten_clock_ins
    # 出勤打刻忘れチェック
  end

  def check_forgotten_clock_outs
    # 退勤打刻忘れチェック
  end

  def send_reminder_notification(employee_id, type)
    # 打刻忘れ通知送信
  end
end
```

## 🔗 Freee API連携

### Freee API連携機能
- **従業員情報取得**: リアルタイムでの従業員データ同期
- **給与データ取得**: 最新の給与情報の取得
- **勤怠データ取得**: 勤怠記録の取得
- **組織情報取得**: 部署・役職情報の取得

### Freee APIサービス
```ruby
class FreeeApiService
  def get_employees
    # 従業員一覧取得
  end

  def get_employee_info(employee_id)
    # 個別従業員情報取得
  end

  def get_time_clocks(employee_id, from_date, to_date)
    # 勤怠記録取得
  end

  def create_work_record(employee_id, form_data)
    # 勤怠記録作成
  end
end
```

## 📱 レスポンシブデザイン

### レスポンシブ対応
- **モバイル対応**: スマートフォンでの利用
- **タブレット対応**: タブレットでの利用
- **デスクトップ対応**: PCでの利用

### CSS設計
```css
/* モバイルファーストデザイン */
.container {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 16px;
}

/* タブレット対応 */
@media (min-width: 768px) {
  .container {
    padding: 0 24px;
  }
}

/* デスクトップ対応 */
@media (min-width: 1024px) {
  .container {
    padding: 0 32px;
  }
}
```

## 🧪 テスト仕様

### テスト構成
- **単体テスト**: モデル・サービスのテスト
- **統合テスト**: コントローラーのテスト
- **システムテスト**: エンドツーエンドのテスト

### テスト例
```ruby
class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_index_url
    assert_response :success
  end

  test "should clock in" do
    post dashboard_clock_in_url
    assert_response :success
  end

  test "should clock out" do
    post dashboard_clock_out_url
    assert_response :success
  end
end
```

## 🚀 パフォーマンス最適化

### 最適化項目
- **データベースクエリ**: N+1問題の解決
- **キャッシュ**: 頻繁にアクセスされるデータのキャッシュ
- **非同期処理**: 重い処理の非同期化
- **CDN**: 静的ファイルの配信最適化

### キャッシュ戦略
```ruby
class FreeeApiService
  CACHE_DURATION = 5.minutes

  def get_employees
    Rails.cache.fetch("employees_#{@company_id}", expires_in: CACHE_DURATION) do
      # API呼び出し
    end
  end
end
```

## 🔒 セキュリティ

### セキュリティ対策
- **CSRF対策**: CSRFトークンによる保護
- **XSS対策**: 入力値のサニタイズ
- **SQLインジェクション対策**: パラメータ化クエリ
- **セッション管理**: セキュアなセッション管理

### セキュリティ実装
```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :set_security_headers

  private

  def set_security_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
  end
end
```

## 📊 監視・ログ

### 監視項目
- **アプリケーション**: レスポンス時間、エラー率
- **データベース**: 接続数、クエリ時間
- **外部API**: Freee API のレスポンス時間
- **ユーザー**: アクティブユーザー数

### ログ設定
```ruby
# config/environments/production.rb
config.log_level = :info
config.log_formatter = ::Logger::Formatter.new

# 構造化ログ
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
```

## 🚀 今後の拡張予定

### 機能拡張
- **ダッシュボード改善**: より詳細な統計情報
- **レポート機能**: 勤怠レポートの生成
- **カレンダー連携**: Google Calendar連携
- **モバイルアプリ**: ネイティブアプリの開発

### 技術的改善
- **SPA化**: React/Vue.jsによるSPA化
- **API化**: RESTful APIの提供
- **マイクロサービス**: サービス分割
- **CI/CD**: 自動デプロイの実装

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
