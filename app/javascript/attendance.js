// 勤怠管理のJavaScript

// グローバル変数
let currentEmployeeId;
let currentEmployeeName;
let attendanceYear;
let attendanceMonth;
let clockInPath;
let clockOutPath;
let clockStatusPath;
let attendanceHistoryPath;
let allAttendanceData;

// 初期化
document.addEventListener('DOMContentLoaded', function () {
    loadConfig();
    updateClockButtons();
    initializeAttendanceHistory();
});

// 設定の読み込み
function loadConfig() {
    const container = document.querySelector('.dashboard-container');
    if (!container) return;

    currentEmployeeId = container.dataset.employeeId;
    currentEmployeeName = container.dataset.employeeName;
    attendanceYear = parseInt(container.dataset.attendanceYear);
    attendanceMonth = parseInt(container.dataset.attendanceMonth);
    clockInPath = container.dataset.clockInPath;
    clockOutPath = container.dataset.clockOutPath;
    clockStatusPath = container.dataset.clockStatusPath;
    attendanceHistoryPath = container.dataset.attendanceHistoryPath;
}

// 勤怠履歴の初期化
function initializeAttendanceHistory() {
    if (!currentEmployeeId) {
        showAttendanceError('従業員IDが取得できません');
        return;
    }
    loadAttendanceData();
}

// 勤怠データを読み込み
function loadAttendanceData() {
    const yearMonth = attendanceYear + '-' + String(attendanceMonth).padStart(2, '0');

    fetch(`${attendanceHistoryPath}?year=${attendanceYear}&month=${attendanceMonth}`)
        .then(response => response.json())
        .then(data => {
            displayAttendanceData(data);
        })
        .catch(error => {
            showAttendanceError('勤怠データの取得に失敗しました: ' + error.message);
        });
}

// 勤怠データを表示
function displayAttendanceData(attendanceRecords) {
    try {
        const attendanceContainer = document.getElementById('attendance-container');
        const title = document.getElementById('attendance-title');

        // タイトルを更新（ページネーションボタンを保持）
        title.innerHTML = attendanceYear + '年' + attendanceMonth + '月の勤怠履歴' +
            '<span class="month-navigation-buttons">' +
            '<button class="button" onclick="prevMonth()">前月</button>' +
            '<button class="button" onclick="nextMonth()">次月</button>' +
            '</span>';

        // テーブルを生成
        let html = '<table border="1">';
        html += '<thead><tr><th>種別</th><th>日時</th></tr></thead>';
        html += '<tbody>';

        if (!attendanceRecords || attendanceRecords.length === 0) {
            html += '<tr><td colspan="2" style="text-align: center; padding: 40px; color: #999;">この月の勤怠記録がありません</td></tr>';
        } else {
            for (let i = 0; i < attendanceRecords.length; i++) {
                const attendanceRecord = attendanceRecords[i];
                html += '<tr>';
                html += '<td>' + attendanceRecord.type + '</td>';
                html += '<td>' + attendanceRecord.date + '</td>';
                html += '</tr>';
            }
        }

        html += '</tbody></table>';
        attendanceContainer.innerHTML = html;

    } catch (error) {
        showAttendanceError('勤怠データの表示に失敗しました: ' + error.message);
    }
}

// 前の月に移動
function prevMonth() {
    attendanceMonth--;
    if (attendanceMonth < 1) {
        attendanceMonth = 12;
        attendanceYear--;
    }
    loadAttendanceData();
}

// 次の月に移動
function nextMonth() {
    attendanceMonth++;
    if (attendanceMonth > 12) {
        attendanceMonth = 1;
        attendanceYear++;
    }
    loadAttendanceData();
}

// 勤怠エラー表示
function showAttendanceError(message) {
    const container = document.getElementById('attendance-container');
    container.innerHTML = '<p style="color: red; text-align: center; padding: 20px;">' + message + '</p>';
}

// 打刻ボタンの状態更新
function updateClockButtons() {
    if (!currentEmployeeId) return;

    fetch(clockStatusPath)
        .then(response => response.json())
        .then(clockStatus => {
            const clockInBtn = document.getElementById('clock-in-btn');
            const clockOutBtn = document.getElementById('clock-out-btn');
            const statusDiv = document.getElementById('clock-status');

            if (clockStatus.can_clock_in) {
                clockInBtn.disabled = false;
                clockInBtn.textContent = '出勤';
            } else {
                clockInBtn.disabled = true;
                clockInBtn.textContent = '出勤';
            }

            if (clockStatus.can_clock_out) {
                clockOutBtn.disabled = false;
                clockOutBtn.textContent = '退勤';
            } else {
                clockOutBtn.disabled = true;
                clockOutBtn.textContent = '退勤';
            }

            if (clockStatus.message) {
                statusDiv.textContent = clockStatus.message;
                statusDiv.style.display = 'block';
            } else {
                statusDiv.style.display = 'none';
            }
        })
        .catch(error => {
            console.error('打刻状態取得エラー:', error);
        });
}

// 出勤打刻
function clockIn() {
    if (!currentEmployeeId) return;

    fetch(clockInPath, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
    })
        .then(response => response.json())
        .then(result => {
            showMessage(result.message, result.success ? 'success' : 'error');
            if (result.success) {
                updateClockButtons();
                loadAttendanceData();
            }
        })
        .catch(error => {
            console.error('出勤打刻エラー:', error);
            showMessage('出勤打刻中にエラーが発生しました', 'error');
        });
}

// 退勤打刻
function clockOut() {
    if (!currentEmployeeId) return;

    fetch(clockOutPath, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
    })
        .then(response => response.json())
        .then(result => {
            showMessage(result.message, result.success ? 'success' : 'error');
            if (result.success) {
                updateClockButtons();
                loadAttendanceData();
            }
        })
        .catch(error => {
            console.error('退勤打刻エラー:', error);
            showMessage('退勤打刻中にエラーが発生しました', 'error');
        });
}

// メッセージ表示
function showMessage(message, type) {
    if (window.messageHandler) {
        return window.messageHandler.show(message, type);
    }
}
