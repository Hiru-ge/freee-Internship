require 'test_helper'

class ErrorHandlerTest < ActiveSupport::TestCase
  # テスト用のダミーコントローラー
  class TestController
    include ErrorHandler
    
    attr_accessor :flash
    
    def initialize
      @flash = {}
    end
    
    def redirect_to(path)
      # テスト用のリダイレクト処理
    end
  end

  setup do
    @controller = TestController.new
  end

  test "should handle validation errors with user-friendly messages" do
    # バリデーションエラーのテスト
    @controller.send(:handle_validation_error, 'employee_id', '従業員IDを入力してください')
    
    assert_equal '従業員IDを入力してください', @controller.flash[:error]
  end

  test "should handle API errors with appropriate messages" do
    # APIエラーのテスト
    error = StandardError.new('Connection timeout')
    @controller.send(:handle_api_error, error, '従業員情報取得')
    
    assert_equal 'システムが混雑しています。しばらく時間をおいてから再度お試しください。', @controller.flash[:error]
  end

  test "should handle authorization errors with clear messages" do
    # 認証エラーのテスト
    @controller.send(:handle_authorization_error, 'このページにアクセスする権限がありません')
    
    assert_equal 'このページにアクセスする権限がありません', @controller.flash[:error]
  end

  test "should provide fallback error messages" do
    # フォールバックエラーメッセージのテスト
    @controller.send(:handle_unknown_error)
    
    assert_equal '予期しないエラーが発生しました。システム管理者にお問い合わせください。', @controller.flash[:error]
  end

  test "should handle success messages consistently" do
    # 成功メッセージの一貫性テスト
    @controller.send(:handle_success, 'ログインしました')
    
    assert_equal 'ログインしました', @controller.flash[:success]
  end

  test "should handle warning messages appropriately" do
    # 警告メッセージのテスト
    @controller.send(:handle_warning, 'パスワードの有効期限が近づいています')
    
    assert_equal 'パスワードの有効期限が近づいています', @controller.flash[:warning]
  end

  test "should handle info messages for user guidance" do
    # 情報メッセージのテスト
    @controller.send(:handle_info, '新しい機能が追加されました')
    
    assert_equal '新しい機能が追加されました', @controller.flash[:info]
  end
end