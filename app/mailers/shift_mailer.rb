# frozen_string_literal: true

class ShiftMailer < ApplicationMailer
  # シフト交代依頼の通知メール
  def shift_exchange_request(approver_email, approver_name, requester_name, shift_date, start_time, end_time)
    @approver_name = approver_name
    @requester_name = requester_name
    @shift_date = shift_date
    @start_time = start_time
    @end_time = end_time
    @approval_url = "#{root_url}shift_approvals"

    mail(
      to: approver_email,
      subject: "【シフト交代のお願い】#{@requester_name}さんより"
    )
  end

  # シフト交代承認の通知メール
  def shift_exchange_approved(requester_email, requester_name, approver_name, shift_date, start_time, end_time)
    @requester_name = requester_name
    @approver_name = approver_name
    @shift_date = shift_date
    @start_time = start_time
    @end_time = end_time

    mail(
      to: requester_email,
      subject: "【承認】シフト交代リクエストが承認されました"
    )
  end

  # シフト交代否認の通知メール（全員否認の場合）
  def shift_exchange_denied(requester_email, requester_name)
    @requester_name = requester_name

    mail(
      to: requester_email,
      subject: "【シフト交代失敗】シフト交代リクエストが成立しませんでした"
    )
  end

  # シフト追加依頼の通知メール
  def shift_addition_request(target_email, target_name, shift_date, start_time, end_time)
    @target_name = target_name
    @shift_date = shift_date
    @start_time = start_time
    @end_time = end_time
    @approval_url = "#{root_url}shift_approvals"

    mail(
      to: target_email,
      subject: "【シフト追加のお願い】"
    )
  end

  # シフト追加承認の通知メール（オーナー宛）
  def shift_addition_approved(owner_email, target_name, shift_date, start_time, end_time)
    @target_name = target_name
    @shift_date = shift_date
    @start_time = start_time
    @end_time = end_time

    mail(
      to: owner_email,
      subject: "【承認】#{@target_name}さんがシフト追加を承認しました"
    )
  end

  # シフト追加否認の通知メール（オーナー宛）
  def shift_addition_denied(owner_email, target_name)
    @target_name = target_name

    mail(
      to: owner_email,
      subject: "【否認】#{@target_name}さんがシフト追加を否認しました"
    )
  end
end
