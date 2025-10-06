// シフト交代のJavaScript

// グローバル変数
let config = {};

// 初期化
CommonUtils.initializePage(() => {
    loadConfig();
    setupFormHandler();
    loadEmployees();
});

// 設定の読み込み
function loadConfig() {
    const configMap = {
        applicantIdFromUrl: 'applicantId',
        dateFromUrl: 'date',
        startFromUrl: 'startTime',
        endFromUrl: 'endTime',
        employees: 'employees'
    };

    config = CommonUtils.loadConfigFromContainer('.form-container', configMap);
}

// フォームハンドラーの設定
function setupFormHandler() {
    CommonUtils.setupFormSubmission('#request-form', validateForm, handleFormSuccess);
}

// フォームバリデーション
function validateForm() {
    const selectedEmployees = getSelectedEmployees();
    if (selectedEmployees.length === 0) {
        CommonUtils.showMessage('交代を依頼する相手を選択してください。複数の人に同時に依頼することも可能です。', 'error');
        return false;
    }
    return true;
}

// フォーム送信成功時の処理
function handleFormSuccess(response) {
    CommonUtils.showMessage('シフト交代リクエストを送信しました', 'success');
    // 必要に応じてリダイレクト処理
}

// 従業員リストを読み込んで表示
function loadEmployees() {
    const employeeList = document.getElementById('employee-list');

    if (!config.employees || config.employees.length === 0) {
        employeeList.innerHTML = '<p style="color: #f44336;">従業員情報の読み込みに失敗しました。</p>';
        return;
    }

    let html = '';
    config.employees.forEach(employee => {
        // 申請者自身は除外
        if (employee.id === config.applicantIdFromUrl) {
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

// showMessage関数はCommonUtilsを使用
