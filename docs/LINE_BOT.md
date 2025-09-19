# LINE Bot機能

勤怠管理システムのLINE Bot連携機能について説明します。

## 概要

LINE Bot機能は、従業員がLINE経由でシフト管理を行うための機能です。グループLINEでのシフト交代依頼・承認、個人チャットでのシフト確認などが可能です。

## アーキテクチャ

### 責務分離後のサービス構成

巨大な `LineBotService` クラス（2,303行）を9つの専門サービスクラスに分割し、単一責任原則に基づいた設計を実現しました。さらに、リファクタリングにより共通化サービスを追加し、コードの重複を削減しました。

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

#### 7. LineShiftDeletionService（欠勤申請サービス）**新機能**
- **責任**: 欠勤申請のLINE連携処理
- **主要メソッド**: `handle_shift_deletion_command`, `handle_shift_selection`, `handle_shift_deletion_reason_input`

#### 8. LineMessageService（メッセージ生成サービス）
- **責任**: 各種メッセージの生成（Flex Message、テキストメッセージ）
- **主要メソッド**: `generate_help_message`, `generate_shift_flex_message_for_date`, `generate_shift_deletion_flex_message`

#### 9. LineValidationService（バリデーションサービス）
- **責任**: 各種入力値の検証
- **主要メソッド**: `validate_shift_date`, `validate_shift_time`, `validate_employee_name`

#### 10. LineNotificationService（通知サービス）
- **責任**: LINE メッセージとメール通知の送信
- **主要メソッド**: `send_shift_exchange_approval_notification`, `send_line_message`

#### 11. LineUtilityService（ユーティリティサービス）
- **責任**: 共通的なユーティリティ機能
- **主要メソッド**: `extract_user_id`, `format_date`, `format_time`

#### 12. LineMessageGeneratorService（メッセージ生成統一サービス）
- **責任**: 統一されたメッセージ生成処理
- **主要メソッド**: `generate_help_message`, `generate_multiple_employee_selection_message`

#### 13. LineValidationManagerService（バリデーション統一サービス）
- **責任**: 統一されたバリデーション処理
- **主要メソッド**: `validate_and_format_date`, `validate_and_format_time`

#### 14. LineFlexMessageBuilderService（Flex Message統一サービス）
- **責任**: 統一されたFlex Message生成処理
- **主要メソッド**: `build_shift_card`, `build_button`, `build_carousel`

## 対応機能

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

### 欠勤申請機能 **新機能**
- **欠勤申請**: 従業員が自分の未来のシフトを欠勤申請
- **シフト選択**: Flex Message形式でのシフト選択UI
- **理由入力**: 欠勤理由のテキスト入力
- **承認・拒否**: オーナーによる承認・拒否処理
- **通知機能**: 申請者と承認者への通知
- **会話状態管理**: マルチステップの対話処理
- **TDD実装**: Red, Green, Refactoringサイクルでの実装

#### 実装詳細
- **LineShiftDeletionService**: 欠勤申請のLINE連携処理
- **Flex Message**: 赤色テーマ（#FF6B6B）での統一デザイン
- **会話状態**: `waiting_shift_selection`, `waiting_deletion_reason`
- **Postback処理**: `deletion_shift_XXX`, `approve_deletion_XXX`, `reject_deletion_XXX`
- **データベース連携**: 既存の`ShiftDeletion`モデルを活用

## 💬 利用可能なコマンド

### 基本コマンド
- **ヘルプ**: 利用可能なコマンドを表示
- **認証**: 従業員名入力による認証（個人チャットのみ）
- **シフト確認**: 個人のシフト情報を確認
- **全員シフト確認**: 全従業員のシフト情報を確認

### シフト交代コマンド
- **交代依頼**: シフト交代依頼（日付入力による絞り込み方式）
- **依頼確認**: 承認待ちのシフト交代依頼確認

### シフト追加コマンド（オーナーのみ）
- **追加依頼**: 新しいシフトの追加依頼

### 欠勤申請コマンド
- **欠勤申請**: 自分のシフトの欠勤申請（Flex Message形式でのシフト選択）

## 処理フロー

### 統一されたメッセージ処理フロー
```
LINE Webhook → WebhookController → LineBotService.handle_message
                ↓
        会話状態チェック → 状態に応じた処理
                ↓
        各専門サービス（認証、シフト管理、交代、追加等）
                ↓
        統一サービス（メッセージ生成、バリデーション、Flex Message）
                ↓
        レスポンス生成
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

### 欠勤申請フロー **新機能**
```
ユーザー → LineBotService → LineShiftDeletionService → LineConversationService
                ↓                    ↓
        LineMessageService    LineValidationService
                ↓                    ↓
        LineNotificationService   データベース (ShiftDeletion, Shift)
```

## Flex Message仕様

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

### 欠勤申請シフト選択形式 **新機能**
欠勤申請時に表示されるFlex Message形式のシフト選択カードです。

```json
{
  "type": "flex",
  "altText": "欠勤申請 - シフトを選択してください",
  "contents": {
    "type": "carousel",
    "contents": [
      {
        "type": "bubble",
        "header": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": "🚫 欠勤申請",
              "weight": "bold",
              "color": "#ffffff",
              "size": "sm"
            }
          ],
          "backgroundColor": "#FF6B6B"
        },
        "body": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "text",
              "text": "12/25 (水)",
              "weight": "bold",
              "size": "lg"
            },
            {
              "type": "text",
              "text": "09:00-18:00",
              "size": "md",
              "color": "#666666",
              "margin": "md"
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "contents": [
            {
              "type": "button",
              "style": "primary",
              "height": "sm",
              "color": "#FF6B6B",
              "action": {
                "type": "postback",
                "label": "このシフトを欠勤申請",
                "data": "deletion_shift_123",
                "displayText": "12/25のシフトを欠勤申請します"
              }
            }
          ]
        }
      }
    ]
  }
}
```

## セキュリティ

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

## 機能状況

### 完了済み機能
- 認証システム
- シフト確認機能
- シフト交代機能
- シフト追加機能
- 欠勤申請機能
- 責務分離（2,303行 → 14つの専門サービス）
- テスト保守性向上（341テスト、892アサーション、100%成功）
- 不要機能削除
- 機能見直し
- リファクタリング
- 実装クリーンアップ
- ドキュメント整備

### 技術的成果
- **保守性の向上**: 機能ごとの独立したクラスにより、変更影響範囲を限定
- **テスタビリティの向上**: 各機能の独立したテスト実行が可能
- **可読性の向上**: 明確な責任分離により、コードの理解が容易
- **拡張性の向上**: 新機能追加時の影響を最小化
- **パフォーマンスの向上**: 遅延ロードとクエリ最適化による効率化
- **コード重複の削減**: 共通化サービスによる重複コードの大幅削減
- **処理の統一**: 個人・グループメッセージの統一処理による一貫性確保

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
- **341テスト、892アサーション、100%成功**
- **エラー完全解消（0）**
- **失敗完全解消（0）**
- **不要機能削除後のテスト最適化**
- **リファクタリング後のテスト安定性確保**
- **欠勤申請機能のテスト充実化**
- **統合テストの安定性向上**

## 今後の拡張予定

### 機能拡張
- 打刻リマインダー機能
- シフト変更通知機能
- その他の便利機能

### 技術的改善
- パフォーマンス最適化
- セキュリティ強化
- ユーザビリティ向上

## 参考資料

- [LINE Messaging API リファレンス](https://developers.line.biz/en/reference/messaging-api/)
- [LINE Bot SDK for Ruby](https://github.com/line/line-bot-sdk-ruby)
- [Rails API ガイド](https://guides.rubyonrails.org/api_app.html)

この設計により、LINE Bot の機能拡張と保守が大幅に改善され、長期的な開発効率の向上が期待できます。
