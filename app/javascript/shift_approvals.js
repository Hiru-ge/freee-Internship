// シフト承認関連のJS機能

// シフト承認処理
function handleApprove(requestType, requestId, employeeId) {
    const formData = new FormData();
    formData.append('request_id', requestId);
    formData.append('request_type', requestType);
    formData.append('employee_id', employeeId);

    // ローディング表示
    if (window.loadingHandler) {
        window.loadingHandler.show('承認処理中...');
    }

    CommonUtils.apiCall('/shift/approve', {
        method: 'POST',
        body: formData
    }).then(response => {
        // レスポンスの成功判定
        if (response && response.success) {
            CommonUtils.showMessage(response.message || 'リクエストを承認しました', 'success');
            hideRequestElement(requestId);
        } else {
            CommonUtils.showMessage(response?.message || '承認に失敗しました', 'error');
        }
    }).catch(error => {
        CommonUtils.handleApiError(error, '承認処理');
    }).finally(() => {
        // ローディング非表示
        if (window.loadingHandler) {
            window.loadingHandler.hide();
        }
    });
}

// シフト否認処理
function handleDeny(requestType, requestId, employeeId) {
    const formData = new FormData();
    formData.append('request_id', requestId);
    formData.append('request_type', requestType);
    formData.append('employee_id', employeeId);

    // ローディング表示
    if (window.loadingHandler) {
        window.loadingHandler.show('否認処理中...');
    }

    CommonUtils.apiCall('/shift/reject', {
        method: 'POST',
        body: formData
    }).then(response => {
        // レスポンスの成功判定
        if (response && response.success) {
            CommonUtils.showMessage(response.message || 'リクエストを否認しました', 'success');
            hideRequestElement(requestId);
        } else {
            CommonUtils.showMessage(response?.message || '否認に失敗しました', 'error');
        }
    }).catch(error => {
        CommonUtils.handleApiError(error, '否認処理');
    }).finally(() => {
        // ローディング非表示
        if (window.loadingHandler) {
            window.loadingHandler.hide();
        }
    });
}

// リクエスト要素を非表示にする共通関数
function hideRequestElement(requestId) {
    const requestElement = document.getElementById(`req-${requestId}`);
    if (requestElement) {
        requestElement.style.display = 'none';
    }
}

// グローバルに公開
window.handleApprove = handleApprove;
window.handleDeny = handleDeny;
