# frozen_string_literal: true

class LineRequestService
  def initialize
    @message_service = LineMessageService.new
    @utility_service = LineUtilityService.new
  end

  # 依頼確認コマンドの処理
  def handle_request_check_command(event)
    line_user_id = @utility_service.extract_user_id(event)

    # 認証チェック
    return "認証が必要です。「認証」と入力して認証を行ってください。" unless @utility_service.employee_already_linked?(line_user_id)

    employee = @utility_service.find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee

    # 承認待ちのリクエストを取得
    pending_requests = get_pending_requests(employee.employee_id)

    # Flex Messageを生成して返す
    @message_service.generate_pending_requests_flex_message(
      pending_requests[:exchanges],
      pending_requests[:additions],
      pending_requests[:deletions]
    )
  end

  private

  def get_pending_requests(employee_id)
    {
      exchanges: get_pending_exchanges(employee_id),
      additions: get_pending_additions(employee_id),
      deletions: get_pending_deletions(employee_id)
    }
  end

  def get_pending_exchanges(employee_id)
    ShiftExchange.where(
      approver_id: employee_id,
      status: "pending"
    ).includes(:shift)
  end

  def get_pending_additions(employee_id)
    ShiftAddition.where(
      target_employee_id: employee_id,
      status: "pending"
    )
  end

  def get_pending_deletions(employee_id)
    ShiftDeletion.joins(:shift).where(
      shifts: { employee_id: employee_id },
      status: "pending"
    ).includes(:shift)
  end
end
