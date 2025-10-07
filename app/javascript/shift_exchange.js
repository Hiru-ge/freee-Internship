// シフト交代のJavaScript

// CommonUtilsが利用可能になるまで待機して初期化
function waitForCommonUtilsForExchange() {
    if (typeof CommonUtils !== 'undefined') {
        CommonUtils.initializePageWithConfig('shiftExchange', '.form-container', [
            setupFormHandler,
            loadEmployees
        ]);
    } else {
        setTimeout(waitForCommonUtilsForExchange, 100);
    }
}

document.addEventListener('DOMContentLoaded', waitForCommonUtilsForExchange);

// フォームハンドラーの設定
function setupFormHandler() {
    CommonUtils.setupFormSubmission('#request-form', () => {
        const isValid = validateForm();
        if (!isValid) return false;
        if (window.loadingHandler) {
            window.loadingHandler.show('リクエストを送信しています...');
        }
        return true;
    }, (response) => {
        if (window.loadingHandler) {
            window.loadingHandler.hide();
        }
        handleFormSuccess(response);
    });
}

// フォームバリデーション
function validateForm() {
    const checkboxValidation = CommonUtils.validateCheckboxSelection('#employee-list input[type="checkbox"]', 1);
    if (!checkboxValidation.valid) {
        CommonUtils.showMessage('交代を依頼する相手を選択してください。複数の人に同時に依頼することも可能です。', 'error');
        return false;
    }
    return true;
}

// フォーム送信成功時の処理
function handleFormSuccess(response) {
    // サービスからのメッセージを使用（重複チェック結果を含む）
    const message = response?.message || 'シフト交代リクエストを送信しました';
    CommonUtils.showMessage(message, 'success');
    // 少し待ってからシフトページへリダイレクト
    setTimeout(() => {
        window.location.href = '/shifts';
    }, 600);
}

// 従業員リストを読み込んで表示
function loadEmployees() {
    const employeeList = document.getElementById('employee-list');

    // data-attributesからの取り込みでJSON文字列になっている可能性があるためパース
    let employees = window.config.employees;
    if (typeof employees === 'string') {
        try {
            employees = JSON.parse(employees);
        } catch (e) {
            employeeList.innerHTML = '<p style="color: #f44336;">従業員情報の解析に失敗しました。</p>';
            return;
        }
    }

    if (!Array.isArray(employees) || employees.length === 0) {
        employeeList.innerHTML = '<p style="color: #f44336;">従業員情報の読み込みに失敗しました。</p>';
        return;
    }

    let html = '';
    // 申請者IDの特定（data属性 or hidden input）
    const applicantId = window.config.applicantId || window.config.applicantIdFromUrl || document.getElementById('applicant-select')?.value;

    employees.forEach(employee => {
        // 申請者自身は除外
        if (String(employee.id) === String(applicantId)) {
            return;
        }

        html += '<div class="form-checkbox-item employee-option">';
        html += '<input type="checkbox" id="employee-' + employee.id + '" name="approver_ids[]" value="' + employee.id + '">';
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
