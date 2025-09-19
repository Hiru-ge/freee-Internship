# ビュー仕様書

勤怠管理システムのビュー層（フロントエンド）の詳細仕様です。

## 🎯 概要

勤怠管理システムのWebインターフェースの設計、実装、ユーザビリティの詳細仕様です。

## 🏗️ 技術スタック

### フロントエンド技術
- **HTML5**: セマンティックマークアップ
- **CSS3**: レスポンシブデザイン、Flexbox、Grid
- **JavaScript**: バニラJS、DOM操作
- **Bootstrap**: UIフレームワーク（一部使用）

### アセット管理
- **Sprockets**: アセットパイプライン
- **SCSS**: CSSプリプロセッサ
- **CoffeeScript**: JavaScriptプリプロセッサ（一部）

## 📱 レスポンシブデザイン

### ブレークポイント
```scss
// モバイルファーストデザイン
$mobile: 576px;
$tablet: 768px;
$desktop: 1024px;
$large-desktop: 1200px;

// メディアクエリ
@media (min-width: $tablet) {
  // タブレット対応
}

@media (min-width: $desktop) {
  // デスクトップ対応
}
```

### レスポンシブ対応
- **モバイル**: 320px〜767px
- **タブレット**: 768px〜1023px
- **デスクトップ**: 1024px以上

## 🎨 デザインシステム

### カラーパレット
```scss
// プライマリカラー
$primary-color: #007bff;
$primary-dark: #0056b3;
$primary-light: #66b3ff;

// セカンダリカラー
$secondary-color: #6c757d;
$secondary-dark: #545b62;
$secondary-light: #adb5bd;

// ステータスカラー
$success-color: #28a745;
$warning-color: #ffc107;
$danger-color: #dc3545;
$info-color: #17a2b8;

// グレースケール
$white: #ffffff;
$light-gray: #f8f9fa;
$gray: #6c757d;
$dark-gray: #343a40;
$black: #000000;
```

### タイポグラフィ
```scss
// フォントファミリー
$font-family-base: 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', 'Yu Gothic', 'Meiryo', sans-serif;
$font-family-mono: 'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', monospace;

// フォントサイズ
$font-size-base: 16px;
$font-size-sm: 14px;
$font-size-lg: 18px;
$font-size-xl: 20px;

// フォントウェイト
$font-weight-light: 300;
$font-weight-normal: 400;
$font-weight-bold: 700;
```

### スペーシング
```scss
// スペーシングスケール
$spacing-xs: 4px;
$spacing-sm: 8px;
$spacing-md: 16px;
$spacing-lg: 24px;
$spacing-xl: 32px;
$spacing-xxl: 48px;
```

## 📄 ページ構成

### 1. アクセス認証画面
**ファイル**: `app/views/auth/index.html.erb`

```erb
<div class="auth-container">
  <div class="auth-card">
    <h1 class="auth-title">勤怠管理システム</h1>
    <p class="auth-subtitle">メールアドレスを入力してください</p>

    <%= form_with url: auth_verify_email_path, method: :post, local: true, class: "auth-form" do |form| %>
      <div class="form-group">
        <%= form.email_field :email, class: "form-control", placeholder: "メールアドレス", required: true %>
      </div>

      <div class="form-group">
        <%= form.submit "認証コードを送信", class: "btn btn-primary btn-block" %>
      </div>
    <% end %>
  </div>
</div>
```

**スタイル**:
```scss
.auth-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.auth-card {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

.auth-title {
  text-align: center;
  color: $primary-color;
  margin-bottom: 0.5rem;
}

.auth-subtitle {
  text-align: center;
  color: $gray;
  margin-bottom: 2rem;
}
```

### 2. ダッシュボード画面
**ファイル**: `app/views/dashboard/index.html.erb`

```erb
<div class="dashboard-container">
  <header class="dashboard-header">
    <h1>ダッシュボード</h1>
    <div class="user-info">
      <span class="user-name"><%= @employee.name %></span>
      <span class="user-role"><%= @employee.role == 'owner' ? 'オーナー' : '従業員' %></span>
    </div>
  </header>

  <div class="dashboard-content">
    <!-- 打刻セクション -->
    <section class="clock-section">
      <h2>打刻</h2>
      <div class="clock-buttons">
        <button id="clock-in-btn" class="btn btn-success btn-lg" <%= 'disabled' unless @clock_status[:can_clock_in] %>>
          出勤打刻
        </button>
        <button id="clock-out-btn" class="btn btn-danger btn-lg" <%= 'disabled' unless @clock_status[:can_clock_out] %>>
          退勤打刻
        </button>
      </div>
      <p class="clock-status"><%= @clock_status[:message] %></p>
    </section>

    <!-- 給与情報セクション -->
    <section class="wage-section">
      <h2>給与情報</h2>
      <div class="wage-gauge">
        <div class="gauge-container">
          <div class="gauge-fill" style="width: <%= @wage_percentage %>%"></div>
        </div>
        <p class="wage-text">
          <%= @wage_amount %>円 / <%= @wage_target %>円
          (<%= @wage_percentage %>%)
        </p>
      </div>
    </section>

    <!-- シフト情報セクション -->
    <section class="shift-section">
      <h2>今月のシフト</h2>
      <div class="shift-list">
        <% @shifts.each do |shift| %>
          <div class="shift-item">
            <span class="shift-date"><%= shift.shift_date.strftime('%m/%d') %></span>
            <span class="shift-time"><%= shift.start_time.strftime('%H:%M') %>-<%= shift.end_time.strftime('%H:%M') %></span>
          </div>
        <% end %>
      </div>
    </section>
  </div>
</div>
```

**スタイル**:
```scss
.dashboard-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid $light-gray;
}

.clock-section {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 2rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.clock-buttons {
  display: flex;
  gap: 1rem;
  margin-bottom: 1rem;
}

.wage-gauge {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 2rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.gauge-container {
  width: 100%;
  height: 20px;
  background: $light-gray;
  border-radius: 10px;
  overflow: hidden;
  margin-bottom: 1rem;
}

.gauge-fill {
  height: 100%;
  background: linear-gradient(90deg, $success-color 0%, $warning-color 70%, $danger-color 100%);
  transition: width 0.3s ease;
}
```

### 3. シフト管理画面
**ファイル**: `app/views/shifts/index.html.erb`

```erb
<div class="shifts-container">
  <header class="shifts-header">
    <h1>シフト管理</h1>
    <div class="shifts-actions">
      <button class="btn btn-primary" data-toggle="modal" data-target="#newShiftModal">
        新規シフト作成
      </button>
    </div>
  </header>

  <div class="shifts-filters">
    <div class="filter-group">
      <label for="year-select">年:</label>
      <select id="year-select" class="form-control">
        <% (Date.current.year - 1..Date.current.year + 1).each do |year| %>
          <option value="<%= year %>" <%= 'selected' if year == Date.current.year %>><%= year %></option>
        <% end %>
      </select>
    </div>

    <div class="filter-group">
      <label for="month-select">月:</label>
      <select id="month-select" class="form-control">
        <% (1..12).each do |month| %>
          <option value="<%= month %>" <%= 'selected' if month == Date.current.month %>><%= month %></option>
        <% end %>
      </select>
    </div>
  </div>

  <div class="shifts-calendar">
    <% @shifts_by_date.each do |date, shifts| %>
      <div class="calendar-day">
        <div class="day-header">
          <span class="day-date"><%= date.strftime('%m/%d') %></span>
          <span class="day-weekday"><%= %w[日 月 火 水 木 金 土][date.wday] %></span>
        </div>

        <div class="day-shifts">
          <% shifts.each do |shift| %>
            <div class="shift-card">
              <div class="shift-info">
                <span class="shift-employee"><%= shift.employee.name %></span>
                <span class="shift-time"><%= shift.start_time.strftime('%H:%M') %>-<%= shift.end_time.strftime('%H:%M') %></span>
              </div>
              <div class="shift-actions">
                <button class="btn btn-sm btn-outline-primary" onclick="editShift(<%= shift.id %>)">
                  編集
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteShift(<%= shift.id %>)">
                  削除
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

**スタイル**:
```scss
.shifts-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem;
}

.shifts-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.shifts-filters {
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
  padding: 1rem;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.shifts-calendar {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
}

.calendar-day {
  background: white;
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.day-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid $light-gray;
}

.shift-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem;
  margin-bottom: 0.5rem;
  background: $light-gray;
  border-radius: 4px;
}

.shift-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.shift-actions {
  display: flex;
  gap: 0.5rem;
}
```

### 4. 給与管理画面
**ファイル**: `app/views/wages/index.html.erb`

```erb
<div class="wages-container">
  <header class="wages-header">
    <h1>給与管理</h1>
    <div class="wages-filters">
      <select id="year-select" class="form-control">
        <% (Date.current.year - 1..Date.current.year + 1).each do |year| %>
          <option value="<%= year %>" <%= 'selected' if year == Date.current.year %>><%= year %></option>
        <% end %>
      </select>

      <select id="month-select" class="form-control">
        <% (1..12).each do |month| %>
          <option value="<%= month %>" <%= 'selected' if month == Date.current.month %>><%= month %></option>
        <% end %>
      </select>
    </div>
  </header>

  <div class="wages-content">
    <!-- 個人給与情報 -->
    <section class="personal-wage">
      <h2>個人給与情報</h2>
      <div class="wage-card">
        <div class="wage-gauge">
          <div class="gauge-container">
            <div class="gauge-fill" style="width: <%= @wage_percentage %>%"></div>
          </div>
          <div class="wage-details">
            <div class="wage-amount">
              <span class="amount"><%= number_with_delimiter(@wage_amount) %>円</span>
              <span class="target">/ <%= number_with_delimiter(@wage_target) %>円</span>
            </div>
            <div class="wage-percentage">
              <%= @wage_percentage %>%
              <% if @wage_percentage >= 100 %>
                <span class="over-limit">（103万の壁を超えています）</span>
              <% end %>
            </div>
          </div>
        </div>

        <div class="wage-breakdown">
          <h3>内訳</h3>
          <% @wage_breakdown.each do |type, data| %>
            <div class="breakdown-item">
              <span class="type-name"><%= data[:name] %></span>
              <span class="type-hours"><%= data[:hours] %>時間</span>
              <span class="type-rate"><%= number_with_delimiter(data[:rate]) %>円/時</span>
              <span class="type-wage"><%= number_with_delimiter(data[:wage]) %>円</span>
            </div>
          <% end %>
        </div>
      </div>
    </section>

    <!-- 全従業員給与情報（オーナーのみ） -->
    <% if @employee.owner? %>
      <section class="all-wages">
        <h2>全従業員給与情報</h2>
        <div class="wages-table">
          <table class="table">
            <thead>
              <tr>
                <th>従業員名</th>
                <th>給与</th>
                <th>達成率</th>
                <th>残り</th>
              </tr>
            </thead>
            <tbody>
              <% @all_wages.each do |wage| %>
                <tr>
                  <td><%= wage[:employee_name] %></td>
                  <td><%= number_with_delimiter(wage[:wage]) %>円</td>
                  <td>
                    <%= wage[:percentage] %>%
                    <% if wage[:percentage] >= 100 %>
                      <span class="over-limit">⚠️</span>
                    <% end %>
                  </td>
                  <td><%= number_with_delimiter([wage[:target] - wage[:wage], 0].max) %>円</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>
    <% end %>
  </div>
</div>
```

**スタイル**:
```scss
.wages-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem;
}

.wages-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.wages-filters {
  display: flex;
  gap: 1rem;
}

.wage-card {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  margin-bottom: 2rem;
}

.wage-details {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 1rem;
}

.wage-amount {
  font-size: 1.5rem;
  font-weight: bold;
}

.amount {
  color: $primary-color;
}

.target {
  color: $gray;
  font-size: 1rem;
}

.wage-percentage {
  font-size: 1.2rem;
  font-weight: bold;
}

.over-limit {
  color: $danger-color;
  font-size: 0.9rem;
}

.wage-breakdown {
  margin-top: 2rem;
  padding-top: 2rem;
  border-top: 1px solid $light-gray;
}

.breakdown-item {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr;
  gap: 1rem;
  padding: 0.5rem 0;
  border-bottom: 1px solid $light-gray;
}

.wages-table {
  background: white;
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.table {
  width: 100%;
  border-collapse: collapse;
}

.table th,
.table td {
  padding: 0.75rem;
  text-align: left;
  border-bottom: 1px solid $light-gray;
}

.table th {
  background: $light-gray;
  font-weight: bold;
}
```

## 🎨 コンポーネント

### 1. ボタンコンポーネント
```scss
.btn {
  display: inline-block;
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  font-weight: 500;
  text-align: center;
  text-decoration: none;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none;
    box-shadow: none;
  }
}

.btn-primary {
  background: $primary-color;
  color: white;

  &:hover {
    background: $primary-dark;
  }
}

.btn-success {
  background: $success-color;
  color: white;

  &:hover {
    background: darken($success-color, 10%);
  }
}

.btn-danger {
  background: $danger-color;
  color: white;

  &:hover {
    background: darken($danger-color, 10%);
  }
}

.btn-lg {
  padding: 0.75rem 1.5rem;
  font-size: 1.1rem;
}

.btn-sm {
  padding: 0.25rem 0.5rem;
  font-size: 0.9rem;
}

.btn-block {
  width: 100%;
}
```

### 2. フォームコンポーネント
```scss
.form-group {
  margin-bottom: 1rem;
}

.form-control {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;

  &:focus {
    outline: none;
    border-color: $primary-color;
    box-shadow: 0 0 0 2px rgba($primary-color, 0.2);
  }
}

.form-label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}
```

### 3. カードコンポーネント
```scss
.card {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.card-header {
  padding: 1rem;
  background: $light-gray;
  border-bottom: 1px solid #ddd;
}

.card-body {
  padding: 1rem;
}

.card-footer {
  padding: 1rem;
  background: $light-gray;
  border-top: 1px solid #ddd;
}
```

## 📱 モバイル対応

### モバイル専用スタイル
```scss
@media (max-width: 767px) {
  .dashboard-container,
  .shifts-container,
  .wages-container {
    padding: 0.5rem;
  }

  .dashboard-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }

  .clock-buttons {
    flex-direction: column;
  }

  .shifts-filters {
    flex-direction: column;
  }

  .shifts-calendar {
    grid-template-columns: 1fr;
  }

  .breakdown-item {
    grid-template-columns: 1fr;
    gap: 0.5rem;
  }

  .wage-details {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }
}
```

### タッチ操作対応
```scss
.btn {
  min-height: 44px; // タッチターゲットの最小サイズ
  min-width: 44px;
}

.form-control {
  min-height: 44px;
}

// タッチデバイスでのホバー効果を無効化
@media (hover: none) {
  .btn:hover {
    transform: none;
    box-shadow: none;
  }
}
```

## 🎭 JavaScript機能

### 1. 打刻機能
```javascript
// app/assets/javascripts/dashboard.js
document.addEventListener('DOMContentLoaded', function() {
  const clockInBtn = document.getElementById('clock-in-btn');
  const clockOutBtn = document.getElementById('clock-out-btn');

  if (clockInBtn) {
    clockInBtn.addEventListener('click', function() {
      performClockAction('/dashboard/clock_in', '出勤打刻');
    });
  }

  if (clockOutBtn) {
    clockOutBtn.addEventListener('click', function() {
      performClockAction('/dashboard/clock_out', '退勤打刻');
    });
  }
});

function performClockAction(url, action) {
  fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      showNotification(data.message, 'success');
      updateClockStatus();
    } else {
      showNotification(data.message, 'error');
    }
  })
  .catch(error => {
    console.error('Error:', error);
    showNotification('エラーが発生しました', 'error');
  });
}

function updateClockStatus() {
  fetch('/dashboard/clock_status')
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        updateClockButtons(data.data);
      }
    });
}

function updateClockButtons(status) {
  const clockInBtn = document.getElementById('clock-in-btn');
  const clockOutBtn = document.getElementById('clock-out-btn');
  const statusMessage = document.querySelector('.clock-status');

  clockInBtn.disabled = !status.can_clock_in;
  clockOutBtn.disabled = !status.can_clock_out;
  statusMessage.textContent = status.message;
}
```

### 2. 通知機能
```javascript
function showNotification(message, type = 'info') {
  const notification = document.createElement('div');
  notification.className = `notification notification-${type}`;
  notification.textContent = message;

  document.body.appendChild(notification);

  setTimeout(() => {
    notification.classList.add('show');
  }, 100);

  setTimeout(() => {
    notification.classList.remove('show');
    setTimeout(() => {
      document.body.removeChild(notification);
    }, 300);
  }, 3000);
}

// 通知スタイル
.notification {
  position: fixed;
  top: 20px;
  right: 20px;
  padding: 1rem 1.5rem;
  border-radius: 4px;
  color: white;
  font-weight: 500;
  z-index: 1000;
  transform: translateX(100%);
  transition: transform 0.3s ease;
}

.notification.show {
  transform: translateX(0);
}

.notification-success {
  background: $success-color;
}

.notification-error {
  background: $danger-color;
}

.notification-info {
  background: $info-color;
}
```

### 3. フィルター機能
```javascript
// app/assets/javascripts/shifts.js
document.addEventListener('DOMContentLoaded', function() {
  const yearSelect = document.getElementById('year-select');
  const monthSelect = document.getElementById('month-select');

  if (yearSelect && monthSelect) {
    yearSelect.addEventListener('change', updateShifts);
    monthSelect.addEventListener('change', updateShifts);
  }
});

function updateShifts() {
  const year = document.getElementById('year-select').value;
  const month = document.getElementById('month-select').value;

  const url = new URL(window.location);
  url.searchParams.set('year', year);
  url.searchParams.set('month', month);

  window.location.href = url.toString();
}
```

## 🧪 テスト

### ビューテスト
```ruby
# test/views/dashboard/index_test.rb
require 'test_helper'

class DashboardIndexTest < ActionView::TestCase
  test "should display dashboard elements" do
    employee = employees(:one)
    assign(:employee, employee)
    assign(:clock_status, { can_clock_in: true, can_clock_out: false, message: "出勤打刻が可能です" })

    render template: "dashboard/index"

    assert_select "h1", text: "ダッシュボード"
    assert_select ".user-name", text: employee.name
    assert_select "#clock-in-btn"
    assert_select "#clock-out-btn[disabled]"
    assert_select ".clock-status", text: "出勤打刻が可能です"
  end
end
```

## 🚀 今後の拡張予定

### 機能拡張
- **SPA化**: React/Vue.jsによるSPA化
- **PWA対応**: プログレッシブWebアプリ
- **ダークモード**: ダークテーマの実装
- **アニメーション**: より豊富なアニメーション

### 技術的改善
- **TypeScript**: 型安全性の向上
- **Webpack**: モダンなビルドツール
- **CSS-in-JS**: コンポーネントベースのスタイリング
- **アクセシビリティ**: WCAG準拠の実装

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
