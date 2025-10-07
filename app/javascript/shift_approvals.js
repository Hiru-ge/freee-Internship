// シフト承認関連のJS機能

// シフト承認処理
function handleApprove(requestType, requestId, employeeId) {
    const formData = new FormData();
    formData.append('request_id', requestId);
    formData.append('request_type', requestType);
    formData.append('employee_id', employeeId);

    CommonUtils.apiCall('/shift/approve', {
        method: 'POST',
        body: formData
    }).then(response => {
        CommonUtils.showMessage('リクエストを承認しました', 'success');
        hideRequestElement(requestId);
    }).catch(error => {
        CommonUtils.handleApiError(error, '承認処理');
    });
}

// シフト否認処理
function handleDeny(requestType, requestId, employeeId) {
    const formData = new FormData();
    formData.append('request_id', requestId);
    formData.append('request_type', requestType);
    formData.append('employee_id', employeeId);

    CommonUtils.apiCall('/shift/reject', {
        method: 'POST',
        body: formData
    }).then(response => {
        CommonUtils.showMessage('リクエストを否認しました', 'success');
        hideRequestElement(requestId);
    }).catch(error => {
        CommonUtils.handleApiError(error, '否認処理');
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
