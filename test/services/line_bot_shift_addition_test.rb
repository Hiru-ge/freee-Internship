require "test_helper"

class LineBotShiftAdditionTest < ActiveSupport::TestCase
  def setup
    @line_bot_service = LineBotService.new
    @test_user_id = "test_user_id"
    @test_group_id = "test_group_id"
  end

  # シフト追加リクエストコマンドのテスト
  test "should handle shift addition command in group" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # グループメッセージイベント
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    event['message']['text'] = 'シフト追加'

    response = @line_bot_service.handle_message(event)

    # 日付入力の案内が表示されることを確認
    assert_includes response, "日付を入力してください"
    # 日付例を動的に生成（明日の日付）
    tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
    assert_includes response, "例：#{tomorrow}"

    # クリーンアップ
    owner.destroy
  end

  test "should handle shift addition command in individual chat" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 個人メッセージイベント
    event = mock_line_event(source_type: "user", user_id: @test_user_id)
    event['message']['text'] = 'シフト追加'

    response = @line_bot_service.handle_message(event)

    # グループチャットでのみ利用可能であることを確認
    assert_includes response, "グループチャットでのみ利用可能です"

    # クリーンアップ
    owner.destroy
  end

  test "should reject shift addition command from non-owner" do
    # 一般従業員を作成
    employee = Employee.create!(
      employee_id: "999",
      role: "employee",
      line_id: @test_user_id
    )

    # グループメッセージイベント
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    event['message']['text'] = 'シフト追加'

    response = @line_bot_service.handle_message(event)

    # オーナーのみが利用可能であることを確認
    assert_includes response, "オーナーのみが利用可能です"

    # クリーンアップ
    employee.destroy
  end

  test "should handle shift addition date input" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 日付入力待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_date'
    })

    # 未来の日付を入力
    future_date = (Date.current + 30).strftime('%Y-%m-%d')
    response = @line_bot_service.handle_message_with_state(@test_user_id, future_date)

    # 時間入力の案内が表示されることを確認
    assert_includes response, "時間を入力してください"
    assert_includes response, "例：09:00-18:00"

    # クリーンアップ
    owner.destroy
  end

  test "should handle shift addition time input" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 時間入力待ちの状態を設定
    future_date = (Date.current + 30).strftime('%Y-%m-%d')
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_time',
      shift_date: future_date
    })

    # 時間を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, '09:00-18:00')

    # 従業員選択の案内が表示されることを確認
    assert_includes response, "対象従業員を選択してください"

    # クリーンアップ
    owner.destroy
  end

  test "should handle shift addition employee selection" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成
    target_employee = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    # display_nameメソッドをグローバルにオーバーライド
    Employee.class_eval do
      def display_name
        case self.employee_id
        when "1000"
          "テスト 太郎"
        else
          "ID: #{self.employee_id}"
        end
      end
    end

    # テスト用にfind_employees_by_nameメソッドをオーバーライド
    @@test_target_employee = target_employee
    
    def @line_bot_service.find_employees_by_name(name)
      case name
      when "テスト 太郎"
        [@@test_target_employee]
      else
        []
      end
    end

    # 従業員選択待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: (Date.current + 30).strftime('%Y-%m-%d'),
      shift_time: '09:00-18:00'
    })

    # 従業員名を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'テスト 太郎')

    # 確認画面が表示されることを確認
    assert_includes response, "シフト追加依頼の確認"
    # 30日後の日付を動的に計算して確認
    expected_date = (Date.current + 30).strftime('%m/%d')
    assert_includes response, expected_date
    assert_includes response, "09:00-18:00"
    assert_includes response, "テスト 太郎"

    # クリーンアップ
    owner.destroy
    target_employee.destroy
  end

  test "should handle shift addition confirmation" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成
    target_employee = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    # 確認待ちの状態を設定
    future_date = (Date.current + 30).strftime('%Y-%m-%d')
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_confirmation',
      shift_date: future_date,
      shift_time: '09:00-18:00',
      target_employee_id: '1000'
    })

    # 確認して依頼を送信
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'はい')

    # 依頼が成功したことを確認
    assert_includes response, "シフト追加依頼を送信しました"

    # シフト追加リクエストが作成されたことを確認
    future_date = Date.current + 30
    shift_addition = ShiftAddition.find_by(
      requester_id: owner.employee_id,
      target_employee_id: target_employee.employee_id,
      shift_date: future_date
    )
    assert_not_nil shift_addition
    assert_equal 'pending', shift_addition.status

    # クリーンアップ
    shift_addition.destroy
    owner.destroy
    target_employee.destroy
  end

  test "should handle shift addition cancellation" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 確認待ちの状態を設定
    future_date = (Date.current + 30).strftime('%Y-%m-%d')
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_confirmation',
      shift_date: future_date,
      shift_time: '09:00-18:00',
      target_employee_id: '1000'
    })

    # キャンセル
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'いいえ')

    # キャンセルされたことを確認
    assert_includes response, "シフト追加依頼をキャンセルしました"

    # 会話状態がクリアされたことを確認
    state = @line_bot_service.get_conversation_state(@test_user_id)
    assert_nil state

    # クリーンアップ
    owner.destroy
  end

  test "should validate shift addition date format" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 日付入力待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_date'
    })

    # 無効な日付形式を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'invalid-date')

    # エラーメッセージが表示されることを確認
    assert_includes response, "日付の形式が正しくありません"
    # 日付例を動的に生成（明日の日付）
    tomorrow = (Date.current + 1).strftime('%Y-%m-%d')
    assert_includes response, "例：#{tomorrow}"

    # クリーンアップ
    owner.destroy
  end

  test "should validate shift addition time format" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 時間入力待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_time',
      shift_date: (Date.current + 1).strftime('%Y-%m-%d')
    })

    # 無効な時間形式を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'invalid-time')

    # エラーメッセージが表示されることを確認
    assert_includes response, "時間の形式が正しくありません"
    assert_includes response, "例：09:00-18:00"

    # クリーンアップ
    owner.destroy
  end

  test "should handle shift addition employee not found" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # テスト用にfind_employees_by_nameメソッドをオーバーライド
    def @line_bot_service.find_employees_by_name(name)
      []
    end

    # 従業員選択待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: (Date.current + 30).strftime('%Y-%m-%d'),
      shift_time: '09:00-18:00'
    })

    # 存在しない従業員名を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, '存在しない従業員')

    # エラーメッセージが表示されることを確認
    assert_includes response, "従業員が見つかりません"

    # クリーンアップ
    owner.destroy
  end

  test "should handle shift addition overlap check" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成
    target_employee = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    # 既存のシフトを作成（重複する時間）
    future_date = Date.current + 30
    existing_shift = Shift.create!(
      employee_id: target_employee.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('16:00')
    )

    # display_nameメソッドをグローバルにオーバーライド
    Employee.class_eval do
      def display_name
        case self.employee_id
        when "1000"
          "テスト 太郎"
        else
          "ID: #{self.employee_id}"
        end
      end
    end

    # テスト用にfind_employees_by_nameメソッドをオーバーライド
    @@test_target_employee = target_employee
    
    def @line_bot_service.find_employees_by_name(name)
      case name
      when "テスト 太郎"
        [@@test_target_employee]
      else
        []
      end
    end

    # 従業員選択待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: future_date.strftime('%Y-%m-%d'),
      shift_time: '09:00-18:00'
    })

    # 従業員名を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'テスト 太郎')

    # 重複エラーメッセージが表示されることを確認
    assert_includes response, "指定された時間にシフトが入っています"

    # クリーンアップ
    existing_shift.destroy
    owner.destroy
    target_employee.destroy
  end

  test "should show pending addition requests in flex message format" do
    # オーナーと対象従業員を作成
    owner = Employee.create!(
      employee_id: "owner_001",
      role: "owner",
      line_id: @test_user_id
    )
    
    target_employee = Employee.create!(
      employee_id: "target_001",
      role: "employee",
      line_id: "target_user_id"
    )

    # シフト追加リクエストを作成
    future_date = Date.current + 7.days
    addition_request = ShiftAddition.create!(
      request_id: "ADD_#{Time.current.strftime('%Y%m%d_%H%M%S')}_test",
      requester_id: owner.employee_id,
      target_employee_id: target_employee.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("18:00"),
      status: 'pending'
    )

    # リクエスト確認コマンドを実行
    event = mock_line_event(source_type: "user", user_id: "target_user_id")
    event['message']['text'] = 'リクエスト確認'

    response = @line_bot_service.handle_message(event)

    # Flex Message形式で承認待ちリクエストが表示されることを確認
    assert response.is_a?(Hash)
    assert_equal "flex", response[:type]
    assert_includes response[:altText], "承認待ちのリクエスト"

    # クリーンアップ
    addition_request.destroy
    owner.destroy
    target_employee.destroy
  end

  # 修正した機能のテスト
  test "should show past date warning in shift addition command" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # グループメッセージイベント
    event = mock_line_event(source_type: "group", group_id: @test_group_id, user_id: @test_user_id)
    event['message']['text'] = 'シフト追加'

    response = @line_bot_service.handle_message(event)

    # 過去の日付は指定できませんという警告が表示されることを確認
    assert_includes response, "過去の日付は指定できません"

    # クリーンアップ
    owner.destroy
  end

  test "should show improved employee input guide" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 時間入力待ちの状態を設定
    future_date = (Date.current + 30).strftime('%Y-%m-%d')
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_time',
      shift_date: future_date
    })

    # 時間を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, '09:00-18:00')

    # 改善された従業員入力ガイドが表示されることを確認
    assert_includes response, "💡 入力例："
    assert_includes response, "• 田中太郎"
    assert_includes response, "• 田中"
    assert_includes response, "• 複数人: 田中太郎,佐藤花子"
    assert_includes response, "複数人に送信する場合は「,」で区切って入力してください"

    # クリーンアップ
    owner.destroy
  end

  test "should handle multiple employees input" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成
    target_employee1 = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    target_employee2 = Employee.create!(
      employee_id: "1001",
      role: "employee",
      line_id: "other_user_2"
    )

    # display_nameメソッドをグローバルにオーバーライド
    Employee.class_eval do
      def display_name
        case self.employee_id
        when "1000"
          "テスト 太郎"
        when "1001"
          "テスト 花子"
        else
          "ID: #{self.employee_id}"
        end
      end
    end

    # テスト用にfind_employees_by_nameメソッドをオーバーライド
    @@test_target_employees = [target_employee1, target_employee2]
    
    def @line_bot_service.find_employees_by_name(name)
      case name
      when "テスト 太郎"
        [@@test_target_employees[0]]
      when "テスト 花子"
        [@@test_target_employees[1]]
      else
        []
      end
    end

    # 従業員選択待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: (Date.current + 30).strftime('%Y-%m-%d'),
      shift_time: '09:00-18:00'
    })

    # 複数の従業員名を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'テスト 太郎,テスト 花子')

    # 確認画面が表示されることを確認
    assert_includes response, "シフト追加依頼の確認"
    assert_includes response, "テスト 太郎"
    assert_includes response, "テスト 花子"

    # クリーンアップ
    owner.destroy
    target_employee1.destroy
    target_employee2.destroy
  end

  test "should handle multiple employees with some overlapping" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成
    target_employee1 = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    target_employee2 = Employee.create!(
      employee_id: "1001",
      role: "employee",
      line_id: "other_user_2"
    )

    # 既存のシフトを作成（target_employee1のみ重複）
    future_date = Date.current + 30
    existing_shift = Shift.create!(
      employee_id: target_employee1.employee_id,
      shift_date: future_date,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('16:00')
    )

    # display_nameメソッドをグローバルにオーバーライド
    Employee.class_eval do
      def display_name
        case self.employee_id
        when "1000"
          "テスト 太郎"
        when "1001"
          "テスト 花子"
        else
          "ID: #{self.employee_id}"
        end
      end
    end

    # テスト用にfind_employees_by_nameメソッドをオーバーライド
    @@test_target_employees = [target_employee1, target_employee2]
    
    def @line_bot_service.find_employees_by_name(name)
      case name
      when "テスト 太郎"
        [@@test_target_employees[0]]
      when "テスト 花子"
        [@@test_target_employees[1]]
      else
        []
      end
    end

    # 従業員選択待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: future_date.strftime('%Y-%m-%d'),
      shift_time: '09:00-18:00'
    })

    # 複数の従業員名を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'テスト 太郎,テスト 花子')

    # 重複警告と利用可能な従業員のみの確認画面が表示されることを確認
    assert_includes response, "以下の従業員は指定された時間にシフトが入っています"
    assert_includes response, "テスト 太郎"
    assert_includes response, "利用可能な従業員のみに送信しますか？"
    assert_includes response, "テスト 花子"

    # クリーンアップ
    existing_shift.destroy
    owner.destroy
    target_employee1.destroy
    target_employee2.destroy
  end

  test "should create multiple shift addition requests" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成
    target_employee1 = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    target_employee2 = Employee.create!(
      employee_id: "1001",
      role: "employee",
      line_id: "other_user_2"
    )

    # 確認待ちの状態を設定（複数の従業員ID）
    future_date = (Date.current + 30).strftime('%Y-%m-%d')
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_confirmation',
      shift_date: future_date,
      shift_time: '09:00-18:00',
      target_employee_ids: ['1000', '1001']
    })

    # 確認して依頼を送信
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'はい')

    # 複数人への依頼が成功したことを確認
    assert_includes response, "2名の従業員にシフト追加依頼を送信しました"

    # 2つのシフト追加リクエストが作成されたことを確認
    future_date = Date.current + 30
    shift_additions = ShiftAddition.where(
      requester_id: owner.employee_id,
      shift_date: future_date
    )
    assert_equal 2, shift_additions.count
    assert_equal ['1000', '1001'], shift_additions.pluck(:target_employee_id).sort

    # クリーンアップ
    shift_additions.destroy_all
    owner.destroy
    target_employee1.destroy
    target_employee2.destroy
  end

  test "should handle employee not found in multiple input" do
    # オーナー従業員を作成
    owner = Employee.create!(
      employee_id: "999",
      role: "owner",
      line_id: @test_user_id
    )

    # 対象従業員を作成（1人だけ）
    target_employee = Employee.create!(
      employee_id: "1000",
      role: "employee",
      line_id: "other_user_1"
    )

    # display_nameメソッドをグローバルにオーバーライド
    Employee.class_eval do
      def display_name
        case self.employee_id
        when "1000"
          "テスト 太郎"
        else
          "ID: #{self.employee_id}"
        end
      end
    end

    # テスト用にfind_employees_by_nameメソッドをオーバーライド
    @@test_target_employee = target_employee
    
    def @line_bot_service.find_employees_by_name(name)
      case name
      when "テスト 太郎"
        [@@test_target_employee]
      else
        []
      end
    end

    # 従業員選択待ちの状態を設定
    @line_bot_service.set_conversation_state(@test_user_id, { 
      step: 'waiting_shift_addition_employee',
      shift_date: (Date.current + 30).strftime('%Y-%m-%d'),
      shift_time: '09:00-18:00'
    })

    # 存在しない従業員を含む複数の従業員名を入力
    response = @line_bot_service.handle_message_with_state(@test_user_id, 'テスト 太郎,存在しない従業員')

    # エラーメッセージが表示されることを確認
    assert_includes response, "従業員が見つかりません: 存在しない従業員"

    # クリーンアップ
    owner.destroy
    target_employee.destroy
  end


  private

  def mock_line_event(source_type:, user_id:, group_id: nil)
    event = {
      'type' => 'message',
      'message' => {
        'type' => 'text',
        'text' => 'test message'
      },
      'source' => {
        'type' => source_type,
        'userId' => user_id
      }
    }
    
    if source_type == 'group' && group_id
      event['source']['groupId'] = group_id
    end
    
    event
  end
end
