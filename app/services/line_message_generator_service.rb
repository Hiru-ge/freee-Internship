# frozen_string_literal: true

class LineMessageGeneratorService
  # 複数従業員マッチ時のメッセージ生成
  def self.generate_multiple_employee_selection_message(employee_name, matches)
    message = "「#{employee_name}」に該当する従業員が複数見つかりました。\n\n"
    message += "該当する従業員の番号を入力してください:\n\n"
    
    matches.each_with_index do |employee, index|
      display_name = employee[:display_name] || employee['display_name']
      employee_id = employee[:id] || employee['id']
      message += "#{index + 1}. #{display_name} (ID: #{employee_id})\n"
    end
    
    message += "\n番号を入力してください:"
    message
  end

  # 従業員が見つからない場合のメッセージ生成
  def self.generate_employee_not_found_message(employee_name)
    "「#{employee_name}」に該当する従業員が見つかりませんでした。\n\nフルネームでも部分入力でも検索できます。\n再度従業員名を入力してください:"
  end

  # エラーメッセージ生成
  def self.generate_error_message(error_type, context = {})
    case error_type
    when :invalid_date
      "正しい日付形式で入力してください。\n例: 2024-01-15"
    when :invalid_time
      "正しい時間形式で入力してください。\n例: 9:00-17:00"
    when :invalid_employee_name
      "従業員名を正しく入力してください。\nフルネームでも部分入力でも検索できます。"
    when :invalid_number
      "正しい番号を入力してください。"
    when :shift_not_found
      "指定されたシフトが見つかりませんでした。"
    when :permission_denied
      "この操作を実行する権限がありません。"
    when :system_error
      "システムエラーが発生しました。しばらく時間をおいて再度お試しください。"
    else
      "エラーが発生しました。入力内容を確認してください。"
    end
  end

  # 成功メッセージ生成
  def self.generate_success_message(action_type, context = {})
    case action_type
    when :authentication_completed
      "認証が完了しました！\n\n以下の機能が利用可能になりました:\n・シフト確認\n・全員シフト確認\n・交代依頼\n・追加依頼\n・依頼確認"
    when :shift_exchange_request_created
      "シフト交代依頼を作成しました。\n承認をお待ちください。"
    when :shift_addition_request_created
      "シフト追加依頼を作成しました。\n承認をお待ちください。"
    when :request_approved
      "依頼が承認されました。"
    when :request_rejected
      "依頼が拒否されました。"
    else
      "操作が完了しました。"
    end
  end

  # 確認メッセージ生成
  def self.generate_confirmation_message(action_type, context = {})
    case action_type
    when :shift_exchange
      "以下の内容でシフト交代依頼を作成しますか？\n\n" \
      "日付: #{context[:date]}\n" \
      "時間: #{context[:time]}\n" \
      "依頼先: #{context[:target_employee]}\n\n" \
      "「はい」または「いいえ」で回答してください。"
    when :shift_addition
      "以下の内容でシフト追加依頼を作成しますか？\n\n" \
      "日付: #{context[:date]}\n" \
      "時間: #{context[:time]}\n" \
      "従業員: #{context[:employee]}\n\n" \
      "「はい」または「いいえ」で回答してください。"
    else
      "この操作を実行しますか？\n「はい」または「いいえ」で回答してください。"
    end
  end

  # ヘルプメッセージ生成
  def self.generate_help_message
    "利用可能なコマンド:\n\n" \
    "・ヘルプ - このメッセージを表示\n" \
    "・認証 - 従業員名入力による認証（個人チャットのみ）\n" \
    "・シフト確認 - 個人のシフト情報を確認\n" \
    "・全員シフト確認 - 全従業員のシフト情報を確認\n" \
    "・交代依頼 - シフト交代依頼\n" \
    "・追加依頼 - シフト追加依頼（オーナーのみ）\n" \
    "・依頼確認 - 承認待ちの依頼を確認\n\n" \
    "コマンドを入力してください。"
  end

  # 認証開始メッセージ生成
  def self.generate_auth_start_message
    "認証を開始します。\n\n従業員名を入力してください。\nフルネームでも部分入力でも検索できます。"
  end

  # 認証コード入力メッセージ生成
  def self.generate_auth_code_input_message(employee_name)
    "「#{employee_name}」で認証を開始します。\n\n認証コードを入力してください:"
  end

  # 認証失敗メッセージ生成
  def self.generate_auth_failed_message
    "認証に失敗しました。\n\n従業員名を再度入力してください。\nフルネームでも部分入力でも検索できます。"
  end
end
