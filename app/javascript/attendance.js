// 勤怠管理のJavaScript

// 初期化
CommonUtils.initializePageWithConfig('attendance', '.dashboard-container', [
    updateClockButtons,
    initializeAttendanceHistory
]);

// 勤怠履歴の初期化
function initializeAttendanceHistory() {
    if (!window.config.currentEmployeeId) {
        showAttendanceError('従業員IDが取得できません');
        return;
    }
    loadAttendanceData();
}

// 勤怠データを読み込み
async function loadAttendanceData() {
    try {
        const data = await CommonUtils.apiCall(
            `${window.config.attendanceHistoryPath}?year=${window.config.attendanceYear}&month=${window.config.attendanceMonth}`
        );
        displayAttendanceData(data);
    } catch (error) {
        CommonUtils.handleApiError(error, '勤怠データの取得');
        showAttendanceError('勤怠データの取得に失敗しました');
    }
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
    window.config.attendanceMonth--;
    if (window.config.attendanceMonth < 1) {
        window.config.attendanceMonth = 12;
        window.config.attendanceYear--;
    }
    loadAttendanceData();
}

// 次の月に移動
function nextMonth() {
    window.config.attendanceMonth++;
    if (window.config.attendanceMonth > 12) {
        window.config.attendanceMonth = 1;
        window.config.attendanceYear++;
    }
    loadAttendanceData();
}

// 勤怠エラー表示
function showAttendanceError(message) {
    const container = document.getElementById('attendance-container');
    container.innerHTML = '<p style="color: red; text-align: center; padding: 20px;">' + message + '</p>';
}

// 打刻ボタンの状態更新
async function updateClockButtons() {
    if (!window.config.currentEmployeeId) return;

    try {
        const clockStatus = await CommonUtils.apiCall(window.config.clockStatusPath);

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
    } catch (error) {
        CommonUtils.handleApiError(error, '打刻状態取得');
    }
}

// 出勤打刻
async function clockIn() {
    if (!window.config.currentEmployeeId) return;

    try {
        const result = await CommonUtils.apiCall(window.config.clockInPath, {
            method: 'POST'
        });

        CommonUtils.showMessage(result.message, result.success ? 'success' : 'error');
        if (result.success) {
            updateClockButtons();
            loadAttendanceData();
        }
    } catch (error) {
        CommonUtils.handleApiError(error, '出勤打刻');
    }
}

// 退勤打刻
async function clockOut() {
    if (!window.config.currentEmployeeId) return;

    try {
        const result = await CommonUtils.apiCall(window.config.clockOutPath, {
            method: 'POST'
        });

        CommonUtils.showMessage(result.message, result.success ? 'success' : 'error');
        if (result.success) {
            updateClockButtons();
            loadAttendanceData();
        }
    } catch (error) {
        CommonUtils.handleApiError(error, '退勤打刻');
    }
}
