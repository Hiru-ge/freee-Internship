# アプリケーション定数の初期化
# config/app_constants.ymlから設定を読み込み

require 'yaml'

# 設定ファイルのパス
CONFIG_FILE = Rails.root.join('config', 'app_constants.yml')

# 設定を読み込み
if File.exist?(CONFIG_FILE)
  APP_CONSTANTS = YAML.load_file(CONFIG_FILE).deep_symbolize_keys
else
  Rails.logger.warn "設定ファイルが見つかりません: #{CONFIG_FILE}"
  APP_CONSTANTS = {}
end

# 設定の検証
def validate_config!
  required_keys = [:wage, :employee, :auth, :email, :ui, :system]
  
  required_keys.each do |key|
    unless APP_CONSTANTS.key?(key)
      Rails.logger.error "必須の設定キーが見つかりません: #{key}"
    end
  end
end

# 開発環境でのみ設定を検証
if Rails.env.development?
  validate_config!
end

# 設定へのアクセス用ヘルパーメソッド
module AppConstants
  def self.wage
    APP_CONSTANTS[:wage] || {}
  end
  
  def self.employee
    APP_CONSTANTS[:employee] || {}
  end
  
  def self.auth
    APP_CONSTANTS[:auth] || {}
  end
  
  def self.email
    APP_CONSTANTS[:email] || {}
  end
  
  def self.ui
    APP_CONSTANTS[:ui] || {}
  end
  
  def self.system
    APP_CONSTANTS[:system] || {}
  end
  
  # 従業員名の取得
  def self.employee_name(employee_id)
    name_mapping = employee[:name_mapping] || {}
    # 文字列とシンボルの両方で検索
    name_mapping[employee_id.to_s] || name_mapping[employee_id.to_sym] || "ID: #{employee_id}"
  end
  
  # 時間帯別時給レートの取得
  def self.wage_rate(time_zone)
    rates = wage[:time_zone_rates] || {}
    rates[time_zone.to_sym] || {}
  end
  
  # 月間給与目標の取得
  def self.monthly_wage_target
    wage[:monthly_target] || 1_030_000
  end
end
