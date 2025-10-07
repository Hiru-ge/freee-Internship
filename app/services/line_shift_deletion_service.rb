class LineShiftDeletionService < LineBaseService
  def initialize
    super
  end
  def handle_shift_deletion_command(event)
    # 1. 認証チェック（LineBaseServiceの共通処理）
    auth_result = check_line_authentication(event)
    return auth_result[:message] unless auth_result[:success]

    # 2. コマンド処理（LineBaseServiceの共通処理）
    process_line_command_with_state("shift_deletion", event, "waiting_for_shift_deletion_date")
  end
  def handle_shift_deletion_date_input(line_user_id, message_text, state)

    date_validation_result = validate_month_day_format(message_text)
    return date_validation_result[:error] if date_validation_result[:error]

    selected_date = date_validation_result[:date]
    if selected_date < Date.current
      return "過去の日付は選択できません。未来の日付を入力してください。"
    end

    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    shifts_on_date = Shift.where(
      employee_id: employee.employee_id,
      shift_date: selected_date
    ).order(:start_time)

    if shifts_on_date.empty?
      return "指定された日付（#{selected_date.strftime('%m/%d')}）にシフトが見つかりません。\n別の日付を入力してください。"
    end
    set_conversation_state(line_user_id, {
      step: "waiting_for_shift_deletion_selection",
      state: "waiting_for_shift_deletion_selection",
      selected_date: selected_date
    })
    generate_shift_deletion_flex_message(shifts_on_date)
  end
  def handle_shift_selection(line_user_id, message_text, state)
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    if state["selected_date"]
      selected_date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
      selected_date = state["selected_date"] if state["selected_date"].is_a?(Date)

      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: selected_date
      ).order(:start_time)
    else

      shifts = Shift.where(
        employee_id: employee.employee_id,
        shift_date: Date.current..Float::INFINITY
      ).order(:shift_date, :start_time)
    end

    if shifts.empty?
      if state["selected_date"]
        selected_date = Date.parse(state["selected_date"]) if state["selected_date"].is_a?(String)
        selected_date = state["selected_date"] if state["selected_date"].is_a?(Date)
        return "指定された日付（#{selected_date.strftime('%m/%d')}）にシフトが見つかりません。"
      else
        return "欠勤申請可能なシフトが見つかりません。"
      end
    end
    generate_shift_deletion_flex_message(shifts)
  end
  def handle_deletion_shift_selection(line_user_id, postback_data)

    return "シフトを選択してください。" unless postback_data.match?(/^deletion_shift_\d+$/)

    shift_id = postback_data.split("_")[2]
    shift = Shift.find_by(id: shift_id)

    return "シフトが見つかりません。" unless shift
    set_conversation_state(line_user_id, {
      step: "waiting_deletion_reason",
      state: "waiting_deletion_reason",
      shift_id: shift_id
    })

    "欠勤理由を入力してください。\n例: 体調不良、急用、家族の用事など"
  end
  def handle_shift_deletion_reason_input(line_user_id, reason, state)
    if reason.blank?
      return "欠勤理由を入力してください。"
    end

    shift_id = state["shift_id"]
    create_shift_deletion_request(line_user_id, shift_id, reason)
  end
  def create_shift_deletion_request(line_user_id, shift_id, reason)
    employee = find_employee_by_line_id(line_user_id)
    return "従業員情報が見つかりません。" unless employee
    begin
      result = ShiftDeletion.create_request_for(
        shift_id: shift_id,
        requester_id: employee.employee_id,
        reason: reason
      )
      result.send_notifications!
      clear_conversation_state(line_user_id)
      result.success_message
    rescue ShiftDeletion::ValidationError, ShiftDeletion::AuthorizationError => e
      e.message
    end
  end
  def handle_deletion_approval_postback(line_user_id, postback_data, action)
    request_id = extract_request_id_from_postback(postback_data)
    shift_deletion = ShiftDeletion.find_by(request_id: request_id)

    return "欠勤申請が見つかりません。" unless shift_deletion
    employee = find_employee_by_line_id(line_user_id)
    return "この申請を処理する権限がありません。" unless employee&.owner?

    begin
      case action
      when "approve"
        shift_deletion.approve_by!(employee.employee_id)
        "欠勤申請を承認しました。"
      when "reject"
        shift_deletion.reject_by!(employee.employee_id)
        "欠勤申請を拒否しました。"
      else
        return "不明なアクションです。"
      end
    rescue ShiftDeletion::ValidationError, ShiftDeletion::AuthorizationError => e
      e.message
    end
  end

  private
  def generate_shift_deletion_flex_message(shifts)
    {
      type: "flex",
      altText: "📋 欠勤申請",
      contents: {
        type: "carousel",
        contents: shifts.map do |shift|
          {
            type: "bubble",
            header: {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "text",
                  text: "📋 欠勤申請",
                  weight: "bold",
                  color: "#ffffff",
                  size: "sm"
                }
              ],
              backgroundColor: "#FF6B6B"
            },
            body: {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "text",
                  text: shift.shift_date.strftime("%Y年%m月%d日"),
                  weight: "bold",
                  size: "lg"
                },
                {
                  type: "text",
                  text: "#{shift.start_time.strftime('%H:%M')}-#{shift.end_time.strftime('%H:%M')}",
                  size: "md",
                  color: "#666666",
                  margin: "md"
                },
                {
                  type: "separator",
                  margin: "md"
                },
                {
                  type: "text",
                  text: "現在の担当: #{shift.employee.display_name}",
                  size: "sm",
                  color: "#666666",
                  margin: "md"
                }
              ]
            },
            footer: {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "button",
                  action: {
                    type: "postback",
                    label: "欠勤申請",
                    data: "deletion_shift_#{shift.id}",
                    displayText: "欠勤申請"
                  },
                  style: "primary",
                  color: "#FF6B6B"
                }
              ]
            }
          }
        end
      }
    }
  end
  def extract_request_id_from_postback(postback_data)

    postback_data.split("_").last
  end
end
