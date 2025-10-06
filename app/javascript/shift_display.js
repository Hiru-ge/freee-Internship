// シフト表示のJavaScript

// グローバル変数
let currentEmployeeId;
let isOwner;
let shiftsDataPath;
let employeesWagesPath;
let allWagesPath;
let wageInfoPath;
let newShiftExchangePath;
let newShiftDeletionPath;
let shiftApprovalsPath;
let newShiftAdditionPath;

let calendarYear;
let calendarMonth;
let allShiftsData;
let currentStartDate;
let daysInMonth;

// 初期化
document.addEventListener('DOMContentLoaded', function () {
    loadConfig();
    checkOwnerPermissions();
    loadShifts();
});

// 設定の読み込み
function loadConfig() {
    const container = document.querySelector('.shift-page-container');
    if (!container) return;

    currentEmployeeId = container.dataset.employeeId;
    isOwner = container.dataset.isOwner === 'true';
    shiftsDataPath = container.dataset.shiftsDataPath;
    employeesWagesPath = container.dataset.employeesWagesPath;
    allWagesPath = container.dataset.allWagesPath;
    wageInfoPath = container.dataset.wageInfoPath;
    newShiftExchangePath = container.dataset.newShiftExchangePath;
    newShiftDeletionPath = container.dataset.newShiftDeletionPath;
    shiftApprovalsPath = container.dataset.shiftApprovalsPath;
    newShiftAdditionPath = container.dataset.newShiftAdditionPath;
}

// オーナー権限チェック
function checkOwnerPermissions() {
    const shiftPageContainer = document.querySelector('.shift-page-container');
    shiftPageContainer.classList.remove('owner-mode', 'employee-mode');

    if (isOwner) {
        shiftPageContainer.classList.add('owner-mode');
        document.getElementById('shift-add-btn').style.display = 'inline-block';
        loadEmployeeList();
    } else {
        shiftPageContainer.classList.add('employee-mode');
        document.getElementById('shift-add-btn').style.display = 'none';
        loadPersonalGauge();
    }
}

// 従業員一覧の読み込み（オーナーのみ）
function loadEmployeeList() {
    if (window.employeeListLoading) return;
    window.employeeListLoading = true;

    fetch(employeesWagesPath)
        .then(response => response.json())
        .then(employees => {
            const tbody = document.getElementById('employee-list-body');
            tbody.innerHTML = '';

            if (employees && employees.length > 0) {
                employees.forEach(employee => {
                    const row = document.createElement('tr');
                    row.innerHTML =
                        '<td>' + employee.display_name + '</td>' +
                        '<td><div class="wage-gauge" data-employee-id="' + employee.id + '">' +
                        '<div class="gauge-container">' +
                        '<div class="gauge-bar"><div class="gauge-fill" style="width: 0%"></div></div>' +
                        '<div class="gauge-text">読み込み中...</div>' +
                        '</div></div></td>';
                    tbody.appendChild(row);
                });
            } else {
                tbody.innerHTML = '<tr><td colspan="2">従業員情報がありません</td></tr>';
            }

            loadWageGauge();
        })
        .catch(error => {
            console.error('従業員一覧取得エラー:', error);
            document.getElementById('employee-list-body').innerHTML = '<tr><td colspan="2">エラーが発生しました</td></tr>';
        });
}

// 給与ゲージの読み込み（オーナーのみ）
function loadWageGauge() {
    fetch(allWagesPath)
        .then(response => response.json())
        .then(wages => {
            if (wages && wages.length > 0) {
                wages.forEach(wage => {
                    updateWageGaugeForEmployee(wage.employee_id, wage);
                });
            } else {
                const gauges = document.querySelectorAll('.wage-gauge[data-employee-id]');
                gauges.forEach(gauge => {
                    const gaugeText = gauge.querySelector('.gauge-text');
                    if (gaugeText) {
                        gaugeText.innerHTML = 'シフトデータがありません';
                    }
                });
            }
        })
        .catch(error => {
            console.error('全従業員給与データ取得失敗:', error);
            const gauges = document.querySelectorAll('.wage-gauge[data-employee-id]');
            gauges.forEach(gauge => {
                const gaugeText = gauge.querySelector('.gauge-text');
                if (gaugeText) {
                    gaugeText.innerHTML = 'エラー: 給与データの取得に失敗しました<br>' + error.message;
                }
            });
        });
}

// 個人の給与ゲージの読み込み（従業員のみ）
function loadPersonalGauge() {
    const gaugeText = document.querySelector('#personal-wage-gauge .gauge-text');
    if (gaugeText) {
        gaugeText.textContent = '読み込み中...';
    }

    fetch(`${wageInfoPath}?employee_id=${currentEmployeeId}`)
        .then(response => response.json())
        .then(wageInfo => {
            updatePersonalWageGauge(wageInfo);
        })
        .catch(error => {
            console.error('給与情報取得エラー:', error);
            if (currentEmployeeId) {
                document.querySelector('#personal-wage-gauge .gauge-text').textContent = 'エラーが発生しました';
            }
        });
}

// シフト情報の読み込み
function loadShifts() {
    const shiftCalendarContainer = document.getElementById('shift-calendar-container');
    shiftCalendarContainer.innerHTML = '<p>シフト情報を読み込んでいます...</p>';

    fetch(shiftsDataPath)
        .then(response => response.json())
        .then(data => {
            initializeShifts(data);
        })
        .catch(error => {
            console.error('シフト情報取得エラー:', error);
            shiftCalendarContainer.innerHTML = '<p>シフト情報の取得に失敗しました</p>';
        });
}

function initializeShifts(dataFromServer) {
    allShiftsData = dataFromServer;

    calendarYear = allShiftsData.year;
    calendarMonth = allShiftsData.month;
    daysInMonth = new Date(calendarYear, calendarMonth, 0).getDate();

    const now = new Date();
    const today = now.getDate();
    const dayOfWeek = now.getDay();

    const startOfWeek = today - (dayOfWeek === 0 ? 6 : dayOfWeek - 1);
    currentStartDate = new Date(now.getFullYear(), now.getMonth(), startOfWeek);

    updateCalendarTitle();
    displayShifts();
}

function updateCalendarTitle() {
    const title = document.getElementById('calendar-title');
    title.textContent = calendarYear + '年' + calendarMonth + '月';
}

function displayShifts() {
    const titleEl = document.getElementById('calendar-title');
    titleEl.textContent = calendarYear + '年' + calendarMonth + '月';

    const shiftCalendarContainer = document.getElementById('shift-calendar-container');
    if (!shiftCalendarContainer) {
        console.error('shift-calendar-container要素が見つかりません');
        return;
    }
    shiftCalendarContainer.innerHTML = "";

    const table = document.createElement('table');
    table.className = 'shift-calendar';
    const thead = document.createElement('thead');
    const tbody = document.createElement('tbody');

    const headerRow = document.createElement('tr');
    const nameHeader = document.createElement('th');
    nameHeader.textContent = '従業員名';
    headerRow.appendChild(nameHeader);

    const datesToShow = [];
    const currentMonth = currentStartDate.getMonth();
    const currentYear = currentStartDate.getFullYear();
    const lastDayOfMonth = new Date(currentYear, currentMonth + 1, 0).getDate();

    const lastDayOfDisplayedPeriod = currentStartDate.getDate() + 6;
    const isLastPage = lastDayOfDisplayedPeriod >= lastDayOfMonth;

    if (isLastPage) {
        const startDay = Math.max(1, lastDayOfMonth - 6);
        for (let day = startDay; day <= lastDayOfMonth; day++) {
            datesToShow.push({
                day: day,
                month: currentMonth,
                year: currentYear,
                displayText: day + '日'
            });
            const dayHeader = document.createElement('th');
            dayHeader.textContent = day + '日';
            headerRow.appendChild(dayHeader);
        }
    } else {
        const currentDate = new Date(currentStartDate);
        for (let i = 0; i < 7; i++) {
            const day = currentDate.getDate();
            const month = currentDate.getMonth();
            const year = currentDate.getFullYear();

            if (month === currentMonth && year === currentYear) {
                datesToShow.push({
                    day: day,
                    month: month,
                    year: year,
                    displayText: day + '日'
                });
                const dayHeader = document.createElement('th');
                dayHeader.textContent = day + '日';
                headerRow.appendChild(dayHeader);
            }
            currentDate.setDate(currentDate.getDate() + 1);
        }
    }
    thead.appendChild(headerRow);

    for (const employeeId in allShiftsData.shifts) {
        const employeeData = allShiftsData.shifts[employeeId];
        const employeeRow = document.createElement('tr');
        const nameCell = document.createElement('td');
        nameCell.textContent = employeeData.name;
        employeeRow.appendChild(nameCell);

        datesToShow.forEach(dateInfo => {
            const shiftCell = document.createElement('td');
            const shiftTime = employeeData.shifts[dateInfo.day] || "";
            if (shiftTime) {
                if (String(employeeId) === String(currentEmployeeId)) {
                    const times = shiftTime.split('-');
                    const startTime = times[0].padStart(2, '0') + ':00';
                    const endTime = times[1].padStart(2, '0') + ':00';
                    const monthStr = String(calendarMonth).padStart(2, '0');
                    const dayStr = String(dateInfo.day).padStart(2, '0');
                    const dateStr = calendarYear + '-' + monthStr + '-' + dayStr;

                    const baseUrl = newShiftExchangePath;
                    const params = '?applicant_id=' + encodeURIComponent(employeeId) +
                        '&date=' + encodeURIComponent(dateStr) +
                        '&start=' + encodeURIComponent(startTime) +
                        '&end=' + encodeURIComponent(endTime);
                    const linkUrl = baseUrl + params;

                    const link = document.createElement('a');
                    link.href = linkUrl;
                    link.textContent = shiftTime;
                    link.style.color = '#ffca28';
                    link.style.textDecoration = 'none';
                    link.style.cursor = 'pointer';
                    link.title = 'クリックしてシフト交代を依頼';

                    shiftCell.appendChild(link);
                } else {
                    shiftCell.style.cursor = 'default';
                    shiftCell.style.color = '#999';
                    shiftCell.title = '他の人のシフトはクリックできません';
                    shiftCell.textContent = shiftTime;
                }
            } else {
                shiftCell.textContent = '';
            }
            employeeRow.appendChild(shiftCell);
        });
        tbody.appendChild(employeeRow);
    }

    table.appendChild(thead);
    table.appendChild(tbody);
    shiftCalendarContainer.appendChild(table);

    updatePaginationButtons();
}

function updatePaginationButtons() {
    const prevBtn = document.querySelector('.month-navigation .button:first-of-type');
    const nextBtn = document.querySelector('.month-navigation .button:last-of-type');

    if (currentStartDate.getDate() === 1) {
        prevBtn.disabled = true;
        prevBtn.style.opacity = '0.5';
    } else {
        prevBtn.disabled = false;
        prevBtn.style.opacity = '1.0';
    }

    const lastDayOfDisplayedPeriod = currentStartDate.getDate() + 6;
    const lastDayOfMonth = new Date(currentStartDate.getFullYear(), currentStartDate.getMonth() + 1, 0).getDate();

    if (lastDayOfDisplayedPeriod >= lastDayOfMonth) {
        nextBtn.disabled = true;
        nextBtn.style.opacity = '0.5';
    } else {
        nextBtn.disabled = false;
        nextBtn.style.opacity = '1.0';
    }
}

function prevWeek() {
    if (currentStartDate.getDate() > 1) {
        currentStartDate.setDate(currentStartDate.getDate() - 7);
        displayShifts();
    }
}

function nextWeek() {
    const nextWeekStart = new Date(currentStartDate);
    nextWeekStart.setDate(currentStartDate.getDate() + 7);

    if (nextWeekStart.getMonth() === currentStartDate.getMonth()) {
        currentStartDate = nextWeekStart;
        displayShifts();
    }
}

// ナビゲーション関数
function goToDeletionForm() {
    window.location.href = newShiftDeletionPath;
}

function goToRequestList() {
    window.location.href = shiftApprovalsPath;
}

function goToShiftAddForm() {
    window.location.href = newShiftAdditionPath;
}

// 個人の給与ゲージの更新
function updatePersonalWageGauge(wageInfo) {
    const gaugeElement = document.getElementById('personal-wage-gauge');
    if (!gaugeElement) return;

    const gaugeFill = gaugeElement.querySelector('.gauge-fill');
    const gaugeText = gaugeElement.querySelector('.gauge-text');

    if (!wageInfo || wageInfo.wage === undefined || wageInfo.target === undefined) {
        gaugeText.textContent = 'データがありません';
        return;
    }

    const percentage = Math.min(wageInfo.percentage, 100);
    const wageFormatted = (wageInfo.wage / 10000).toFixed(1) + '万円';
    const targetFormatted = (wageInfo.target / 10000).toFixed(0) + '万円';

    gaugeFill.style.width = percentage + '%';

    if (percentage >= 100) {
        gaugeFill.style.backgroundColor = '#ff4444';
        gaugeText.innerHTML = wageFormatted + ' / ' + targetFormatted + '<br>🎉 目標達成！';
    } else if (percentage >= 80) {
        gaugeFill.style.backgroundColor = '#ffaa44';
        gaugeText.innerHTML = wageFormatted + ' / ' + targetFormatted + '<br>あと' + ((wageInfo.target - wageInfo.wage) / 10000).toFixed(1) + '万円';
    } else {
        gaugeFill.style.backgroundColor = '#44ff44';
        gaugeText.innerHTML = wageFormatted + ' / ' + targetFormatted + '<br>あと' + ((wageInfo.target - wageInfo.wage) / 10000).toFixed(1) + '万円';
    }
}

// 給与ゲージの更新（従業員指定）
function updateWageGaugeForEmployee(employeeId, wageInfo) {
    const gaugeElement = document.querySelector('.wage-gauge[data-employee-id="' + employeeId + '"]');
    if (!gaugeElement) return;

    const gaugeFill = gaugeElement.querySelector('.gauge-fill');
    const gaugeText = gaugeElement.querySelector('.gauge-text');

    const percentage = Math.min(wageInfo.percentage, 100);
    const wageFormatted = (wageInfo.wage / 10000).toFixed(1) + '万円';
    const targetFormatted = (wageInfo.target / 10000).toFixed(0) + '万円';

    gaugeFill.style.width = percentage + '%';

    if (percentage >= 100) {
        gaugeFill.style.backgroundColor = '#ff4444';
        gaugeText.innerHTML = wageFormatted + ' / ' + targetFormatted + '<br>🎉 目標達成！';
    } else if (percentage >= 80) {
        gaugeFill.style.backgroundColor = '#ffaa44';
        gaugeText.innerHTML = wageFormatted + ' / ' + targetFormatted + '<br>あと' + ((wageInfo.target - wageInfo.wage) / 10000).toFixed(1) + '万円';
    } else {
        gaugeFill.style.backgroundColor = '#44ff44';
        gaugeText.innerHTML = wageFormatted + ' / ' + targetFormatted + '<br>あと' + ((wageInfo.target - wageInfo.wage) / 10000).toFixed(1) + '万円';
    }
}

function showMessage(message, type) {
    if (window.messageHandler) {
        return window.messageHandler.show(message, type);
    }
}
