# LINE Bot機能

勤怠管理システムのLINE Bot連携機能について説明します。

## 🎯 概要

LINE Bot機能は、従業員がLINE経由でシフト管理を行うための機能です。グループLINEでのシフト交代依頼・承認、個人チャットでのシフト確認などが可能です。

## 🏗️ アーキテクチャ

### 責務分離後のサービス構成

巨大な `LineBotService` クラス（2,303行）を9つの専門サービスクラスに分割し、単一責任原則に基づいた設計を実現しました。

#### 1. LineBotService（メインコントローラー）
- **責任**: LINE Bot のメインエントリーポイント、メッセージルーティング
- **主要メソッド**: `handle_message`, `handle_postback_event`, `handle_request_check_command`

#### 2. LineAuthenticationService（認証サービス）
- **責任**: LINE アカウントと従業員アカウントの紐付け認証
- **主要メソッド**: `handle_auth_command`, `handle_employee_name_input`, `handle_verification_code_input`

#### 3. LineConversationService（会話状態管理サービス）
- **責任**: マルチステップの対話処理における会話状態の管理
- **管理する状態**: 従業員名入力待ち、認証コード入力待ち、シフト日付入力待ちなど

#### 4. LineShiftService（シフト管理サービス）
- **責任**: シフト情報の取得と表示
- **主要メソッド**: `handle_shift_command`, `handle_all_shifts_command`

#### 5. LineShiftExchangeService（シフト交代サービス）
- **責任**: シフト交代リクエストの作成、承認、拒否処理
- **主要メソッド**: `handle_shift_exchange_command`, `handle_approval_postback`

#### 6. LineShiftAdditionService（シフト追加サービス）
- **責任**: シフト追加リクエストの作成、承認、拒否処理
- **主要メソッド**: `handle_shift_addition_command`, `handle_shift_addition_approval_postback`

#### 7. LineMessageService（メッセージ生成サービス）
- **責任**: 各種メッセージの生成（Flex Message、テキストメッセージ）
- **主要メソッド**: `generate_help_message`, `generate_shift_flex_message_for_date`

#### 8. LineValidationService（バリデーションサービス）
- **責任**: 各種入力値の検証
- **主要メソッド**: `validate_shift_date`, `validate_shift_time`, `validate_employee_name`

#### 9. LineNotificationService（通知サービス）
- **責任**: LINE メッセージとメール通知の送信
- **主要メソッド**: `send_shift_exchange_approval_notification`, `send_line_message`

#### 10. LineUtilityService（ユーティリティサービス）
- **責任**: 共通的なユーティリティ機能
- **主要メソッド**: `extract_user_id`, `format_date`, `format_time`

## 📱 対応機能

### 認証システム
- **従業員名入力による認証**: 従業員IDではなく、より使いやすい従業員名での認証
- **多段階認証フロー**: 従業員名入力 → 認証コード生成 → メール送信 → 認証コード入力
- **会話状態管理**: ConversationStateモデルによる複数ターンにまたがる認証フローの管理
- **セキュリティ**: 認証コードによる安全なアカウント紐付け

### シフト管理機能
- **個人シフト確認**: 認証済みユーザーの個人シフト情報表示
- **全従業員シフト確認**: 認証済みユーザーが全従業員のシフト情報を確認可能
- **シフト交代依頼**: 日付入力による絞り込み方式でシフト交代依頼
- **シフト交代承認**: 依頼されたシフト交代を承認・否認

### シフト追加機能
- **シフト追加依頼**: オーナーが新しいシフトの追加依頼（日付・時間・対象従業員指定）
- **シフト追加承認**: 依頼されたシフト追加を承認・否認
- **複数人対応**: カンマ区切りでの複数従業員への一括依頼
- **重複チェック**: 既存シフトとの重複を自動チェック

## 💬 利用可能なコマンド

### 基本コマンド
- **ヘルプ**: 利用可能なコマンドを表示
- **認証**: 従業員名入力による認証（個人チャットのみ）
- **シフト**: 個人のシフト情報を確認
- **全員シフト**: 全従業員のシフト情報を確認

### シフト交代コマンド
- **シフト交代**: シフト交代依頼（日付入力による絞り込み方式）
- **リクエスト確認**: 承認待ちのシフト交代リクエスト確認

### シフト追加コマンド（オーナーのみ）
- **シフト追加**: 新しいシフトの追加依頼

## 🔄 処理フロー

### 認証フロー
```
ユーザー → LineBotService → LineAuthenticationService → LineNotificationService
                ↓
        LineConversationService (状態管理)
                ↓
        データベース (Employee, VerificationCode)
```

### シフト交代フロー
```
ユーザー → LineBotService → LineShiftExchangeService → LineConversationService
                ↓                    ↓
        LineMessageService    LineValidationService
                ↓                    ↓
        LineNotificationService   データベース (ShiftExchange, Shift)
```

### シフト追加フロー
```
ユーザー → LineBotService → LineShiftAdditionService → LineConversationService
                ↓                    ↓
        LineMessageService    LineValidationService
                ↓                    ↓
        LineNotificationService   データベース (ShiftAddition, Shift)
```

## 🎨 Flex Message仕様

### シフトカード形式
シフト交代依頼時に表示されるFlex Message形式のシフトカードです。

```json
{
  "type": "flex",
  "altText": "シフト交代依頼 - 交代したいシフトを選択してください",
  "contents": {
    "type": "carousel",
    "contents": [
      {
        "type": "bubble",
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": "シフト交代依頼",
              "weight": "bold",
              "size": "xl",
              "color": "#1DB446"
            },
            {
              "type": "separator",
              "margin": "md"
            },
            {
              "type": "box",
              "layout": "vertical",
              "margin": "md",
              "spacing": "sm",
              "contents": [
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "📅",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "12/25 (水)",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "⏰",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "09:00-18:00",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                }
              ]
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "style": "primary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "交代を依頼",
                "data": "shift_123",
                "displayText": "12/25のシフト交代を依頼します"
              }
            }
          ]
        }
      }
    ]
  }
}
```

### 承認待ちリクエスト形式
承認待ちのシフト交代リクエストを表示するFlex Messageです。

```json
{
  "type": "flex",
  "altText": "承認待ちのシフト交代リクエスト",
  "contents": {
    "type": "carousel",
    "contents": [
      {
        "type": "bubble",
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": "シフト交代承認",
              "weight": "bold",
              "size": "xl",
              "color": "#1DB446"
            },
            {
              "type": "separator",
              "margin": "md"
            },
            {
              "type": "box",
              "layout": "vertical",
              "margin": "md",
              "spacing": "sm",
              "contents": [
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "👤",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "申請者: 田中太郎",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "📅",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "12/25 (水)",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "⏰",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "09:00-18:00",
                      "wrap": true,
                      "color": "#666666",
                      "size": "sm",
                      "flex": 0
                    }
                  ]
                }
              ]
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "style": "primary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "承認",
                "data": "approve_123",
                "displayText": "12/25のシフト交代を承認します"
              }
            },
            {
              "type": "button",
              "style": "secondary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "拒否",
                "data": "reject_123",
                "displayText": "12/25のシフト交代を拒否します"
              }
            }
          ]
        }
      }
    ]
  }
}
```

## 🔐 セキュリティ

### 署名検証
LINE webhookの署名検証を実装しています。

**検証方法**:
1. `X-Line-Signature`ヘッダーから署名を取得
2. リクエストボディと`LINE_CHANNEL_SECRET`でHMAC-SHA256を計算
3. 署名を比較して検証

### 認証制御
- シフト確認機能はすべて認証が必要
- チャット分離: 認証は個人チャットでのみ実行可能
- アクセス制御: 未認証ユーザーには適切な案内メッセージを表示
- データ保護: 認証コードによる安全な認証、有効期限付きの会話状態管理

## 📊 実装状況

### 完了済み機能
- ✅ 認証システム
- ✅ シフト確認機能
- ✅ シフト交代機能
- ✅ シフト追加機能
- ✅ 責務分離完了（2,303行 → 9つの専門サービス）
- ✅ テスト保守性向上完了（227テスト、706アサーション、100%成功）
- ✅ 不要機能削除完了（Phase 14-1）

### 技術的成果
- **保守性の向上**: 機能ごとの独立したクラスにより、変更影響範囲を限定
- **テスタビリティの向上**: 各機能の独立したテスト実行が可能
- **可読性の向上**: 明確な責任分離により、コードの理解が容易
- **拡張性の向上**: 新機能追加時の影響を最小化
- **パフォーマンスの向上**: 遅延ロードとクエリ最適化による効率化

## 🧪 テスト戦略

### テストの階層構造
```
LineBotService（統合テスト）
├── LineAuthenticationService（単体テスト）
├── LineConversationService（単体テスト）
├── LineShiftService（単体テスト）
├── LineShiftExchangeService（単体テスト）
├── LineShiftAdditionService（単体テスト）
├── LineMessageService（単体テスト）
├── LineValidationService（単体テスト）
├── LineNotificationService（単体テスト）
└── LineUtilityService（単体テスト）
```

### テスト結果
- **315テスト、797アサーション、100%成功**
- **エラー完全解消（48 → 0）**
- **失敗完全解消（6 → 0）**
- **不要機能削除後のテスト最適化完了**

## 🚀 今後の拡張予定

### 機能拡張
- 打刻リマインダー機能
- シフト変更通知機能
- その他の便利機能

### 技術的改善
- パフォーマンス最適化
- セキュリティ強化
- ユーザビリティ向上

## 📚 参考資料

- [LINE Messaging API リファレンス](https://developers.line.biz/en/reference/messaging-api/)
- [LINE Bot SDK for Ruby](https://github.com/line/line-bot-sdk-ruby)
- [Rails API ガイド](https://guides.rubyonrails.org/api_app.html)

この設計により、LINE Bot の機能拡張と保守が大幅に改善され、長期的な開発効率の向上が期待できます。
