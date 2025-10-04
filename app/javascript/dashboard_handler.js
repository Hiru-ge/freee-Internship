class DashboardHandler {
    constructor() {
        this.currentEmployeeId = null;
        this.currentEmployeeName = null;
        this.attendanceYear = new Date().getFullYear();
        this.attendanceMonth = new Date().getMonth() + 1;
        this.allAttendanceData = null;
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupEventListeners();
            this.updateClockButtons();
            this.initializeAttendanceHistory();
        });
    }

    setupEventListeners() {
        // 打刻ボタンのイベント設定
        const clockInBtn = document.getElementById('clock-in-btn');
        if (clockInBtn) {
            clockInBtn.addEventListener('click', () => this.clockIn());
        }

        const clockOutBtn = document.getElementById('clock-out-btn');
        if (clockOutBtn) {
            clockOutBtn.addEventListener('click', () => this.clockOut());
        }

        // 月ナビゲーションボタンのイベント設定
        const prevMonthBtn = document.querySelector('[data-action="prev-month"]');
        if (prevMonthBtn) {
            prevMonthBtn.addEventListener('click', () => this.prevMonth());
        }

        const nextMonthBtn = document.querySelector('[data-action="next-month"]');
        if (nextMonthBtn) {
            nextMonthBtn.addEventListener('click', () => this.nextMonth());
        }
    }

    setData(employeeId, employeeName) {
        this.currentEmployeeId = employeeId;
        this.currentEmployeeName = employeeName;
    }

    initializeAttendanceHistory() {
        if (!this.currentEmployeeId) {
            this.showAttendanceError('従業員IDが取得できません');
            return;
        }
        this.loadAttendanceData();
    }

    loadAttendanceData() {
        const yearMonth = this.attendanceYear + '-' + String(this.attendanceMonth).padStart(2, '0');

        fetch(`/attendance/history?year=${this.attendanceYear}&month=${this.attendanceMonth}`)
            .then(response => response.json())
            .then(data => {
                this.displayAttendanceData(data);
            })
            .catch(error => {
                this.showAttendanceError('勤怠データの取得に失敗しました: ' + error.message);
            });
    }

    displayAttendanceData(attendanceRecords) {
        try {
            const attendanceContainer = document.getElementById('attendance-container');
            const title = document.getElementById('attendance-title');

            if (!attendanceContainer || !title) return;

            title.innerHTML = `
        <h3>勤怠履歴 (${this.attendanceYear}年${this.attendanceMonth}月)</h3>
        <div class="attendance-nav">
          <button class="button" data-action="prev-month">前月</button>
          <button class="button" data-action="next-month">次月</button>
        </div>
      `;

            let html = '<table class="attendance-table">';
            html += '<thead><tr><th>種別</th><th>日時</th></tr></thead>';
            html += '<tbody>';

            if (!attendanceRecords || attendanceRecords.length === 0) {
                html += '<tr><td colspan="2" class="text-center padding-40 color-gray">この月の勤怠記録がありません</td></tr>';
            } else {
                attendanceRecords.forEach(record => {
                    html += '<tr>';
                    html += '<td>' + record.type + '</td>';
                    html += '<td>' + record.timestamp + '</td>';
                    html += '</tr>';
                });
            }

            html += '</tbody></table>';
            attendanceContainer.innerHTML = html;

            // イベントリスナーを再設定
            this.setupEventListeners();
        } catch (error) {
            console.error('勤怠データ表示エラー:', error);
            this.showAttendanceError('勤怠データの表示に失敗しました');
        }
    }

    showAttendanceError(message) {
        const container = document.getElementById('attendance-container');
        if (container) {
            container.innerHTML = '<p class="text-red text-center padding-20">' + message + '</p>';
        }
    }

    updateClockButtons() {
        if (!this.currentEmployeeId) return;

        fetch('/attendance/status')
            .then(response => response.json())
            .then(data => {
                const clockInBtn = document.getElementById('clock-in-btn');
                const clockOutBtn = document.getElementById('clock-out-btn');

                if (data.can_clock_in) {
                    if (clockInBtn) {
                        clockInBtn.disabled = false;
                        clockInBtn.textContent = '出勤';
                    }
                    if (clockOutBtn) {
                        clockOutBtn.disabled = true;
                        clockOutBtn.textContent = '退勤（出勤後に利用可能）';
                    }
                } else {
                    if (clockInBtn) {
                        clockInBtn.disabled = true;
                        clockInBtn.textContent = '出勤（既に出勤済み）';
                    }
                    if (clockOutBtn) {
                        clockOutBtn.disabled = false;
                        clockOutBtn.textContent = '退勤';
                    }
                }
            })
            .catch(error => {
                console.error('勤怠状態取得エラー:', error);
                this.showMessage('勤怠状態の取得に失敗しました', 'error');
            });
    }

    clockIn() {
        if (!this.currentEmployeeId) {
            this.showMessage('従業員IDが取得できません', 'error');
            return;
        }

        if (window.loadingHandler) {
            window.loadingHandler.show('出勤打刻処理中...');
        }

        fetch('/attendance/clock_in', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
            },
            body: JSON.stringify({
                employee_id: this.currentEmployeeId
            })
        })
            .then(response => response.json())
            .then(data => {
                if (window.loadingHandler) {
                    window.loadingHandler.hide();
                }

                if (data.success) {
                    this.showMessage('出勤打刻が完了しました', 'success');
                    this.updateClockButtons();
                    this.loadAttendanceData();
                } else {
                    this.showMessage(data.message || '出勤打刻に失敗しました', 'error');
                }
            })
            .catch(error => {
                if (window.loadingHandler) {
                    window.loadingHandler.hide();
                }
                console.error('出勤打刻エラー:', error);
                this.showMessage('出勤打刻でエラーが発生しました', 'error');
            });
    }

    clockOut() {
        if (!this.currentEmployeeId) {
            this.showMessage('従業員IDが取得できません', 'error');
            return;
        }

        if (window.loadingHandler) {
            window.loadingHandler.show('退勤打刻処理中...');
        }

        fetch('/attendance/clock_out', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
            },
            body: JSON.stringify({
                employee_id: this.currentEmployeeId
            })
        })
            .then(response => response.json())
            .then(data => {
                if (window.loadingHandler) {
                    window.loadingHandler.hide();
                }

                if (data.success) {
                    this.showMessage('退勤打刻が完了しました', 'success');
                    this.updateClockButtons();
                    this.loadAttendanceData();
                } else {
                    this.showMessage(data.message || '退勤打刻に失敗しました', 'error');
                }
            })
            .catch(error => {
                if (window.loadingHandler) {
                    window.loadingHandler.hide();
                }
                console.error('退勤打刻エラー:', error);
                this.showMessage('退勤打刻でエラーが発生しました', 'error');
            });
    }

    prevMonth() {
        this.attendanceMonth--;
        if (this.attendanceMonth < 1) {
            this.attendanceMonth = 12;
            this.attendanceYear--;
        }
        this.loadAttendanceData();
    }

    nextMonth() {
        this.attendanceMonth++;
        if (this.attendanceMonth > 12) {
            this.attendanceMonth = 1;
            this.attendanceYear++;
        }
        this.loadAttendanceData();
    }

    showMessage(message, type) {
        if (window.messageHandler) {
            window.messageHandler.show(message, type);
        } else {
            const messageDiv = document.getElementById('message');
            if (messageDiv) {
                messageDiv.textContent = message;
                messageDiv.className = 'message ' + type;
                messageDiv.style.display = 'block';
                setTimeout(() => {
                    messageDiv.style.display = 'none';
                }, 5000);
            }
        }
    }
}

// グローバルインスタンスを作成
window.dashboardHandler = new DashboardHandler();
