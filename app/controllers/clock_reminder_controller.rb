class ClockReminderController < ApplicationController
  # 認証をスキップ（GitHub Actionsからの呼び出し用）
  skip_before_action :require_login
  skip_before_action :verify_authenticity_token
  
  def trigger
    # 認証なし（無害な処理のため）
    Rails.logger.info "Clock reminder check triggered via HTTP API"
    
    begin
      # バックグラウンドでRakeタスクを実行
      
      # 直接サービスを呼び出し
      ClockReminderService.new.check_forgotten_clock_ins
      ClockReminderService.new.check_forgotten_clock_outs
      
      render json: { 
        status: 'success', 
        message: 'Clock reminder check completed',
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "Clock reminder check failed: #{e.message}"
      render json: { 
        status: 'error', 
        message: e.message,
        timestamp: Time.current
      }, status: :internal_server_error
    end
  end
end
