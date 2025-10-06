// シフト交代のJavaScript

// グローバル変数
let applicantIdFromUrl;
let dateFromUrl;
let startFromUrl;
let endFromUrl;
let employees;

// 初期化
document.addEventListener('DOMContentLoaded', function () {
    loadConfig();
    setupFormHandler();
    loadEmployees();
});

// 設定の読み込み
function loadConfig() {
    const container = document.querySelector('.form-container');
    if (!container) return;

    applicantIdFromUrl = container.dataset.applicantId;
    dateFromUrl = container.dataset.date;
    startFromUrl = container.dataset.startTime;
    endFromUrl = container.dataset.endTime;
    employees = JSON.parse(container.dataset.employees || '[]');
}

// フォームハンドラーの設定
function setupFormHandler() {
    document.getElementById('request-form').addEventListener('submit', function (e) {
        const selectedEmployees = getSelectedEmployees();

        if (selectedEmployees.length === 0) {
            e.preventDefault();
            showMessage('交代を依頼する相手を選択してください。複数の人に同時に依頼することも可能です。', 'error');
            return;
        }

        // 選択された従業員IDをhiddenフィールドに設定
        selectedEmployees.forEach(employeeId => {
            const hiddenInput = document.createElement('input');
            hiddenInput.type = 'hidden';
            hiddenInput.name = 'approver_ids[]';
            hiddenInput.value = employeeId;
            e.target.appendChild(hiddenInput);
        });

        // ローディング表示
        if (window.loadingHandler) {
            window.loadingHandler.show('リクエスト送信中...');
        } else {
            const submitButton = document.querySelector('button[type="submit"]');
            submitButton.disabled = true;
            submitButton.textContent = '送信中...';
        }
    });
}

// 従業員リストを読み込んで表示
function loadEmployees() {
    const employeeList = document.getElementById('employee-list');

    if (!employees || employees.length === 0) {
        employeeList.innerHTML = '<p style="color: #f44336;">従業員情報の読み込みに失敗しました。</p>';
        return;
    }

    let html = '';
    employees.forEach(employee => {
        // 申請者自身は除外
        if (employee.id === applicantIdFromUrl) {
            return;
        }

        html += '<div class="form-checkbox-item">';
        html += '<input type="checkbox" id="employee-' + employee.id + '" value="' + employee.id + '">';
        html += '<label for="employee-' + employee.id + '">' + employee.display_name + '</label>';
        html += '</div>';
    });

    employeeList.innerHTML = html;
}

// 選択された従業員IDの配列を取得
function getSelectedEmployees() {
    const checkboxes = document.querySelectorAll('#employee-list input[type="checkbox"]:checked');
    const selectedIds = [];

    checkboxes.forEach(checkbox => {
        selectedIds.push(checkbox.value);
    });

    return selectedIds;
}

// 戻るボタンの処理
function goBack() {
    if (window.history.length > 1) {
        window.history.back();
    } else {
        window.location.href = '/shifts';
    }
}

function showMessage(message, type) {
    if (window.messageHandler) {
        return window.messageHandler.show(message, type);
    }
}
