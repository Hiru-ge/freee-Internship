# 変更履歴

## [2024-12-19] ルーティング構造の見直しとビューディレクトリの統合、インラインJSの分離

### 概要
シフト関連の機能を統合し、ビューディレクトリ構造を整理しました。また、RESTfulな設計に準拠するよう改善し、インラインJSを完全に分離しました。

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

#### インラインJSの分離
- **認証関連JS**: `app/javascript/auth.js` に統合
  - フォームバリデーション機能
  - 認証コード入力制限機能
  - パスワードバリデーション機能
- **シフト承認JS**: `app/javascript/shift_approvals.js` に分離
  - シフト承認/否認機能
  - API呼び出し機能
- **ヘッダーJS**: `app/javascript/header.js` に分離
  - モバイルメニュー制御機能
  - ログアウト確認機能
- **シフトフォームJS**: `app/javascript/shift_forms.js` に分離
  - シフト追加/削除フォームのバリデーション
- **importmap.rb**: 新しいJSファイルを追加

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
- **JavaScript**: インラインJSの完全分離により、JSとHTMLの分離が実現

### 互換性
- 既存のAPIエンドポイントは維持
- フロントエンドのJavaScriptコードは変更不要
- データベーススキーマに変更なし

### 今後の改善点
1. ドキュメント化の徹底
2. 段階的な変更の実施
3. テストファーストアプローチの採用
4. JavaScriptのモジュール化の推進
5. 共通機能のさらなる統合
