# frozen_string_literal: true

require "rails_helper"

RSpec.describe LineShiftDeletionService, type: :service do
  let(:service) { described_class.new }
  let(:employee) { create(:employee, line_id: "test_line_id", role: "employee") }
  let(:owner) { create(:employee, line_id: "owner_line_id", role: "owner") }
  let(:shift) { create(:shift, employee: employee, shift_date: Date.current + 1) }
  let(:line_user_id) { "test_line_id" }

  describe "#handle_shift_deletion_command" do
    context "認証済みユーザーの場合" do
      before do
        allow(service).to receive(:employee_already_linked?).with(line_user_id).and_return(true)
        allow(service).to receive(:find_employee_by_line_id).with(line_user_id).and_return(employee)
      end

      it "欠勤申請の開始メッセージを返す" do
        event = mock_event(line_user_id, "欠勤申請")
        result = service.handle_shift_deletion_command(event)

        expect(result).to include("欠勤申請")
        expect(result).to include("シフトを選択")
      end

      it "会話状態を設定する" do
        event = mock_event(line_user_id, "欠勤申請")
        expect(service).to receive(:set_conversation_state).with(line_user_id, { step: "waiting_shift_selection" })

        service.handle_shift_deletion_command(event)
      end
    end

    context "未認証ユーザーの場合" do
      before do
        allow(service).to receive(:employee_already_linked?).with(line_user_id).and_return(false)
      end

      it "認証が必要なメッセージを返す" do
        event = mock_event(line_user_id, "欠勤申請")
        result = service.handle_shift_deletion_command(event)

        expect(result).to include("認証が必要です")
      end
    end
  end

  describe "#handle_shift_selection" do
    let(:state) { { step: "waiting_shift_selection" } }

    before do
      allow(service).to receive(:employee_already_linked?).with(line_user_id).and_return(true)
      allow(service).to receive(:find_employee_by_line_id).with(line_user_id).and_return(employee)
    end

    context "未来のシフトが存在する場合" do
      before do
        create(:shift, employee: employee, shift_date: Date.current + 1, start_time: "09:00", end_time: "18:00")
        create(:shift, employee: employee, shift_date: Date.current + 2, start_time: "10:00", end_time: "19:00")
      end

      it "シフト選択のFlex Messageを返す" do
        result = service.handle_shift_selection(line_user_id, "shift_selection", state)

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq("flex")
        expect(result[:contents][:contents]).to be_an(Array)
        expect(result[:contents][:contents].length).to eq(2)
      end
    end

    context "未来のシフトが存在しない場合" do
      before do
        create(:shift, employee: employee, shift_date: Date.current - 1) # 過去のシフト
      end

      it "シフトが見つからないメッセージを返す" do
        result = service.handle_shift_selection(line_user_id, "shift_selection", state)

        expect(result).to include("シフトが見つかりません")
      end
    end
  end

  describe "#handle_shift_deletion_reason_input" do
    let(:state) { { step: "waiting_reason", shift_id: shift.id } }

    before do
      allow(service).to receive(:employee_already_linked?).with(line_user_id).and_return(true)
      allow(service).to receive(:find_employee_by_line_id).with(line_user_id).and_return(employee)
    end

    context "有効な理由が入力された場合" do
      it "欠勤申請を作成する" do
        reason = "体調不良のため"

        expect(service).to receive(:create_shift_deletion_request).with(line_user_id, shift.id, reason)

        service.handle_shift_deletion_reason_input(line_user_id, reason, state)
      end
    end

    context "空の理由が入力された場合" do
      it "エラーメッセージを返す" do
        result = service.handle_shift_deletion_reason_input(line_user_id, "", state)

        expect(result).to include("理由を入力してください")
      end
    end
  end

  describe "#create_shift_deletion_request" do
    before do
      allow(service).to receive(:employee_already_linked?).with(line_user_id).and_return(true)
      allow(service).to receive(:find_employee_by_line_id).with(line_user_id).and_return(employee)
    end

    context "有効な申請の場合" do
      it "欠勤申請を作成する" do
        reason = "体調不良のため"

        result = service.create_shift_deletion_request(line_user_id, shift.id, reason)

        expect(result[:success]).to be true
        expect(result[:message]).to include("欠勤申請を送信しました")
      end

      it "ShiftDeletionServiceを呼び出す" do
        reason = "体調不良のため"
        deletion_service = instance_double(ShiftDeletionService)
        allow(ShiftDeletionService).to receive(:new).and_return(deletion_service)

        expect(deletion_service).to receive(:create_deletion_request).with(shift.id, employee.employee_id, reason)

        service.create_shift_deletion_request(line_user_id, shift.id, reason)
      end
    end

    context "既に申請済みの場合" do
      before do
        create(:shift_deletion, shift: shift, status: "pending")
      end

      it "エラーメッセージを返す" do
        reason = "体調不良のため"

        result = service.create_shift_deletion_request(line_user_id, shift.id, reason)

        expect(result[:success]).to be false
        expect(result[:message]).to include("既に申請済み")
      end
    end
  end

  describe "#handle_deletion_approval_postback" do
    let(:shift_deletion) { create(:shift_deletion, shift: shift, status: "pending") }
    let(:owner_line_user_id) { "owner_line_id" }

    before do
      allow(service).to receive(:employee_already_linked?).with(owner_line_user_id).and_return(true)
      allow(service).to receive(:find_employee_by_line_id).with(owner_line_user_id).and_return(owner)
    end

    context "承認の場合" do
      it "欠勤申請を承認する" do
        postback_data = "approve_deletion_#{shift_deletion.request_id}"

        result = service.handle_deletion_approval_postback(owner_line_user_id, postback_data, "approve")

        expect(result).to include("承認しました")
      end
    end

    context "拒否の場合" do
      it "欠勤申請を拒否する" do
        postback_data = "reject_deletion_#{shift_deletion.request_id}"

        result = service.handle_deletion_approval_postback(owner_line_user_id, postback_data, "reject")

        expect(result).to include("拒否しました")
      end
    end
  end

  private

  def mock_event(line_user_id, message_text)
    event = double("event")
    allow(event).to receive(:[]).with("source").and_return({ "userId" => line_user_id })
    allow(event).to receive(:[]).with("message").and_return({ "text" => message_text })
    allow(event).to receive(:[]).with("type").and_return("message")
    event
  end
end
