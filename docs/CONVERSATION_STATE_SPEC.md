# 会話状態管理仕様書

LINE Botのマルチステップ対話における会話状態管理システムの詳細仕様です。

## 🎯 概要

LINE Botの複数ステップにわたる対話処理において、ユーザーの入力状態を管理し、適切な処理を実行するための状態管理システムです。

## 🔄 状態管理の仕組み

### 基本概念
- **会話状態**: ユーザーが現在どの段階にいるかを示す状態
- **状態データ**: その状態で必要な情報を保存するデータ
- **有効期限**: 状態の有効期限（自動削除）
- **コマンド割り込み**: 会話中に新しいコマンドが入力された場合の処理

### 状態の種類
```
認証フロー:
waiting_for_employee_name → waiting_for_verification_code → 完了

シフト交代フロー:
waiting_for_shift_exchange_date → waiting_for_shift_exchange_selection → waiting_for_shift_exchange_employee → 完了

シフト追加フロー:
waiting_for_shift_addition_date → waiting_for_shift_addition_time → waiting_for_shift_addition_employee → 完了

欠勤申請フロー:
waiting_for_shift_deletion_date → waiting_for_shift_deletion_selection → waiting_deletion_reason → 完了
```

## 🗄️ データベース設計

### ConversationState テーブル
```sql
CREATE TABLE conversation_states (
  id BIGINT PRIMARY KEY,
  line_user_id VARCHAR(255) NOT NULL,
  state VARCHAR(255) NOT NULL,
  state_data TEXT,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
```

### フィールド説明
- **line_user_id**: LINEユーザーID（一意）
- **state**: 現在の会話状態
- **state_data**: 状態に関連するデータ（JSON形式）
- **expires_at**: 状態の有効期限
- **created_at**: 作成日時
- **updated_at**: 更新日時

## 📊 状態一覧

### 認証関連状態
| 状態 | 説明 | 次の状態 |
|------|------|----------|
| `waiting_for_employee_name` | 従業員名入力待ち | `waiting_for_verification_code` |
| `waiting_for_verification_code` | 認証コード入力待ち | 完了 |

### シフト交代関連状態
| 状態 | 説明 | 次の状態 |
|------|------|----------|
| `waiting_for_shift_exchange_date` | 交代日付入力待ち | `waiting_for_shift_exchange_selection` |
| `waiting_for_shift_exchange_selection` | シフト選択待ち | `waiting_for_shift_exchange_employee` |
| `waiting_for_shift_exchange_employee` | 交代先従業員入力待ち | 完了 |

### シフト追加関連状態
| 状態 | 説明 | 次の状態 |
|------|------|----------|
| `waiting_for_shift_addition_date` | 追加日付入力待ち | `waiting_for_shift_addition_time` |
| `waiting_for_shift_addition_time` | 追加時間入力待ち | `waiting_for_shift_addition_employee` |
| `waiting_for_shift_addition_employee` | 対象従業員入力待ち | 完了 |

### 欠勤申請関連状態
| 状態 | 説明 | 次の状態 |
|------|------|----------|
| `waiting_for_shift_deletion_date` | 欠勤日付入力待ち | `waiting_for_shift_deletion_selection` |
| `waiting_for_shift_deletion_selection` | 欠勤シフト選択待ち | `waiting_deletion_reason` |
| `waiting_deletion_reason` | 欠勤理由入力待ち | 完了 |

## 🔧 実装仕様

### 状態の設定
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

### 状態の取得
```ruby
def get_conversation_state(line_user_id)
  state = ConversationState.find_active_state(line_user_id)
  return nil unless state

  {
    state: state.state,
    state_data: JSON.parse(state.state_data || '{}')
  }
end
```

### 状態のクリア
```ruby
def clear_conversation_state(line_user_id)
  ConversationState.where(line_user_id: line_user_id).delete_all
end
```

### 有効期限チェック
```ruby
def find_active_state(line_user_id)
  ConversationState.where(
    line_user_id: line_user_id,
    expires_at: Time.current..Float::INFINITY
  ).first
end
```

## 📝 状態データの構造

### 認証フロー
```json
{
  "state": "waiting_for_verification_code",
  "state_data": {
    "employee_id": "tanaka_taro",
    "verification_code": "123456"
  }
}
```

### シフト交代フロー
```json
{
  "state": "waiting_for_shift_exchange_employee",
  "state_data": {
    "selected_date": "2024-12-25",
    "selected_shift_id": "123"
  }
}
```

### シフト追加フロー
```json
{
  "state": "waiting_for_shift_addition_employee",
  "state_data": {
    "selected_date": "2024-12-25",
    "start_time": "09:00",
    "end_time": "17:00"
  }
}
```

### 欠勤申請フロー
```json
{
  "state": "waiting_deletion_reason",
  "state_data": {
    "selected_date": "2024-12-25",
    "selected_shift_id": "123"
  }
}
```

## 🔄 コマンド割り込み処理

### 割り込みの検出
```ruby
def command_message?(message_text)
  known_commands = [
    "ヘルプ", "認証", "シフト確認", "全員シフト確認",
    "交代依頼", "追加依頼", "欠勤申請", "依頼確認"
  ]
  known_commands.include?(message_text)
end
```

### 割り込み時の処理
```ruby
def handle_stateful_message(line_user_id, message_text)
  # コマンドが入力された場合、現在の状態をクリア
  if command_message?(message_text)
    clear_conversation_state(line_user_id)
    return nil  # LineBotServiceで新しいコマンドとして処理
  end

  # 通常の状態処理
  handle_current_state(line_user_id, message_text)
end
```

## ⏰ 有効期限管理

### 有効期限の設定
- **認証フロー**: 30分
- **シフト管理フロー**: 1時間
- **自動削除**: 期限切れの状態は自動削除

### 期限切れ処理
```ruby
def cleanup_expired_states
  ConversationState.where(
    expires_at: ..Time.current
  ).delete_all
end
```

## 🔍 状態遷移の検証

### 有効な遷移
```
認証:
開始 → waiting_for_employee_name → waiting_for_verification_code → 完了

シフト交代:
開始 → waiting_for_shift_exchange_date → waiting_for_shift_exchange_selection → waiting_for_shift_exchange_employee → 完了

シフト追加:
開始 → waiting_for_shift_addition_date → waiting_for_shift_addition_time → waiting_for_shift_addition_employee → 完了

欠勤申請:
開始 → waiting_for_shift_deletion_date → waiting_for_shift_deletion_selection → waiting_deletion_reason → 完了
```

### 無効な遷移
- 認証フローからシフト管理フローへの直接遷移
- 状態をスキップした遷移
- 存在しない状態への遷移

## 🛡️ エラーハンドリング

### 状態エラー
| エラー | 原因 | 対応 |
|--------|------|------|
| 状態が見つからない | 期限切れまたは未設定 | 初期状態に戻る |
| 無効な状態 | 不正な状態値 | エラーメッセージ表示 |
| 状態データ破損 | JSON解析エラー | 状態をクリアして再開始 |

### データ整合性
```ruby
def validate_state_data(state, state_data)
  case state
  when 'waiting_for_verification_code'
    state_data['employee_id'].present?
  when 'waiting_for_shift_exchange_employee'
    state_data['selected_shift_id'].present?
  else
    true
  end
end
```

## 🧪 テスト仕様

### 単体テスト
- 状態の設定・取得テスト
- 有効期限チェックテスト
- 状態データの検証テスト
- コマンド割り込みテスト

### 統合テスト
- 認証フロー全体テスト
- シフト交代フロー全体テスト
- シフト追加フロー全体テスト
- 欠勤申請フロー全体テスト

### テストケース
1. **正常フロー**: 各状態の正常な遷移
2. **期限切れ**: 有効期限切れの処理
3. **コマンド割り込み**: 会話中のコマンド入力
4. **データ破損**: 不正な状態データの処理
5. **並行処理**: 複数ユーザーの同時処理

## 📊 監視・ログ

### ログ出力
- 状態設定ログ
- 状態遷移ログ
- 期限切れログ
- エラーログ

### 監視項目
- 状態の平均保持時間
- 期限切れの発生率
- コマンド割り込みの発生率
- エラー発生率

## 🚀 今後の拡張予定

### 機能拡張
- 状態の履歴管理
- 状態の復元機能
- 状態の共有機能
- 状態の統計機能

### パフォーマンス改善
- 状態のキャッシュ機能
- バッチ処理での期限切れ削除
- 状態の圧縮機能

---

**最終更新日**: 2024年12月
**バージョン**: 1.0.0
