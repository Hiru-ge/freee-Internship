# LINE Bot デプロイ手順書

## 前提条件

- Fly.ioアカウントの設定完了
- LINE Developer Consoleアカウントの作成
- 本アプリケーションの基本デプロイ完了

## 1. LINE Developer Console設定

### 1.1 チャンネルの作成

1. [LINE Developer Console](https://developers.line.biz/console/)にログイン
2. 「Create」→「Messaging API」を選択
3. チャンネル情報を入力：
   - **Channel name**: `勤怠管理システム Bot`
   - **Channel description**: `勤怠管理システムのLINE Bot`
   - **Category**: `Business`
   - **Subcategory**: `Productivity`

### 1.2 チャンネル設定

1. 作成したチャンネルを選択
2. 「Messaging API」タブで以下を設定：
   - **Webhook URL**: `https://your-app-name.fly.dev/webhook/callback`
   - **Webhook**: `Use webhook` を有効化
   - **Auto-reply messages**: `Disabled`
   - **Greeting messages**: `Disabled`

### 1.3 認証情報の取得

1. 「Basic settings」タブで以下を確認：
   - **Channel ID**: 後で使用
   - **Channel secret**: 環境変数として設定
   - **Channel access token**: 環境変数として設定

## 2. 環境変数の設定

### 2.1 Fly.ioでの環境変数設定

```bash
# Channel Secretの設定
fly secrets set LINE_CHANNEL_SECRET="your_channel_secret_here"

# Channel Access Tokenの設定
fly secrets set LINE_CHANNEL_TOKEN="your_channel_access_token_here"
```

### 2.2 環境変数の確認

```bash
# 設定された環境変数を確認
fly secrets list
```

## 3. アプリケーションのデプロイ

### 3.1 最新コードのデプロイ

```bash
# 最新のコードをデプロイ
fly deploy
```

### 3.2 デプロイ状況の確認

```bash
# デプロイ状況を確認
fly status

# ログを確認
fly logs
```

## 4. LINE Botの動作確認

### 4.1 Webhook URLの検証

1. LINE Developer Consoleの「Messaging API」タブ
2. 「Verify」ボタンをクリック
3. 「Success」が表示されることを確認

### 4.2 友達追加のテスト

1. LINE Developer Consoleの「Messaging API」タブ
2. 「QR code」を表示
3. スマートフォンでQRコードをスキャン
4. 友達追加を完了

### 4.3 メッセージ送信のテスト

友達追加後、以下のメッセージを送信してテスト：

```
ヘルプ
```

期待される応答：
```
勤怠管理システムへようこそ！

利用可能なコマンド:
- ヘルプ: このメッセージを表示
- 認証: 認証コードを生成
- シフト: シフト情報を確認
- 勤怠: 勤怠状況を確認
```

## 5. トラブルシューティング

### 5.1 Webhook URL検証エラー

**エラー**: `Webhook URL verification failed`

**原因と解決方法**:
- URLが正しくない → 正しいURLを設定
- アプリが起動していない → `fly status`で確認
- 環境変数が設定されていない → `fly secrets list`で確認

### 5.2 メッセージが応答しない

**原因と解決方法**:
- 署名検証エラー → ログを確認
- アプリケーションエラー → `fly logs`で確認
- 環境変数の設定ミス → 再設定

### 5.3 ログの確認方法

```bash
# リアルタイムログ
fly logs -f

# 特定の時間範囲のログ
fly logs --since 1h

# エラーログのみ
fly logs | grep ERROR
```

## 6. 本番環境での監視

### 6.1 ヘルスチェック

```bash
# アプリケーションの状態確認
fly status

# ヘルスチェックエンドポイント
curl https://your-app-name.fly.dev/health
```

### 6.2 パフォーマンス監視

```bash
# メトリクス確認
fly metrics

# リソース使用状況
fly status --all
```

## 7. セキュリティチェックリスト

### 7.1 環境変数
- [ ] `LINE_CHANNEL_SECRET`が正しく設定されている
- [ ] `LINE_CHANNEL_TOKEN`が正しく設定されている
- [ ] 機密情報がコードにハードコードされていない

### 7.2 アクセス制御
- [ ] webhookエンドポイントのみ認証をスキップ
- [ ] その他のエンドポイントは認証が必要
- [ ] 署名検証が正しく動作している

### 7.3 ログ管理
- [ ] 機密情報がログに出力されていない
- [ ] エラーログが適切に記録されている
- [ ] アクセスログが監視されている

## 8. バックアップと復旧

### 8.1 設定のバックアップ

```bash
# 環境変数のバックアップ
fly secrets list > backup/secrets.txt

# アプリケーション設定のバックアップ
fly config save > backup/fly.toml
```

### 8.2 復旧手順

1. 環境変数の復元
2. アプリケーションの再デプロイ
3. LINE Developer Consoleの設定確認
4. 動作テストの実行

## 9. 今後のメンテナンス

### 9.1 定期チェック項目

- [ ] LINE Botの応答性
- [ ] エラーログの確認
- [ ] パフォーマンスメトリクス
- [ ] セキュリティアップデート

### 9.2 アップデート手順

1. ローカル環境でのテスト
2. ステージング環境でのテスト
3. 本番環境へのデプロイ
4. 動作確認とロールバック準備

## 10. 連絡先とサポート

### 10.1 緊急時の連絡先
- 開発チーム: [連絡先]
- インフラチーム: [連絡先]

### 10.2 参考資料
- [LINE Messaging API ドキュメント](https://developers.line.biz/en/docs/messaging-api/)
- [Fly.io ドキュメント](https://fly.io/docs/)
- [Rails ドキュメント](https://guides.rubyonrails.org/)
