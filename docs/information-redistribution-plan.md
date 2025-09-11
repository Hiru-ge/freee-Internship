# 情報再配置計画書

## 概要
現在のダッシュボードから削除される情報（103万の壁ゲージ、月別勤怠履歴）を適切な場所に再配置し、各画面の役割を明確化する。

## 再配置対象の情報

### 1. 103万の壁ゲージ
**現在の場所**: ダッシュボード
**新しい場所**: シフトページ
**理由**: シフトと給与は密接に関連しており、シフト確認時に給与状況も一緒に確認できる

### 2. 月別勤怠履歴
**現在の場所**: ダッシュボード
**新しい場所**: ダッシュボード（ページネーション機能付き）+ 専用の勤怠履歴ページ（既存コンポーネント活用）
**理由**: ダッシュボードで月別確認、詳細確認は専用ページで提供する

## 詳細な再配置計画

### 1. 103万の壁ゲージのシフトページ統合

#### オーナー向け表示
```
シフトページ
├── シフト表（週単位表示）
├── 全従業員の給与状況一覧
│   ├── 従業員名
│   ├── 給与ゲージ
│   ├── 達成率
│   └── 勤務時間
└── シフト管理機能
```

#### 従業員向け表示
```
シフトページ
├── シフト表（週単位表示）
├── 個人の給与ゲージ
│   ├── 現在の給与額
│   ├── 目標額
│   ├── 達成率
│   └── 残り必要額
└── シフト管理機能
```

#### 実装詳細

##### シフトページビューの更新
```erb
<!-- 既存のシフトページに追加 -->
<% if @is_owner %>
  <!-- オーナー: 全従業員の給与状況 -->
  <div class="employee-wages-section">
    <h2>全従業員の給与状況</h2>
    <div class="wages-grid">
      <% @employee_wages.each do |wage| %>
        <div class="wage-card">
          <div class="employee-name"><%= wage[:employee_name] %></div>
          <div class="wage-gauge">
            <div class="gauge-bar">
              <div class="gauge-fill" style="width: <%= [wage[:percentage], 100].min %>%"></div>
            </div>
            <div class="gauge-text">
              ¥<%= number_with_delimiter(wage[:wage]) %> / ¥<%= number_with_delimiter(wage[:target]) %>
            </div>
          </div>
          <div class="achievement-rate <%= wage[:percentage] >= 100 ? 'achieved' : '' %>">
            <%= wage[:percentage] %>%
          </div>
        </div>
      <% end %>
    </div>
  </div>
<% else %>
  <!-- 従業員: 個人の給与ゲージ -->
  <div class="personal-wage-section">
    <h2>103万の壁ゲージ</h2>
    <div class="wage-gauge-large">
      <div class="wage-info">
        <span class="current-wage">¥<%= number_with_delimiter(@wage_info[:wage]) %></span>
        <span class="target-wage">/ ¥<%= number_with_delimiter(@wage_info[:target]) %></span>
      </div>
      <div class="gauge-container">
        <div class="gauge-bar">
          <div class="gauge-fill" style="width: <%= [@wage_info[:percentage], 100].min %>%"></div>
        </div>
        <div class="gauge-percentage"><%= @wage_info[:percentage] %>%</div>
      </div>
      <% if @wage_info[:wage] >= @wage_info[:target] %>
        <div class="achievement-message">目標達成！</div>
      <% else %>
        <div class="remaining-amount">
          残り: ¥<%= number_with_delimiter(@wage_info[:target] - @wage_info[:wage]) %>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

##### コントローラーの更新
```ruby
# app/controllers/shifts_controller.rb
class ShiftsController < ApplicationController
  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @is_owner = owner?
    
    # 給与情報を取得
    if @is_owner
      # オーナー: 全従業員の給与情報
      wage_service = WageService.new
      @employee_wages = wage_service.get_all_employees_wages(
        Date.current.month, 
        Date.current.year
      )
    else
      # 従業員: 個人の給与情報
      wage_service = WageService.new
      @wage_info = wage_service.get_wage_info(@employee_id)
    end
  end
end
```

### 2. 勤怠履歴専用ページの作成

#### 新しいページ構成
```
勤怠履歴ページ
├── 月別ナビゲーション（前月/次月）
├── 勤怠履歴テーブル
│   ├── 日付
│   ├── 出勤時間
│   ├── 退勤時間
│   ├── 勤務時間
│   └── 備考
└── 月間サマリー
    ├── 総勤務時間
    ├── 出勤日数
    ├── 平均勤務時間
    └── 残業時間
```


### 3. ナビゲーションの統合

#### ヘッダーナビゲーションへの統合
- ダッシュボードから不要なナビゲーションリンクを削除
- ヘッダーナビゲーションで統一されたアクセスを提供
- クイックアクセスのみダッシュボードに残す


## 実装手順

### Step 1: シフトページへの給与ゲージ統合（フロントエンドのみ）
1. シフトページビューの更新
2. 既存コントローラーの活用
3. オーナー/従業員別の表示制御
4. スタイリングの調整

### Step 2: 勤怠履歴ページの作成（フロントエンドのみ）
1. 既存コントローラー（DashboardController）の拡張
2. ビューファイルの作成
3. ルーティングの追加
4. 月間サマリーとページネーション機能の実装

### Step 3: ダッシュボードの簡素化（フロントエンドのみ）
1. 不要なセクションの削除
2. クイックアクセスの実装
3. レイアウトの調整

### Step 4: テストと調整
1. 各画面での表示確認

### 実装範囲
**この情報再配置はフロントエンドのみの変更で十分実現可能です。**
- 既存のコントローラー・サービス・APIをそのまま活用
- ビューファイル（HTML/CSS/JavaScript）の変更のみ
- 新規のバックエンド開発は不要
2. 機能動作のテスト
3. レスポンシブ対応の確認

## 期待される効果

### 1. 情報の適切な配置
- 関連性の高い情報がグループ化される
- 各画面の役割が明確になる
- 情報の重複が排除される

### 2. ユーザビリティの向上
- 目的に応じた適切な画面への誘導
- 情報の探しやすさの向上
- 操作効率の改善

### 3. 保守性の向上
- 各画面の責任範囲が明確になる
- コードの整理と最適化
- 今後の機能追加が容易になる

## まとめ
この情報再配置により、各画面の役割が明確になり、ユーザーが必要な情報を適切な場所で確認できるようになる。また、ダッシュボードの簡素化により、打刻機能に集中できる環境を提供する。
