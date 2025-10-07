// シフト承認関連のJS機能

// シフト承認処理
function handleApprove(requestType, requestId, employeeId) {
    if (window.loadingHandler) {
        window.loadingHandler.show('承認処理中...');
    }

    const formData = new FormData();
    formData.append('request_id', requestId);
    formData.append('request_type', requestType);
    formData.append('employee_id', employeeId);

    fetch('/shift/approve', {
        method: 'POST',
        headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: formData
    })
        .then(response => {
            if (response.ok) {
                if (window.messageHandler) {
                    window.messageHandler.show('リクエストを承認しました', 'success');
                }
                // 承認されたリクエストを非表示にする
                const requestElement = document.getElementById(`req-${requestId}`);
                if (requestElement) {
                    requestElement.style.display = 'none';
                }
            } else {
                throw new Error('承認に失敗しました');
            }
        })
        .catch(error => {
            if (window.messageHandler) {
                window.messageHandler.show('エラーが発生しました: ' + error.message, 'error');
            }
        })
        .finally(() => {
            if (window.loadingHandler) {
                window.loadingHandler.hide();
            }
        });
}

// シフト否認処理
function handleDeny(requestType, requestId, employeeId) {
    if (window.loadingHandler) {
        window.loadingHandler.show('否認処理中...');
    }

    const formData = new FormData();
    formData.append('request_id', requestId);
    formData.append('request_type', requestType);
    formData.append('employee_id', employeeId);

    fetch('/shift/reject', {
        method: 'POST',
        headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: formData
    })
        .then(response => {
            if (response.ok) {
                if (window.messageHandler) {
                    window.messageHandler.show('リクエストを否認しました', 'success');
                }
                // 否認されたリクエストを非表示にする
                const requestElement = document.getElementById(`req-${requestId}`);
                if (requestElement) {
                    requestElement.style.display = 'none';
                }
            } else {
                throw new Error('否認に失敗しました');
            }
        })
        .catch(error => {
            if (window.messageHandler) {
                window.messageHandler.show('エラーが発生しました: ' + error.message, 'error');
            }
        })
        .finally(() => {
            if (window.loadingHandler) {
                window.loadingHandler.hide();
            }
        });
}

// グローバルに公開
window.handleApprove = handleApprove;
window.handleDeny = handleDeny;
