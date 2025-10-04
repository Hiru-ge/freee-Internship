class ShiftApprovalHandler {
    constructor() {
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupEventListeners();
        });
    }

    setupEventListeners() {
        // 承認ボタンのイベント設定
        const approveButtons = document.querySelectorAll('.approval-button.approve');
        approveButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                const requestType = e.target.dataset.requestType;
                const requestId = e.target.dataset.requestId;
                const employeeId = e.target.dataset.employeeId;
                this.handleApprove(requestType, requestId, employeeId);
            });
        });

        // 否認ボタンのイベント設定
        const rejectButtons = document.querySelectorAll('.approval-button.reject');
        rejectButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                const requestType = e.target.dataset.requestType;
                const requestId = e.target.dataset.requestId;
                const employeeId = e.target.dataset.employeeId;
                this.handleDeny(requestType, requestId, employeeId);
            });
        });
    }

    handleApprove(requestType, requestId, employeeId) {
        if (!requestType || !requestId || !employeeId) {
            this.showMessage('リクエスト情報が不正です', 'error');
            return;
        }

        if (window.loadingHandler) {
            window.loadingHandler.show('承認処理中...');
        }

        const url = this.getApprovalUrl(requestType, requestId);
        const data = {
            employee_id: employeeId,
            action: 'approve'
        };

        this.submitApproval(url, data, requestId);
    }

    handleDeny(requestType, requestId, employeeId) {
        if (!requestType || !requestId || !employeeId) {
            this.showMessage('リクエスト情報が不正です', 'error');
            return;
        }

        if (window.loadingHandler) {
            window.loadingHandler.show('否認処理中...');
        }

        const url = this.getApprovalUrl(requestType, requestId);
        const data = {
            employee_id: employeeId,
            action: 'deny'
        };

        this.submitApproval(url, data, requestId);
    }

    getApprovalUrl(requestType, requestId) {
        switch (requestType) {
            case 'exchange':
                return `/shift_exchanges/${requestId}/approve`;
            case 'addition':
                return `/shift_additions/${requestId}/approve`;
            case 'deletion':
                return `/shift_deletions/${requestId}/approve`;
            default:
                throw new Error(`Unknown request type: ${requestType}`);
        }
    }

    submitApproval(url, data, requestId) {
        fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
            },
            body: JSON.stringify(data)
        })
            .then(response => response.json())
            .then(result => {
                if (window.loadingHandler) {
                    window.loadingHandler.hide();
                }

                if (result.success) {
                    this.showMessage(result.message || '処理が完了しました', 'success');
                    this.removeRequestElement(requestId);
                } else {
                    this.showMessage(result.message || '処理に失敗しました', 'error');
                }
            })
            .catch(error => {
                if (window.loadingHandler) {
                    window.loadingHandler.hide();
                }
                console.error('Approval error:', error);
                this.showMessage('エラーが発生しました', 'error');
            });
    }

    removeRequestElement(requestId) {
        const element = document.getElementById(`req-${requestId}`);
        if (element) {
            element.remove();
        }
    }

    showMessage(message, type) {
        if (window.messageHandler) {
            window.messageHandler.show(message, type);
        } else {
            // フォールバック
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ' + type;
            messageDiv.textContent = message;
            document.body.appendChild(messageDiv);
            setTimeout(() => {
                messageDiv.remove();
            }, 5000);
        }
    }
}

// グローバルインスタンスを作成
window.shiftApprovalHandler = new ShiftApprovalHandler();
