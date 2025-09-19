# Flex Message仕様書

LINE Botで使用するFlex Messageの詳細仕様です。

## 🎯 概要

LINE Botのシフト管理機能で使用するFlex Messageのデザイン仕様と実装詳細です。

## 🎨 デザインガイドライン

### カラーパレット
- **プライマリ**: #1DB446 (LINE Green)
- **セカンダリ**: #FF6B6B (Red for deletion)
- **テキスト**: #333333 (Dark Gray)
- **サブテキスト**: #666666 (Medium Gray)
- **背景**: #FFFFFF (White)
- **ボーダー**: #E0E0E0 (Light Gray)

### タイポグラフィ
- **タイトル**: 18px, Bold
- **サブタイトル**: 16px, Bold
- **本文**: 14px, Regular
- **キャプション**: 12px, Regular

### レイアウト
- **マージン**: 12px
- **パディング**: 16px
- **ボタン高さ**: 40px
- **セパレーター**: 1px

## 📋 シフト交代依頼カード

### 用途
シフト交代依頼時に表示されるシフト選択カード

### デザイン仕様
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

### 特徴
- **カラー**: LINE Green (#1DB446)
- **アイコン**: 📅 (日付), ⏰ (時間)
- **ボタン**: プライマリスタイル
- **Postback**: `shift_{shift_id}`

## ✅ 承認待ちリクエストカード

### 用途
承認待ちのシフト交代リクエストを表示するカード

### デザイン仕様
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

### 特徴
- **カラー**: LINE Green (#1DB446)
- **アイコン**: 👤 (申請者), 📅 (日付), ⏰ (時間)
- **ボタン**: 承認（プライマリ）、拒否（セカンダリ）
- **Postback**: `approve_{request_id}`, `reject_{request_id}`

## 🚫 欠勤申請シフト選択カード

### 用途
欠勤申請時に表示されるシフト選択カード

### デザイン仕様
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

### 特徴
- **カラー**: Red (#FF6B6B)
- **ヘッダー**: 赤背景に白文字
- **アイコン**: 🚫 (欠勤)
- **ボタン**: 赤色のプライマリスタイル
- **Postback**: `deletion_shift_{shift_id}`

## 📝 欠勤申請承認カード

### 用途
欠勤申請の承認・拒否用カード

### デザイン仕様
```json
{
  "type": "flex",
  "altText": "欠勤申請の承認",
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
              "text": "🚫 欠勤申請承認",
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
                },
                {
                  "type": "box",
                  "layout": "baseline",
                  "spacing": "sm",
                  "contents": [
                    {
                      "type": "text",
                      "text": "📝",
                      "size": "sm",
                      "color": "#666666"
                    },
                    {
                      "type": "text",
                      "text": "理由: 体調不良のため",
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
              "color": "#FF6B6B",
              "action": {
                "type": "postback",
                "label": "承認",
                "data": "approve_deletion_123",
                "displayText": "欠勤申請を承認します"
              }
            },
            {
              "type": "button",
              "style": "secondary",
              "height": "sm",
              "action": {
                "type": "postback",
                "label": "拒否",
                "data": "reject_deletion_123",
                "displayText": "欠勤申請を拒否します"
              }
            }
          ]
        }
      }
    ]
  }
}
```

### 特徴
- **カラー**: Red (#FF6B6B)
- **ヘッダー**: 赤背景に白文字
- **アイコン**: 👤 (申請者), 📅 (日付), ⏰ (時間), 📝 (理由)
- **ボタン**: 承認（赤色プライマリ）、拒否（セカンダリ）
- **Postback**: `approve_deletion_{request_id}`, `reject_deletion_{request_id}`

## 🔧 実装仕様

### 動的データ挿入
```ruby
def build_shift_card(shift, action_type)
  {
    "type": "bubble",
    "body": {
      "type": "box",
      "layout": "vertical",
      "contents": [
        {
          "type": "text",
          "text": format_date(shift.shift_date),
          "weight": "bold",
          "size": "lg"
        },
        {
          "type": "text",
          "text": format_time_range(shift.start_time, shift.end_time),
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
          "color": get_action_color(action_type),
          "action": {
            "type": "postback",
            "label": get_action_label(action_type),
            "data": get_postback_data(action_type, shift.id),
            "displayText": get_display_text(action_type, shift)
          }
        }
      ]
    }
  }
end
```

### カラーテーマ管理
```ruby
def get_action_color(action_type)
  case action_type
  when :exchange
    "#1DB446"  # LINE Green
  when :deletion
    "#FF6B6B"  # Red
  else
    "#1DB446"  # Default
  end
end
```

### Postbackデータ形式
```ruby
def get_postback_data(action_type, id)
  case action_type
  when :exchange
    "shift_#{id}"
  when :deletion
    "deletion_shift_#{id}"
  when :approve_exchange
    "approve_#{id}"
  when :reject_exchange
    "reject_#{id}"
  when :approve_deletion
    "approve_deletion_#{id}"
  when :reject_deletion
    "reject_deletion_#{id}"
  end
end
```

## 📱 レスポンシブ対応

### カードサイズ
- **最大幅**: 320px
- **最小幅**: 280px
- **高さ**: 自動調整

### テキスト折り返し
- **長いテキスト**: 自動折り返し
- **最大行数**: 3行
- **省略**: 3行を超える場合は省略記号

### ボタン配置
- **単一ボタン**: 全幅
- **複数ボタン**: 等幅配置
- **最大ボタン数**: 2個

## 🧪 テスト仕様

### 単体テスト
- Flex Message構造の検証
- 動的データ挿入のテスト
- Postbackデータの検証
- カラーテーマの確認

### 統合テスト
- LINE Botでの表示確認
- Postbackイベントの処理確認
- エラーハンドリングの確認

### テストケース
1. **正常表示**: 各カードの正常な表示
2. **データ挿入**: 動的データの正しい挿入
3. **Postback処理**: ボタンタップ時の正しい処理
4. **エラー処理**: 不正なデータでのエラーハンドリング

## 🚀 今後の拡張予定

### デザイン改善
- アニメーション効果の追加
- カスタムアイコンの使用
- ダークモード対応

### 機能拡張
- カードのカスタマイズ機能
- テンプレート機能
- 多言語対応

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
