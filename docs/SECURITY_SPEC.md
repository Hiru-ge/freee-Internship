# セキュリティ仕様書

勤怠管理システムのセキュリティ対策と実装仕様です。

## 🎯 概要

LINE Bot連携システムにおけるセキュリティ対策の詳細仕様です。

## 🔐 認証・認可

### LINE Webhook署名検証
```ruby
def verify_line_signature(body, signature)
  hash = OpenSSL::HMAC.digest(
    OpenSSL::Digest.new('sha256'),
    ENV['LINE_CHANNEL_SECRET'],
    body
  )

  expected_signature = Base64.strict_encode64(hash)
  signature == expected_signature
end
```

**実装箇所**: `WebhookController`
**検証内容**:
- `X-Line-Signature`ヘッダーの検証
- HMAC-SHA256による署名検証
- リクエストボディの改ざん検出

### 従業員認証
```ruby
def authenticate_employee(line_user_id)
  employee = Employee.find_by(line_id: line_user_id)
  return nil unless employee

  # アクティブな従業員のみ認証
  return nil unless employee.status == 'active'

  employee
end
```

**認証要件**:
- LINEアカウントと従業員アカウントの紐付け
- 認証コードによる二段階認証
- 有効期限付きの認証コード

## 🛡️ データ保護

### 認証コードの保護
```ruby
def generate_verification_code
  # 6桁のランダム数字
  SecureRandom.random_number(1000000).to_s.rjust(6, '0')
end

def store_verification_code(employee_id, code)
  VerificationCode.create!(
    employee_id: employee_id,
    code: code,
    expires_at: 30.minutes.from_now
  )
end
```

**保護措置**:
- ランダム生成による予測困難性
- 30分の短期有効期限
- 1回のみ使用可能
- 使用後の自動削除

### 会話状態の保護
```ruby
def set_conversation_state(line_user_id, state, state_data = {})
  ConversationState.create!(
    line_user_id: line_user_id,
    state: state,
    state_data: state_data.to_json,
    expires_at: 1.hour.from_now
  )
end
```

**保護措置**:
- 1時間の有効期限
- 自動削除によるデータ漏洩防止
- JSON形式での安全なデータ保存

## 🔒 アクセス制御

### チャット種別による制御
```ruby
def handle_message(event)
  if group_message?(event)
    handle_group_message(event)
  else
    handle_individual_message(event)
  end
end

def group_message?(event)
  event['source']['type'] == 'group'
end
```

**制御内容**:
- 個人チャット: 全機能利用可能
- グループチャット: シフト管理機能のみ
- 認証機能: 個人チャット限定

### 権限ベースアクセス制御
```ruby
def check_permission(employee, action)
  case action
  when :shift_addition
    employee.role == 'owner'
  when :shift_management
    employee.role.in?(['owner', 'employee'])
  else
    false
  end
end
```

**権限レベル**:
- **Owner**: 全機能利用可能
- **Employee**: 基本機能のみ利用可能

## 🚫 入力値検証

### 日付検証
```ruby
def validate_date_format(date_string)
  return false unless date_string.match?(/\A\d{1,2}\/\d{1,2}\z/)

  month, day = date_string.split('/').map(&:to_i)
  return false unless (1..12).include?(month)
  return false unless (1..31).include?(day)

  true
end
```

### 時間検証
```ruby
def validate_time_format(time_string)
  return false unless time_string.match?(/\A\d{1,2}:\d{2}-\d{1,2}:\d{2}\z/)

  start_time, end_time = time_string.split('-')
  start_hour, start_min = start_time.split(':').map(&:to_i)
  end_hour, end_min = end_time.split(':').map(&:to_i)

  return false unless (0..23).include?(start_hour) && (0..59).include?(start_min)
  return false unless (0..23).include?(end_hour) && (0..59).include?(end_min)
  return false unless start_time < end_time

  true
end
```

### 従業員名検証
```ruby
def validate_employee_name(name)
  return false if name.blank?
  return false if name.length > 50
  return false if name.match?(/[<>\"'&]/)  # XSS対策

  true
end
```

## 🔍 ログ・監査

### セキュリティログ
```ruby
def log_security_event(event_type, user_id, details = {})
  SecurityLog.create!(
    event_type: event_type,
    user_id: user_id,
    details: details.to_json,
    ip_address: request.remote_ip,
    user_agent: request.user_agent,
    timestamp: Time.current
  )
end
```

**ログ対象**:
- 認証試行
- 認証成功/失敗
- 権限エラー
- 不正な入力
- API呼び出し

### 監査証跡
```ruby
def audit_shift_change(employee, action, details)
  AuditLog.create!(
    employee_id: employee.employee_id,
    action: action,
    details: details.to_json,
    timestamp: Time.current
  )
end
```

**監査対象**:
- シフト変更
- 従業員情報変更
- 権限変更
- データ削除

## 🚨 異常検知

### 認証試行の監視
```ruby
def detect_brute_force_attack(line_user_id)
  recent_attempts = VerificationCode.where(
    employee_id: line_user_id,
    created_at: 1.hour.ago..Time.current
  ).count

  if recent_attempts > 5
    log_security_event('brute_force_attempt', line_user_id)
    block_user(line_user_id)
  end
end
```

### 異常なアクセスパターンの検知
```ruby
def detect_anomalous_access(employee_id)
  recent_requests = AuditLog.where(
    employee_id: employee_id,
    created_at: 1.hour.ago..Time.current
  ).count

  if recent_requests > 100
    log_security_event('anomalous_access', employee_id)
    notify_admin(employee_id)
  end
end
```

## 🔐 データ暗号化

### 機密データの暗号化
```ruby
def encrypt_sensitive_data(data)
  cipher = OpenSSL::Cipher.new('AES-256-CBC')
  cipher.encrypt
  cipher.key = ENV['ENCRYPTION_KEY']
  cipher.iv = SecureRandom.random_bytes(16)

  encrypted = cipher.update(data) + cipher.final
  Base64.strict_encode64(encrypted)
end
```

### 暗号化対象データ
- 認証コード
- 個人情報
- 機密設定

## 🛡️ SQLインジェクション対策

### パラメータ化クエリ
```ruby
def find_employee_by_name(name)
  Employee.where("name LIKE ?", "%#{name}%")
end

def find_shifts_by_date(date)
  Shift.where(shift_date: date)
end
```

### 入力値のサニタイズ
```ruby
def sanitize_input(input)
  input.to_s.strip.gsub(/[<>\"'&]/, '')
end
```

## 🔒 CSRF対策

### CSRFトークン
```ruby
def generate_csrf_token
  session[:csrf_token] = SecureRandom.hex(32)
end

def verify_csrf_token(token)
  session[:csrf_token] == token
end
```

## 📊 セキュリティ監視

### 監視項目
- 認証失敗率
- 異常なアクセスパターン
- エラー発生率
- レスポンス時間

### アラート設定
```ruby
def check_security_metrics
  if authentication_failure_rate > 0.1
    send_alert('High authentication failure rate')
  end

  if error_rate > 0.05
    send_alert('High error rate detected')
  end
end
```

## 🧪 セキュリティテスト

### 脆弱性テスト
```ruby
describe 'Security Tests' do
  it 'SQLインジェクション攻撃を防ぐ' do
    malicious_input = "'; DROP TABLE employees; --"

    expect {
      Employee.where("name = ?", malicious_input)
    }.not_to raise_error
  end

  it 'XSS攻撃を防ぐ' do
    malicious_input = "<script>alert('XSS')</script>"

    result = sanitize_input(malicious_input)
    expect(result).not_to include('<script>')
  end
end
```

### 認証テスト
```ruby
describe 'Authentication Security' do
  it '無効な認証コードを拒否する' do
    response = post '/webhook', params: {
      events: [{
        type: 'message',
        message: { text: '123456' },
        source: { userId: 'test_user' }
      }]
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('認証コードが正しくありません')
  end
end
```

## 🚀 今後のセキュリティ強化

### 計画中の対策
- 二要素認証の追加
- IPアドレス制限
- デバイス認証
- 生体認証連携
- 暗号化の強化
- セキュリティ監視の自動化

### 継続的改善
- 定期的なセキュリティ監査
- 脆弱性スキャンの実施
- セキュリティ教育の実施
- インシデント対応手順の整備

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
