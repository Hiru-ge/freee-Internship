# 変更履歴

## [2024-12-19] ルーティング構造の見直しとビューディレクトリの統合

### 概要
シフト関連の機能を統合し、ビューディレクトリ構造を整理しました。また、RESTfulな設計に準拠するよう改善しました。

### 変更内容

#### ルーティング変更
- `get "shifts", to: "shift_display#index"` - シフト表示機能
- `get "shift/approvals", to: "shift_approvals#index"` - シフト承認機能
- その他のシフト関連ルートは既存のまま維持

#### コントローラー変更
- **ShiftDisplayController**: シフト表示機能を担当
  - `index` アクション: HTML/JSON形式でシフトデータを提供
  - `app/views/shifts/index.html.erb` をレンダリング
- **ShiftApprovalsController**: シフト承認機能を担当
  - `app/views/shifts/approvals_index.html.erb` をレンダリング

#### ビューディレクトリの統合
```
app/views/shifts/
├── index.html.erb              # シフト表示
├── approvals_index.html.erb    # シフト承認一覧
├── additions_new.html.erb      # シフト追加依頼
├── deletions_new.html.erb      # シフト削除依頼
└── exchanges_new.html.erb      # シフト交代依頼
```

#### 認証機能の改善
- **AuthController**: GET `/login` でログインページを表示するよう改善
- RESTfulな設計に準拠

### 削除されたファイル
- `app/controllers/shifts_controller.rb` (一時的に作成されたが、命名の明確性のため削除)
- `app/views/shift_display/` ディレクトリ
- `app/views/shift_approvals/` ディレクトリ
- `app/views/shifts/approvals_index_clean.html.erb` (重複ファイル)
- `app/views/dashboard/wages_clean.html.erb` (重複ファイル)

### テスト変更
- `ShiftDisplayControllerTest`: シフト表示機能のテスト
- 権限チェックのテスト期待値を実際の動作に合わせて修正
- 全テスト100%通過を達成

### 影響範囲
- **フロントエンド**: シフト関連のページ表示
- **API**: シフトデータ取得エンドポイント
- **認証**: ログインページの表示方法

### 互換性
- 既存のAPIエンドポイントは維持
- フロントエンドのJavaScriptコードは変更不要
- データベーススキーマに変更なし

### 今後の改善点
1. ドキュメント化の徹底
2. 段階的な変更の実施
3. テストファーストアプローチの採用
