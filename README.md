# GASプロジェクト - Cursor開発環境

このプロジェクトは、Google Apps Script (GAS) プロジェクトをCursorエディタで開発するためのローカル環境です。

## セットアップ手順

### 1. 前提条件
- Node.jsがインストールされていること
- Cursorエディタがインストールされていること

### 2. claspのインストール
```bash
npm install -g @google/clasp
```

### 3. Googleアカウントでの認証
```bash
clasp login
```

### 4. プロジェクトのクローン
```bash
clasp clone 1d4SbemkCanj0RUeVfJjSIcDLdP6FZtOYQBrKouLn-Typ9G6aTTrB-Awd --rootDir ./src
```

### 5. 開発とデプロイ
- コード編集後、変更をアップロード: `clasp push`
- 最新の変更を取得: `clasp pull`
- プロジェクトをブラウザで開く: `clasp open`

## プロジェクト構造
```
.
├── .clasp.json          # clasp設定ファイル
├── .gitignore          # Git除外ファイル
├── docs/               # ドキュメント
└── src/                # GASソースコード（clasp clone後に作成）
```

## 注意事項
- `.clasp.json`ファイルには機密情報が含まれるため、Gitにコミットしないでください
- 初回セットアップ時は、Google Apps Script APIの有効化が必要です
