require 'test_helper'

class ShiftMailerTest < ActionMailer::TestCase
  test "should send shift exchange request email" do
    # テストデータの準備
    approver_email = "approver@example.com"
    approver_name = "承認者 太郎"
    requester_name = "申請者 花子"
    shift_date = Date.parse('2025-09-19')
    start_time = Time.zone.parse('20:00')
    end_time = Time.zone.parse('23:00')
    
    # メール送信
    email = ShiftMailer.shift_exchange_request(
      approver_email,
      approver_name,
      requester_name,
      shift_date,
      start_time,
      end_time
    )
    
    # メール送信の確認
    assert_emails 1 do
      email.deliver_now
    end
    
    # メール内容の確認
    assert_equal [approver_email], email.to
    assert_equal "【シフト交代のお願い】#{requester_name}さんより", email.subject
    
    # メール本文の確認
    assert_includes email.body.to_s, approver_name
    assert_includes email.body.to_s, requester_name
    assert_includes email.body.to_s, "09月19日"
    assert_includes email.body.to_s, "20:00"
    assert_includes email.body.to_s, "23:00"
  end

  test "should send shift exchange approved email" do
    # テストデータの準備
    requester_email = "requester@example.com"
    requester_name = "申請者 花子"
    approver_name = "承認者 太郎"
    shift_date = Date.parse('2025-09-19')
    start_time = Time.zone.parse('20:00')
    end_time = Time.zone.parse('23:00')
    
    # メール送信
    email = ShiftMailer.shift_exchange_approved(
      requester_email,
      requester_name,
      approver_name,
      shift_date,
      start_time,
      end_time
    )
    
    # メール送信の確認
    assert_emails 1 do
      email.deliver_now
    end
    
    # メール内容の確認
    assert_equal [requester_email], email.to
    assert_equal "【承認】シフト交代リクエストが承認されました", email.subject
    
    # メール本文の確認
    assert_includes email.body.to_s, requester_name
    assert_includes email.body.to_s, approver_name
  end

  test "should send shift exchange denied email" do
    # テストデータの準備
    requester_email = "requester@example.com"
    requester_name = "申請者 花子"
    
    # メール送信
    email = ShiftMailer.shift_exchange_denied(
      requester_email,
      requester_name
    )
    
    # メール送信の確認
    assert_emails 1 do
      email.deliver_now
    end
    
    # メール内容の確認
    assert_equal [requester_email], email.to
    assert_equal "【シフト交代失敗】シフト交代リクエストが成立しませんでした", email.subject
    
    # メール本文の確認
    assert_includes email.body.to_s, requester_name
  end
end