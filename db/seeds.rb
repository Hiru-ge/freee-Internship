# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require 'bcrypt'

# シフト情報の初期データ（GASのテストコードから移植）
puts "シフト情報の初期データを作成中..."

# 現在の月のシフトデータを作成
current_date = Date.current
year = current_date.year
month = current_date.month

# 従業員IDのリスト（freee APIから取得した実際のID）
employee_ids = ["3313254", "3316116", "3316120", "3317741"]

# 従業員レコードを作成（存在しない場合のみ）
puts "従業員レコードを作成中..."
employee_ids.each do |employee_id|
  unless Employee.exists?(employee_id: employee_id)
    Employee.create!(
      employee_id: employee_id,
      password_hash: BCrypt::Password.create("password123"), # デフォルトパスワード
      role: employee_id == "3313254" ? "owner" : "employee"
    )
    puts "従業員 #{employee_id} を作成しました"
  else
    puts "従業員 #{employee_id} は既に存在します"
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

# GASのテストコードから移植したシフトデータ
# 従業員0（店長 太郎）: 週3回程度、18-20と20-23中心
shift_data_3313254 = [
  [1, "18:00", "20:00"], [2, "18:00", "20:00"], [4, "20:00", "23:00"], [5, "20:00", "23:00"], 
  [6, "20:00", "23:00"], [7, "18:00", "20:00"], [10, "18:00", "20:00"], [11, "18:00", "20:00"], 
  [13, "20:00", "23:00"], [14, "18:00", "20:00"], [16, "20:00", "23:00"], [17, "18:00", "20:00"], 
  [19, "20:00", "23:00"], [20, "18:00", "20:00"], [22, "20:00", "23:00"], [23, "18:00", "20:00"], 
  [25, "20:00", "23:00"], [26, "18:00", "20:00"], [27, "20:00", "23:00"], [29, "18:00", "20:00"], 
  [30, "20:00", "23:00"], [31, "18:00", "20:00"]
]

# 従業員1（テスト 太郎）: 週3回程度、20-23と18-20中心
shift_data_3316116 = [
  [1, "20:00", "23:00"], [3, "18:00", "20:00"], [4, "18:00", "20:00"], [6, "18:00", "20:00"], 
  [8, "20:00", "23:00"], [10, "18:00", "20:00"], [12, "18:00", "20:00"], [13, "20:00", "23:00"], 
  [14, "18:00", "20:00"], [16, "18:00", "20:00"], [18, "20:00", "23:00"], [20, "18:00", "20:00"], 
  [21, "20:00", "23:00"], [22, "18:00", "20:00"], [24, "18:00", "20:00"], [26, "20:00", "23:00"], 
  [27, "18:00", "20:00"], [28, "20:00", "23:00"], [30, "18:00", "20:00"]
]

# 従業員2（テスト 次郎）: 週3回程度、20-23と18-20中心
shift_data_3316120 = [
  [2, "20:00", "23:00"], [3, "20:00", "23:00"], [5, "18:00", "20:00"], [7, "20:00", "23:00"], 
  [9, "20:00", "23:00"], [10, "18:00", "20:00"], [12, "18:00", "20:00"], [13, "20:00", "23:00"], 
  [15, "18:00", "20:00"], [16, "20:00", "23:00"], [17, "18:00", "20:00"], [19, "20:00", "23:00"], 
  [20, "18:00", "20:00"], [21, "20:00", "23:00"], [23, "18:00", "20:00"], [24, "20:00", "23:00"], 
  [25, "18:00", "20:00"], [27, "20:00", "23:00"], [28, "18:00", "20:00"], [29, "20:00", "23:00"], 
  [30, "18:00", "20:00"]
]

# 従業員3（テスト 三郎）: 週3回程度、18-23中心
shift_data_3317741 = [
  [1, "18:00", "23:00"], [3, "18:00", "23:00"], [4, "18:00", "23:00"], [5, "18:00", "23:00"], 
  [7, "18:00", "23:00"], [8, "18:00", "23:00"], [10, "20:00", "23:00"], [11, "18:00", "23:00"], 
  [13, "18:00", "23:00"], [15, "18:00", "23:00"], [16, "18:00", "23:00"], [18, "20:00", "23:00"], 
  [19, "18:00", "23:00"], [20, "18:00", "23:00"], [22, "18:00", "23:00"], [24, "18:00", "23:00"], 
  [25, "20:00", "23:00"], [26, "18:00", "23:00"], [28, "18:00", "23:00"], [29, "18:00", "23:00"], 
  [31, "20:00", "23:00"]
]

# シフトデータのハッシュ
shift_data_hash = {
  "3313254" => shift_data_3313254,
  "3316116" => shift_data_3316116,
  "3316120" => shift_data_3316120,
  "3317741" => shift_data_3317741
}

# 各従業員のシフトを作成
shift_data_hash.each do |employee_id, shifts|
  shifts.each do |day, start_time, end_time|
    # 日付が月の範囲内かチェック
    max_day = Date.new(year, month, -1).day
    if day <= max_day
      date = Date.new(year, month, day)
      
      Shift.create!(
        employee_id: employee_id,
        shift_date: date,
        start_time: start_time,
        end_time: end_time,
        is_modified: false
      )
    end
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

# シフト変更リクエストのサンプルデータ
puts "シフト変更リクエストを作成中..."

# リクエスト1: テスト 太郎 → テスト 次郎への交代依頼
shift1 = Shift.find_by(employee_id: "3316116", shift_date: Date.new(year, month, 3))
if shift1
  ShiftExchange.create!(
    request_id: SecureRandom.uuid,
    requester_id: "3316116", # テスト 太郎
    approver_id: "3316120",  # テスト 次郎
    shift_id: shift1.id,
    status: "pending",
    requested_at: Time.current - 2.hours
  )
end

# リクエスト2: テスト 次郎 → テスト 三郎への交代依頼
shift2 = Shift.find_by(employee_id: "3316120", shift_date: Date.new(year, month, 7))
if shift2
  ShiftExchange.create!(
    request_id: SecureRandom.uuid,
    requester_id: "3316120", # テスト 次郎
    approver_id: "3317741",  # テスト 三郎
    shift_id: shift2.id,
    status: "pending",
    requested_at: Time.current - 1.hour
  )
end

# リクエスト3: テスト 三郎 → 店長 太郎への交代依頼（承認済み）
shift3 = Shift.find_by(employee_id: "3317741", shift_date: Date.new(year, month, 10))
if shift3
  ShiftExchange.create!(
    request_id: SecureRandom.uuid,
    requester_id: "3317741", # テスト 三郎
    approver_id: "3313254",  # 店長 太郎
    shift_id: shift3.id,
    status: "approved",
    requested_at: Time.current - 3.hours,
    responded_at: Time.current - 2.hours
  )
end

# シフト追加リクエストのサンプルデータ（オーナーが従業員に依頼）
puts "シフト追加リクエストを作成中..."

# リクエスト1: オーナー → テスト 太郎への追加シフト依頼（承認済み）
ShiftAddition.create!(
  request_id: SecureRandom.uuid,
  requester_id: "3313254", # オーナー（店長 太郎）
  target_employee_id: "3316116", # テスト 太郎
  shift_date: Date.new(year, month, 15),
  start_time: "18:00",
  end_time: "20:00",
  status: "approved",
  requested_at: Time.current - 4.hours,
  responded_at: Time.current - 3.hours
)

# リクエスト2: オーナー → テスト 次郎への追加シフト依頼（拒否済み）
ShiftAddition.create!(
  request_id: SecureRandom.uuid,
  requester_id: "3313254", # オーナー（店長 太郎）
  target_employee_id: "3316120", # テスト 次郎
  shift_date: Date.new(year, month, 18),
  start_time: "20:00",
  end_time: "23:00",
  status: "rejected",
  requested_at: Time.current - 5.hours,
  responded_at: Time.current - 4.hours
)

# リクエスト3: オーナー → テスト 三郎への追加シフト依頼（承認待ち）
ShiftAddition.create!(
  request_id: SecureRandom.uuid,
  requester_id: "3313254", # オーナー（店長 太郎）
  target_employee_id: "3317741", # テスト 三郎
  shift_date: Date.new(year, month, 22),
  start_time: "18:00",
  end_time: "23:00",
  status: "pending",
  requested_at: Time.current - 30.minutes
)

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
