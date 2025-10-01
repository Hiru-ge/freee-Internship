# frozen_string_literal: true

# アプリケーション定数定義
module AppConstants
  # セッション関連
  SESSION_TIMEOUT_HOURS = 24
  EMAIL_AUTH_TIMEOUT_HOURS = 24

  # 認証関連
  VERIFICATION_CODE_LENGTH = 6
  VERIFICATION_CODE_EXPIRY_MINUTES = 5

  # 会話状態関連
  CONVERSATION_STATE_TIMEOUT_HOURS = 24

  # シフト関連
  MAX_SHIFT_DURATION_HOURS = 24

  # メッセージ関連
  MAX_MESSAGE_LENGTH = 2000

  # 従業員名関連
  MAX_EMPLOYEE_NAME_LENGTH = 20

  # リクエストID関連
  REQUEST_ID_PATTERN = /^[A-Z_]+_\d{8}_\d{6}_[a-f0-9]{8}$/

  # 認証コードパターン
  VERIFICATION_CODE_PATTERN = /^\d{6}$/

  # 数値選択関連
  MIN_SELECTION_NUMBER = 1

  # 確認入力関連
  CONFIRMATION_YES = %w[はい yes y ok 承認].freeze
  CONFIRMATION_NO = %w[いいえ no n キャンセル 否認].freeze
end
