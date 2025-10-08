# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "bcrypt"

# シフト情報の初期データ（GASのテストコードから移植）
puts "シフト情報の初期データを作成中..."

# 現在の月のシフトデータを作成
current_date = Date.current
year = current_date.year
month = current_date.month

# freee APIから従業員一覧を取得
puts "freee APIから従業員データを取得中..."
freee_service = FreeeApiService.new(
  ENV["FREEE_ACCESS_TOKEN"],
  ENV["FREEE_COMPANY_ID"]
)

employees = freee_service.get_employees
if employees.empty?
  puts "警告: freee APIから従業員データを取得できませんでした"
  puts "環境変数 FREEE_ACCESS_TOKEN と FREEE_COMPANY_ID を確認してください"
  exit 1
end

# 従業員IDのリストを動的生成
employee_ids = employees.map { |emp| emp[:id] }
owner_id = ENV["OWNER_EMPLOYEE_ID"] || employee_ids.first

puts "従業員数: #{employee_ids.length}"
puts "オーナーID: #{owner_id}"

# 従業員レコードを作成（存在しない場合のみ）
puts "従業員レコードを作成中..."
employee_ids.each do |employee_id|
  if Employee.exists?(employee_id: employee_id)
    puts "従業員 #{employee_id} は既に存在します"
  else
    # 環境変数に基づいて役割を決定
    role = if ENV["OWNER_EMPLOYEE_ID"]&.strip&.present? && employee_id == ENV["OWNER_EMPLOYEE_ID"].strip
             "owner"
           else
             "employee"
           end

    Employee.create!(
      employee_id: employee_id,
      password_hash: BCrypt::Password.create("password123"), # デフォルトパスワード
      role: role # 環境変数に基づいて役割を設定
    )
    puts "従業員 #{employee_id} を作成しました"
  end
end

# 既存のシフトデータを削除（同じ月のデータ）
# 外部キー制約を考慮して、shift_exchangesを先に削除してからshiftsを削除
target_shifts = Shift.where(shift_date: Date.new(year, month, 1)..Date.new(year, month, -1))
if target_shifts.exists?
  # 対象のシフトに関連するshift_exchangesを先に削除
  ShiftExchange.where(shift_id: target_shifts.pluck(:id)).destroy_all
  # その後、シフトを削除
  target_shifts.destroy_all
end

# シフトデータの動的生成
# 各従業員に対してランダムなシフトパターンを生成
def generate_shift_data(employee_id, employee_count, index)
  # 基本的なシフトパターン（週3-4回勤務）
  base_patterns = [
    # パターン1: 平日中心（月水金）
    [[1, "18:00", "20:00"], [3, "18:00", "20:00"], [5, "20:00", "23:00"], [8, "18:00", "20:00"], [10, "20:00", "23:00"], [12, "18:00", "20:00"], [15, "20:00", "23:00"], [17, "18:00", "20:00"], [19, "20:00", "23:00"], [22, "18:00", "20:00"], [24, "20:00", "23:00"], [26, "18:00", "20:00"], [29, "20:00", "23:00"], [31, "18:00", "20:00"]],
    # パターン2: 週末中心（土日）
    [[2, "18:00", "23:00"], [3, "20:00", "23:00"], [6, "18:00", "23:00"], [7, "20:00", "23:00"], [9, "18:00", "23:00"], [10, "20:00", "23:00"], [13, "18:00", "23:00"], [14, "20:00", "23:00"], [16, "18:00", "23:00"], [17, "20:00", "23:00"], [20, "18:00", "23:00"], [21, "20:00", "23:00"], [23, "18:00", "23:00"], [24, "20:00", "23:00"], [27, "18:00", "23:00"], [28, "20:00", "23:00"], [30, "18:00", "23:00"], [31, "20:00", "23:00"]],
    # パターン3: バランス型（平日・週末混合）
    [[1, "20:00", "23:00"], [3, "18:00", "20:00"], [5, "18:00", "23:00"], [7, "20:00", "23:00"], [9, "18:00", "20:00"], [11, "20:00", "23:00"], [13, "18:00", "20:00"], [15, "20:00", "23:00"], [17, "18:00", "20:00"], [19, "20:00", "23:00"], [21, "18:00", "20:00"], [23, "20:00", "23:00"], [25, "18:00", "20:00"], [27, "20:00", "23:00"], [29, "18:00", "20:00"], [31, "20:00", "23:00"]],
    # パターン4: 夜勤中心
    [[1, "20:00", "23:00"], [2, "20:00", "23:00"], [4, "20:00", "23:00"], [6, "20:00", "23:00"], [8, "20:00", "23:00"], [10, "20:00", "23:00"], [12, "20:00", "23:00"], [14, "20:00", "23:00"], [16, "20:00", "23:00"], [18, "20:00", "23:00"], [20, "20:00", "23:00"], [22, "20:00", "23:00"], [24, "20:00", "23:00"], [26, "20:00", "23:00"], [28, "20:00", "23:00"], [30, "20:00", "23:00"]]
  ]

  # 従業員のインデックスに基づいてパターンを選択
  pattern_index = index % base_patterns.length
  base_patterns[pattern_index]
end

# シフトデータのハッシュを動的生成
shift_data_hash = {}
employee_ids.each_with_index do |employee_id, index|
  shift_data_hash[employee_id] = generate_shift_data(employee_id, employee_ids.length, index)
end

# 各従業員のシフトを作成
shift_data_hash.each do |employee_id, shifts|
  shifts.each do |day, start_time, end_time|
    # 日付が月の範囲内かチェック
    max_day = Date.new(year, month, -1).day
    next unless day <= max_day

    date = Date.new(year, month, day)

    # seed作成時はバリデーションをスキップ
    shift = Shift.new(
      employee_id: employee_id,
      shift_date: date,
      start_time: start_time,
      end_time: end_time,
      is_modified: false
    )
    shift.save!(validate: false)
  end
end

puts "シフト情報の初期データ作成完了"
puts "作成されたシフト数: #{Shift.count}"
puts "対象月: #{year}年#{month}月"
puts "従業員別シフト数:"
Shift.group(:employee_id).count.each do |employee_id, count|
  puts "  #{employee_id}: #{count}件"
end

# シフト変更・追加リクエストのサンプルデータ
puts "\nシフト変更・追加リクエストのサンプルデータを作成中..."

# 既存のリクエストデータを削除
ShiftExchange.destroy_all
ShiftAddition.destroy_all

# シフト変更リクエストのサンプルデータ（動的生成）
puts "シフト変更リクエストを作成中..."

# 従業員が2人以上いる場合のみサンプルデータを作成
if employee_ids.length >= 2
  # 最初の従業員から2番目の従業員への交代依頼
  shift1 = Shift.find_by(employee_id: employee_ids[0], shift_date: Date.new(year, month, 3))
  if shift1
    ShiftExchange.create!(
      request_id: SecureRandom.uuid,
      requester_id: employee_ids[0],
      approver_id: employee_ids[1],
      shift_id: shift1.id,
      status: "pending",
      requested_at: Time.current - 2.hours
    )
  end

  # 2番目の従業員から3番目の従業員への交代依頼（3人以上いる場合）
  if employee_ids.length >= 3
    shift2 = Shift.find_by(employee_id: employee_ids[1], shift_date: Date.new(year, month, 7))
    if shift2
      ShiftExchange.create!(
        request_id: SecureRandom.uuid,
        requester_id: employee_ids[1],
        approver_id: employee_ids[2],
        shift_id: shift2.id,
        status: "pending",
        requested_at: Time.current - 1.hour
      )
    end

    # 3番目の従業員からオーナーへの交代依頼（承認済み）
    shift3 = Shift.find_by(employee_id: employee_ids[2], shift_date: Date.new(year, month, 10))
    if shift3
      ShiftExchange.create!(
        request_id: SecureRandom.uuid,
        requester_id: employee_ids[2],
        approver_id: owner_id,
        shift_id: shift3.id,
        status: "approved",
        requested_at: Time.current - 3.hours,
        responded_at: Time.current - 2.hours
      )
    end
  end
end

# シフト追加リクエストのサンプルデータ（オーナーが従業員に依頼）
puts "シフト追加リクエストを作成中..."

# シフト追加依頼のサンプルデータ（動的生成）
# 従業員が1人以上いる場合のみサンプルデータを作成
if employee_ids.length >= 1
  # リクエスト1: オーナー → 最初の従業員への追加シフト依頼（承認済み）
  ShiftAddition.create!(
    request_id: SecureRandom.uuid,
    requester_id: owner_id,
    target_employee_id: employee_ids[0],
    shift_date: Date.new(year, month, 15),
    start_time: "18:00",
    end_time: "20:00",
    status: "approved",
    requested_at: Time.current - 4.hours,
    responded_at: Time.current - 3.hours
  )

  # リクエスト2: オーナー → 2番目の従業員への追加シフト依頼（拒否済み）
  if employee_ids.length >= 2
    ShiftAddition.create!(
      request_id: SecureRandom.uuid,
      requester_id: owner_id,
      target_employee_id: employee_ids[1],
      shift_date: Date.new(year, month, 18),
      start_time: "20:00",
      end_time: "23:00",
      status: "rejected",
      requested_at: Time.current - 5.hours,
      responded_at: Time.current - 4.hours
    )
  end

  # リクエスト3: オーナー → 3番目の従業員への追加シフト依頼（承認待ち）
  if employee_ids.length >= 3
    ShiftAddition.create!(
      request_id: SecureRandom.uuid,
      requester_id: owner_id,
      target_employee_id: employee_ids[2],
      shift_date: Date.new(year, month, 22),
      start_time: "18:00",
      end_time: "23:00",
      status: "pending",
      requested_at: Time.current - 30.minutes
    )
  end
end

puts "シフト変更・追加リクエストのサンプルデータ作成完了"
puts "作成されたシフト変更リクエスト数: #{ShiftExchange.count}"
puts "作成されたシフト追加リクエスト数: #{ShiftAddition.count}"
puts ""
puts "リクエスト詳細:"
puts "シフト変更リクエスト:"
ShiftExchange.includes(:shift).each do |exchange|
  puts "  - #{exchange.requester_id} → #{exchange.approver_id} (#{exchange.shift&.shift_date} #{exchange.shift&.start_time}-#{exchange.shift&.end_time}) [#{exchange.status}]"
end
puts "シフト追加リクエスト:"
ShiftAddition.all.each do |addition|
  puts "  - #{addition.requester_id} → #{addition.target_employee_id} (#{addition.shift_date} #{addition.start_time}-#{addition.end_time}) [#{addition.status}]"
end
