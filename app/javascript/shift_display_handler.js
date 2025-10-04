class ShiftDisplayHandler {
    constructor() {
        this.currentEmployeeId = null;
        this.isOwner = false;
        this.calendarYear = null;
        this.calendarMonth = null;
        this.allShiftsData = null;
        this.currentStartDate = null;
        this.daysInMonth = null;
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupEventListeners();
            this.checkOwnerPermissions();
            this.loadShifts();
        });
    }

    setupEventListeners() {
        // ボタンイベントの設定
        const requestListBtn = document.querySelector('[data-action="request-list"]');
        if (requestListBtn) {
            requestListBtn.addEventListener('click', () => this.goToRequestList());
        }

        const deletionFormBtn = document.querySelector('[data-action="deletion-form"]');
        if (deletionFormBtn) {
            deletionFormBtn.addEventListener('click', () => this.goToDeletionForm());
        }

        const shiftAddBtn = document.querySelector('[data-action="shift-add"]');
        if (shiftAddBtn) {
            shiftAddBtn.addEventListener('click', () => this.goToShiftAddForm());
        }

        const prevWeekBtn = document.querySelector('[data-action="prev-week"]');
        if (prevWeekBtn) {
            prevWeekBtn.addEventListener('click', () => this.prevWeek());
        }

        const nextWeekBtn = document.querySelector('[data-action="next-week"]');
        if (nextWeekBtn) {
            nextWeekBtn.addEventListener('click', () => this.nextWeek());
        }
    }

    setData(employeeId, isOwner) {
        this.currentEmployeeId = employeeId;
        this.isOwner = isOwner;
    }

    checkOwnerPermissions() {
        const shiftPageContainer = document.querySelector('.shift-page-container');
        if (!shiftPageContainer) return;

        shiftPageContainer.classList.remove('owner-mode', 'employee-mode');

        if (this.isOwner) {
            shiftPageContainer.classList.add('owner-mode');
            const shiftAddBtn = document.getElementById('shift-add-btn');
            if (shiftAddBtn) {
                shiftAddBtn.style.display = 'inline-block';
            }
            this.loadEmployeeList();
        } else {
            shiftPageContainer.classList.add('employee-mode');
            const shiftAddBtn = document.getElementById('shift-add-btn');
            if (shiftAddBtn) {
                shiftAddBtn.style.display = 'none';
            }
            this.loadPersonalGauge();
        }
    }

    loadEmployeeList() {
        if (window.employeeListLoading) return;
        window.employeeListLoading = true;

        fetch('/employees/wages')
            .then(response => response.json())
            .then(employees => {
                const tbody = document.getElementById('employee-list-body');
                if (!tbody) return;

                tbody.innerHTML = '';

                if (employees && employees.length > 0) {
                    employees.forEach(employee => {
                        const row = document.createElement('tr');
                        row.innerHTML = `
              <td>${employee.display_name}</td>
              <td>
                <div class="wage-gauge" data-employee-id="${employee.id}">
                  <div class="gauge-container">
                    <div class="gauge-bar">
                      <div class="gauge-fill" style="width: 0%"></div>
                    </div>
                    <div class="gauge-text">読み込み中...</div>
                  </div>
                </div>
              </td>
            `;
                        tbody.appendChild(row);
                    });
                } else {
                    tbody.innerHTML = '<tr><td colspan="2">従業員情報がありません</td></tr>';
                }

                this.loadWageGauge();
            })
            .catch(error => {
                console.error('従業員一覧取得エラー:', error);
                const tbody = document.getElementById('employee-list-body');
                if (tbody) {
                    tbody.innerHTML = '<tr><td colspan="2">エラーが発生しました</td></tr>';
                }
            });
    }

    loadWageGauge() {
        fetch('/wages/all_wages')
            .then(response => response.json())
            .then(wages => {
                if (wages && wages.length > 0) {
                    wages.forEach(wage => {
                        this.updateWageGaugeForEmployee(wage.employee_id, wage);
                    });
                } else {
                    this.showEmptyWageData();
                }
            })
            .catch(error => {
                console.error('全従業員給与データ取得失敗:', error);
                this.showWageError();
            });
    }

    updateWageGaugeForEmployee(employeeId, wage) {
        const gauge = document.querySelector(`.wage-gauge[data-employee-id="${employeeId}"]`);
        if (!gauge) return;

        const gaugeFill = gauge.querySelector('.gauge-fill');
        const gaugeText = gauge.querySelector('.gauge-text');

        if (gaugeFill && gaugeText) {
            const percentage = Math.min((wage.total_wage / wage.target_wage) * 100, 100);
            gaugeFill.style.width = percentage + '%';
            gaugeText.innerHTML = `¥${wage.total_wage.toLocaleString()} / ¥${wage.target_wage.toLocaleString()}`;
        }
    }

    showEmptyWageData() {
        const gauges = document.querySelectorAll('.wage-gauge[data-employee-id]');
        gauges.forEach(gauge => {
            const gaugeText = gauge.querySelector('.gauge-text');
            if (gaugeText) {
                gaugeText.innerHTML = 'シフトデータがありません';
            }
        });
    }

    showWageError() {
        const gauges = document.querySelectorAll('.wage-gauge[data-employee-id]');
        gauges.forEach(gauge => {
            const gaugeText = gauge.querySelector('.gauge-text');
            if (gaugeText) {
                gaugeText.innerHTML = 'データ取得エラー';
            }
        });
    }

    loadPersonalGauge() {
        if (!this.currentEmployeeId) return;

        fetch(`/wages/personal_wage?employee_id=${this.currentEmployeeId}`)
            .then(response => response.json())
            .then(wage => {
                this.updatePersonalGauge(wage);
            })
            .catch(error => {
                console.error('個人給与データ取得失敗:', error);
                this.showPersonalGaugeError();
            });
    }

    updatePersonalGauge(wage) {
        const gauge = document.querySelector('.personal-wage-gauge');
        if (!gauge) return;

        const gaugeFill = gauge.querySelector('.gauge-fill');
        const gaugeText = gauge.querySelector('.gauge-text');

        if (gaugeFill && gaugeText) {
            const percentage = Math.min((wage.total_wage / wage.target_wage) * 100, 100);
            gaugeFill.style.width = percentage + '%';
            gaugeText.innerHTML = `¥${wage.total_wage.toLocaleString()} / ¥${wage.target_wage.toLocaleString()}`;
        }
    }

    showPersonalGaugeError() {
        const gaugeText = document.querySelector('.personal-wage-gauge .gauge-text');
        if (gaugeText) {
            gaugeText.innerHTML = 'データ取得エラー';
        }
    }

    loadShifts() {
        const currentDate = new Date();
        this.calendarYear = currentDate.getFullYear();
        this.calendarMonth = currentDate.getMonth() + 1;
        this.updateCalendar();
    }

    updateCalendar() {
        const currentDate = new Date(this.calendarYear, this.calendarMonth - 1, 1);
        this.currentStartDate = new Date(currentDate);
        this.currentStartDate.setDate(this.currentStartDate.getDate() - this.currentStartDate.getDay());

        this.daysInMonth = new Date(this.calendarYear, this.calendarMonth, 0).getDate();

        this.loadShiftsData();
    }

    loadShiftsData() {
        const startDate = this.currentStartDate.toISOString().split('T')[0];
        const endDate = new Date(this.currentStartDate);
        endDate.setDate(endDate.getDate() + 41);
        const endDateStr = endDate.toISOString().split('T')[0];

        fetch(`/shifts?start_date=${startDate}&end_date=${endDateStr}`)
            .then(response => response.json())
            .then(data => {
                this.allShiftsData = data;
                this.renderCalendar();
            })
            .catch(error => {
                console.error('シフトデータ取得エラー:', error);
                this.showShiftError();
            });
    }

    renderCalendar() {
        const calendarBody = document.getElementById('calendar-body');
        if (!calendarBody) return;

        calendarBody.innerHTML = '';

        for (let week = 0; week < 6; week++) {
            const weekRow = document.createElement('tr');

            for (let day = 0; day < 7; day++) {
                const cellDate = new Date(this.currentStartDate);
                cellDate.setDate(cellDate.getDate() + (week * 7) + day);

                const cell = document.createElement('td');
                cell.className = 'calendar-cell';

                if (cellDate.getMonth() === this.calendarMonth - 1) {
                    cell.classList.add('current-month');
                }

                cell.innerHTML = `
          <div class="date">${cellDate.getDate()}</div>
          <div class="shifts" data-date="${cellDate.toISOString().split('T')[0]}"></div>
        `;

                weekRow.appendChild(cell);
            }

            calendarBody.appendChild(weekRow);
        }

        this.renderShifts();
    }

    renderShifts() {
        if (!this.allShiftsData) return;

        this.allShiftsData.forEach(shift => {
            const shiftElement = document.querySelector(`[data-date="${shift.shift_date}"]`);
            if (shiftElement) {
                const shiftDiv = document.createElement('div');
                shiftDiv.className = 'shift-item';
                shiftDiv.innerHTML = `
          <div class="shift-time">${shift.start_time} - ${shift.end_time}</div>
          <div class="shift-employee">${shift.employee_name}</div>
        `;
                shiftElement.appendChild(shiftDiv);
            }
        });
    }

    showShiftError() {
        const calendarBody = document.getElementById('calendar-body');
        if (calendarBody) {
            calendarBody.innerHTML = '<tr><td colspan="7" class="text-center padding-20 text-red">シフトデータの取得に失敗しました</td></tr>';
        }
    }

    prevWeek() {
        this.currentStartDate.setDate(this.currentStartDate.getDate() - 7);
        this.renderCalendar();
    }

    nextWeek() {
        this.currentStartDate.setDate(this.currentStartDate.getDate() + 7);
        this.renderCalendar();
    }

    goToRequestList() {
        window.location.href = '/shift_approvals';
    }

    goToDeletionForm() {
        window.location.href = '/shift_deletions/new';
    }

    goToShiftAddForm() {
        window.location.href = '/shift_additions/new';
    }
}

// グローバルインスタンスを作成
window.shiftDisplayHandler = new ShiftDisplayHandler();
