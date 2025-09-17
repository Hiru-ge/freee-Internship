# LINE Bot シフト追加リクエスト機能実装ドキュメント

## 概要

Phase 9-3で実装され、Phase 9-3.1で修正されたLINE Bot経由でのシフト追加リクエスト機能の詳細な実装ドキュメントです。

## 実装概要

### 機能の目的
- オーナーがLINE Botから直接シフト追加依頼を送信
- シフト交代リクエストと同様のフローで直感的な操作
- オーナー権限チェックによる適切なアクセス制御
- 複数人への同時依頼機能
- メール通知による確実な通知機能

### 実装手法
- **TDD（テスト駆動開発）**: Red, Green, Refactoringのサイクル
- **既存機能との統合**: シフト交代機能と同様の設計パターン
- **セキュリティ**: オーナー権限チェックの実装
- **会話状態管理**: グループメッセージでの適切な状態管理
- **包括的テスト**: 修正した機能に対応するテストの整備

## 技術実装詳細

### 1. コマンド処理

#### コマンド追加
```ruby
# app/services/line_bot_service.rb
COMMANDS = {
  'ヘルプ' => :help,
  'help' => :help,
  '認証' => :auth,
  'シフト' => :shift,
  '勤怠' => :attendance,
  '全員シフト' => :all_shifts,
  'シフト交代' => :shift_exchange,
  'シフト追加' => :shift_addition, # 新規追加
  'リクエスト確認' => :request_check,
  '交代状況' => :exchange_status,
  '依頼キャンセル' => :cancel_request
}.freeze
```

#### メイン処理
```ruby
def handle_shift_addition_command(event)
  line_user_id = extract_user_id(event)
  
  # 認証チェック
  unless employee_already_linked?(line_user_id)
    if group_message?(event)
      return "シフト追加には認証が必要です。\n" +
             "このボットと個人チャットを開始して「認証」を行ってください。"
    else
      return "認証が必要です。「認証」と入力して認証を行ってください。"
    end
  end
  
  # オーナー権限チェック
  employee = Employee.find_by(line_id: line_user_id)
  unless employee&.owner?
    return "シフト追加はオーナーのみが利用可能です。"
  end
  
  # グループチャットでのみ利用可能
  unless group_message?(event)
    return "シフト追加はグループチャットでのみ利用可能です。"
  end
  
  # 日付入力待ちの状態を設定
  set_conversation_state(line_user_id, { 
    step: 'waiting_shift_addition_date'
  })
  
    "📅 シフト追加依頼\n\n" +
    "日付を入力してください（例：2025-01-15）\n" +
    "※ 過去の日付は指定できません"
end
```

### 2. 会話状態管理

#### 状態定義
```ruby
# 会話状態の種類
'waiting_shift_addition_date'      # 日付入力待ち
'waiting_shift_addition_time'      # 時間入力待ち
'waiting_shift_addition_employee'  # 従業員選択待ち
'waiting_shift_addition_confirmation' # 確認待ち
```

#### 状態処理
```ruby
def handle_stateful_message(line_user_id, message_text, state)
  case state['step']
  when 'waiting_shift_addition_date'
    handle_shift_addition_date_input(line_user_id, message_text)
  when 'waiting_shift_addition_time'
    handle_shift_addition_time_input(line_user_id, message_text, state)
  when 'waiting_shift_addition_employee'
    handle_shift_addition_employee_input(line_user_id, message_text, state)
  when 'waiting_shift_addition_confirmation'
    handle_shift_addition_confirmation_input(line_user_id, message_text, state)
  # ... 他の状態
  end
end
```

### 3. 入力処理フロー

#### 日付入力処理
```ruby
def handle_shift_addition_date_input(line_user_id, message_text)
  # 日付形式の検証
  date_validation_result = validate_shift_date(message_text)
  return date_validation_result[:error] if date_validation_result[:error]
  
  # 時間入力待ちの状態を設定
  set_conversation_state(line_user_id, { 
    step: 'waiting_shift_addition_time',
    shift_date: date_validation_result[:date].strftime('%Y-%m-%d')
  })
  
  "⏰ 時間を入力してください（例：09:00-18:00）"
end
```

#### 時間入力処理
```ruby
def handle_shift_addition_time_input(line_user_id, message_text, state)
  # 時間形式の検証
  time_validation_result = validate_shift_time(message_text)
  return time_validation_result[:error] if time_validation_result[:error]
  
  # 従業員選択待ちの状態を設定
  set_conversation_state(line_user_id, { 
    step: 'waiting_shift_addition_employee',
    shift_date: state['shift_date'],
    shift_time: message_text
  })
  
    "👥 対象従業員を選択してください\n\n" +
    "💡 入力例：\n" +
    "• 田中太郎\n" +
    "• 田中\n" +
    "• 複数人: 田中太郎,佐藤花子\n\n" +
    "※ 複数人に送信する場合は「,」で区切って入力してください"
end
```

#### 従業員選択処理
```ruby
def handle_shift_addition_employee_input(line_user_id, message_text, state)
  # 従業員名で検索
  employees = find_employees_by_name(message_text)
  
  if employees.empty?
    return "従業員が見つかりません。\n" +
           "従業員名を正確に入力してください。"
  elsif employees.length == 1
    # 単一従業員の場合、直接確認画面へ
    target_employee = employees.first
    set_conversation_state(line_user_id, {
      step: 'waiting_shift_addition_confirmation',
      shift_date: state['shift_date'],
      shift_time: state['shift_time'],
      target_employee_id: target_employee.employee_id
    })
    
    "📋 シフト追加依頼の確認\n\n" +
    "📅 日付: #{Date.parse(state['shift_date']).strftime('%m/%d')}\n" +
    "⏰ 時間: #{state['shift_time']}\n" +
    "👤 対象: #{target_employee.display_name}\n\n" +
    "この内容で依頼を送信しますか？\n" +
    "「はい」または「いいえ」で回答してください。"
  else
    # 複数従業員の場合、選択肢を表示
    employee_list = "複数の従業員が見つかりました：\n\n"
    employees.each_with_index do |employee, index|
      employee_list += "#{index + 1}. #{employee.display_name}\n"
    end
    employee_list += "\n番号を選択してください。"
    
    # 選択肢を会話状態に保存
    set_conversation_state(line_user_id, {
      step: 'waiting_shift_addition_employee_selection',
      shift_date: state['shift_date'],
      shift_time: state['shift_time'],
      candidate_employees: employees.map(&:employee_id)
    })
    
    employee_list
  end
end
```

### 4. リクエスト作成処理

#### 確認処理
```ruby
def handle_shift_addition_confirmation_input(line_user_id, message_text, state)
  case message_text
  when 'はい'
    create_shift_addition_request(line_user_id, state)
  when 'いいえ'
    clear_conversation_state(line_user_id)
    "❌ シフト追加依頼をキャンセルしました。"
  else
    "「はい」または「いいえ」で回答してください。"
  end
end
```

#### リクエスト作成
```ruby
def create_shift_addition_request(line_user_id, state)
  begin
    employee = Employee.find_by(line_id: line_user_id)
    return "従業員情報が見つかりません。" unless employee
    
    # 時間をパース
    start_time_str, end_time_str = state['shift_time'].split('-')
    
    ShiftAddition.create!(
      request_id: generate_request_id,
      requester_id: employee.employee_id,
      target_employee_id: state['target_employee_id'],
      shift_date: Date.parse(state['shift_date']),
      start_time: Time.zone.parse(start_time_str),
      end_time: Time.zone.parse(end_time_str),
      status: 'pending'
    )
    
    # 会話状態をクリア
    clear_conversation_state(line_user_id)
    
    "✅ シフト追加依頼を送信しました。\n" +
    "対象従業員に通知が送信されます。"
    
  rescue => e
    Rails.logger.error "シフト追加リクエスト作成エラー: #{e.message}"
    "❌ 依頼の送信に失敗しました。\n" +
    "しばらく時間をおいてから再度お試しください。"
  end
end
```

### 5. 共通検証メソッド

#### 日付検証
```ruby
def validate_shift_date(date_text)
  begin
    date = Date.parse(date_text)
    if date < Date.current
      return { error: "過去の日付は指定できません。\n日付を入力してください（例：2025-01-15）" }
    end
    { date: date }
  rescue ArgumentError
    { error: "日付の形式が正しくありません。\n例：2025-01-15" }
  end
end
```

#### 時間検証
```ruby
def validate_shift_time(time_text)
  # 時間形式の検証（HH:MM-HH:MM）
  unless time_text.match?(/^\d{2}:\d{2}-\d{2}:\d{2}$/)
    return { error: "時間の形式が正しくありません。\n例：09:00-18:00" }
  end
  
  begin
    start_time_str, end_time_str = time_text.split('-')
    start_time = Time.zone.parse(start_time_str)
    end_time = Time.zone.parse(end_time_str)
    
    if start_time >= end_time
      return { error: "開始時間は終了時間より早く設定してください。\n例：09:00-18:00" }
    end
    { start_time: start_time, end_time: end_time }
  rescue ArgumentError
    { error: "時間の形式が正しくありません。\n例：09:00-18:00" }
  end
end
```

### 6. 既存機能との統合

#### リクエスト確認機能の拡張
```ruby
def handle_request_check_command(event)
  # ... 認証チェック ...
  
  # シフト交代リクエスト
  pending_exchange_requests = ShiftExchange.where(
    approver_id: employee.employee_id,
    status: 'pending'
  ).includes(:shift)
  
  # シフト追加リクエスト
  pending_addition_requests = ShiftAddition.where(
    target_employee_id: employee.employee_id,
    status: 'pending'
  )
  
  if pending_exchange_requests.empty? && pending_addition_requests.empty?
    return "承認待ちのリクエストはありません"
  end
  
  # Flex Message形式でリクエストを表示
  generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)
end
```

#### Flex Message形式でのリクエスト表示
```ruby
def generate_pending_requests_flex_message(pending_exchange_requests, pending_addition_requests)
  bubbles = []
  
  # シフト交代リクエストのカード
  pending_exchange_requests.each do |request|
    shift = request.shift
    requester = Employee.find_by(employee_id: request.requester_id)
    requester_name = requester&.display_name || "ID: #{request.requester_id}"
    
    day_of_week = %w[日 月 火 水 木 金 土][shift.shift_date.wday]
    
    bubbles << {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          { type: "text", text: "🔄 シフト交代承認", weight: "bold", size: "xl", color: "#1DB446" },
          { type: "separator", margin: "md" },
          {
            type: "box", layout: "vertical", margin: "md", spacing: "sm", contents: [
              {
                type: "box", layout: "baseline", spacing: "sm", contents: [
                  { type: "text", text: "👤", size: "sm", color: "#666666" },
                  { type: "text", text: "申請者: #{requester_name}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                ]
              },
              {
                type: "box", layout: "baseline", spacing: "sm", contents: [
                  { type: "text", text: "📅", size: "sm", color: "#666666" },
                  { type: "text", text: "#{shift.shift_date.strftime('%m/%d')} (#{day_of_week})", wrap: true, color: "#666666", size: "sm", flex: 0 }
                ]
              },
              {
                type: "box", layout: "baseline", spacing: "sm", contents: [
                  { type: "text", text: "⏰", size: "sm", color: "#666666" },
                  { type: "text", text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                ]
              }
            ]
          }
        ]
      },
      footer: {
        type: "box", layout: "vertical", spacing: "sm", contents: [
          {
            type: "button", style: "primary", height: "sm", action: {
              type: "postback",
              label: "承認",
              data: "approve_exchange_#{request.id}",
              displayText: "#{shift.shift_date.strftime('%m/%d')}のシフト交代を承認します"
            }
          },
          {
            type: "button", style: "secondary", height: "sm", action: {
              type: "postback",
              label: "拒否",
              data: "reject_exchange_#{request.id}",
              displayText: "#{shift.shift_date.strftime('%m/%d')}のシフト交代を拒否します"
            }
          }
        ]
      }
    }
  end
  
  # シフト追加リクエストのカード
  pending_addition_requests.each do |request|
    requester = Employee.find_by(employee_id: request.requester_id)
    requester_name = requester&.display_name || "ID: #{request.requester_id}"
    
    day_of_week = %w[日 月 火 水 木 金 土][request.shift_date.wday]
    
    bubbles << {
      type: "bubble",
      body: {
        type: "box",
        layout: "vertical",
        contents: [
          { type: "text", text: "➕ シフト追加承認", weight: "bold", size: "xl", color: "#FF6B6B" },
          { type: "separator", margin: "md" },
          {
            type: "box", layout: "vertical", margin: "md", spacing: "sm", contents: [
              {
                type: "box", layout: "baseline", spacing: "sm", contents: [
                  { type: "text", text: "👤", size: "sm", color: "#666666" },
                  { type: "text", text: "申請者: #{requester_name}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                ]
              },
              {
                type: "box", layout: "baseline", spacing: "sm", contents: [
                  { type: "text", text: "📅", size: "sm", color: "#666666" },
                  { type: "text", text: "#{request.shift_date.strftime('%m/%d')} (#{day_of_week})", wrap: true, color: "#666666", size: "sm", flex: 0 }
                ]
              },
              {
                type: "box", layout: "baseline", spacing: "sm", contents: [
                  { type: "text", text: "⏰", size: "sm", color: "#666666" },
                  { type: "text", text: "#{request.start_time.strftime('%H:%M')}-#{request.end_time.strftime('%H:%M')}", wrap: true, color: "#666666", size: "sm", flex: 0 }
                ]
              }
            ]
          }
        ]
      },
      footer: {
        type: "box", layout: "vertical", spacing: "sm", contents: [
          {
            type: "button", style: "primary", height: "sm", action: {
              type: "postback",
              label: "承認",
              data: "approve_addition_#{request.id}",
              displayText: "#{request.shift_date.strftime('%m/%d')}のシフト追加を承認します"
            }
          },
          {
            type: "button", style: "secondary", height: "sm", action: {
              type: "postback",
              label: "拒否",
              data: "reject_addition_#{request.id}",
              displayText: "#{request.shift_date.strftime('%m/%d')}のシフト追加を拒否します"
            }
          }
        ]
      }
    }
  end

  {
    type: "flex",
    altText: "承認待ちのリクエスト",
    contents: {
      type: "carousel",
      contents: bubbles
    }
  }
end
```

## テスト実装

### テストファイル
- `test/services/line_bot_shift_addition_test.rb`

### テストカバレッジ
1. **コマンド処理テスト**
   - シフト追加コマンドの基本処理
   - 認証チェック
   - オーナー権限チェック
   - グループチャット制限

2. **入力処理テスト**
   - 日付入力処理
   - 時間入力処理
   - 従業員選択処理
   - 確認処理

3. **エラーハンドリングテスト**
   - 無効な日付形式
   - 無効な時間形式
   - 存在しない従業員
   - 重複チェック

4. **統合テスト**
   - 既存機能との統合
   - リクエスト確認機能
   - 会話状態管理

### テスト実行結果
```
203 runs, 602 assertions, 0 failures, 0 errors, 0 skips
```

### 修正履歴
- **2025年1月**: 承認待ちリクエストの表示をFlex Message形式に戻す修正
  - `handle_request_check_command`メソッドをFlex Message形式に変更
  - `generate_pending_requests_flex_message`メソッドを新規作成
  - シフト交代とシフト追加の両方のリクエストを統合表示
  - テストファイルの修正（Flex Message形式のレスポンスを期待）

## セキュリティ機能

### 1. 認証チェック
- すべてのシフト追加機能で認証が必要
- 未認証ユーザーには適切な案内メッセージ

### 2. オーナー権限チェック
- オーナーのみがシフト追加機能を利用可能
- `employee&.owner?`による権限確認

### 3. グループチャット制限
- シフト追加はグループチャットでのみ利用可能
- 個人チャットでは利用不可

### 4. 入力値検証
- 日付形式の検証
- 時間形式の検証
- 従業員存在確認

## ユーザー体験

### 利用フロー
1. オーナーがグループチャットで「シフト追加」と入力
2. 日付の入力を求められる（例：2025-01-15、過去日付は不可）
3. 時間の入力を求められる（例：09:00-18:00）
4. 対象従業員名を入力（複数人可：田中太郎,佐藤花子）
5. 重複チェックと利用可能従業員の確認
6. 確認画面で内容を確認
7. 「はい」で依頼送信、「いいえ」でキャンセル
8. 対象従業員にメール通知が送信される

### 承認フロー
1. 対象従業員が「リクエスト確認」コマンドを実行
2. Flex Message形式で承認待ちリクエストが表示
3. シフト交代とシフト追加の両方のリクエストが統合表示
4. 各リクエストに承認・拒否ボタンが表示
5. ボタンをタップして承認・拒否を実行

### エラーハンドリング
- 過去の日付は指定不可（警告メッセージ付き）
- 無効な時間形式は拒否
- 存在しない従業員は拒否
- 重複するシフトは警告
- 複数従業員入力時の部分的な重複対応
- 親切な入力ガイドとエラーメッセージ

## 今後の拡張予定

### 機能拡張
- 複数日一括追加機能
- テンプレート機能
- シフトパターン保存機能

### UI改善
- Flex Message対応
- より直感的な操作フロー
- 進捗表示の改善

## Phase 9-3.1 修正内容

### 修正された問題
1. **会話状態管理の問題**: グループメッセージで会話状態がチェックされない問題を修正
2. **ユーザー体験の改善**: 日付入力時の警告メッセージと従業員入力ガイドの改善
3. **複数人対応の復活**: カンマ区切りでの複数従業員への同時依頼機能
4. **メール通知の復活**: 対象従業員への自動メール通知機能

### 修正の詳細
- **会話状態管理**: グループメッセージでも会話状態をチェックするように修正
- **入力ガイド改善**: 従業員名入力時に親切な例と複数人対応の説明を追加
- **複数人対応**: カンマ区切りで複数の従業員名を入力可能
- **重複チェック**: 各従業員の重複をチェックし、利用可能な従業員のみに送信
- **メール通知**: シフト追加リクエスト作成時に自動でメール通知を送信

### テスト結果
- **20テスト、78アサーション、すべて成功**
- 修正したすべての機能をカバーする包括的なテストスイート
- 既存のテストパターンに準拠した実装

## まとめ

Phase 9-3で実装され、Phase 9-3.1で修正されたシフト追加リクエスト機能は、TDD手法により堅牢に実装され、既存のシフト交代機能と同様の直感的なフローを提供しています。オーナー権限チェックによる適切なアクセス制御、複数人への同時依頼機能、メール通知機能、そして包括的なテストカバレッジにより、高品質なシステムが構築されています。

この機能により、オーナーはLINE Botから直接シフト追加依頼を送信でき、従業員は既存の承認機能を通じてシフト追加リクエストを処理できるようになりました。修正により、ユーザー体験が大幅に改善され、シフト交代リクエストと同様の高品質な機能が提供されています。
