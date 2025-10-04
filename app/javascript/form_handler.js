class FormHandler {
    constructor() {
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupFormHandlers();
        });
    }

    setupFormHandlers() {
        // シフト追加フォーム
        this.setupShiftAdditionForm();

        // シフト削除フォーム
        this.setupShiftDeletionForm();

        // その他のフォーム
        this.setupGenericForms();
    }

    setupShiftAdditionForm() {
        const form = document.getElementById('shift-addition-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const date = document.getElementById('shift_date').value;
            const startTime = document.getElementById('start_time').value;
            const endTime = document.getElementById('end_time').value;
            const reason = document.getElementById('reason').value;

            if (!date) {
                e.preventDefault();
                this.showMessage('日付を選択してください', 'error');
                return;
            }

            if (!startTime) {
                e.preventDefault();
                this.showMessage('開始時間を選択してください', 'error');
                return;
            }

            if (!endTime) {
                e.preventDefault();
                this.showMessage('終了時間を選択してください', 'error');
                return;
            }

            if (!reason) {
                e.preventDefault();
                this.showMessage('理由を入力してください', 'error');
                return;
            }

            this.showLoading('シフト追加依頼を送信中...');
        });
    }

    setupShiftDeletionForm() {
        const form = document.getElementById('shift-deletion-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const reason = document.getElementById('reason').value;

            if (!reason) {
                e.preventDefault();
                this.showMessage('欠勤理由を入力してください', 'error');
                return;
            }

            this.showLoading('欠勤申請を送信中...');
        });
    }

    setupGenericForms() {
        // 一般的なフォームのバリデーション
        const forms = document.querySelectorAll('form');
        forms.forEach(form => {
            if (form.id && !form.id.includes('shift-addition') && !form.id.includes('shift-deletion')) {
                form.addEventListener('submit', (e) => {
                    this.validateGenericForm(e, form);
                });
            }
        });
    }

    validateGenericForm(e, form) {
        const requiredFields = form.querySelectorAll('[required]');
        let hasError = false;

        requiredFields.forEach(field => {
            if (!field.value.trim()) {
                e.preventDefault();
                this.showMessage(`${field.labels[0]?.textContent || '必須項目'}を入力してください`, 'error');
                hasError = true;
                return;
            }
        });

        if (!hasError) {
            this.showLoading('送信中...');
        }
    }

    showLoading(message) {
        if (window.loadingHandler) {
            window.loadingHandler.show(message);
        } else {
            // フォールバック
            const submitButton = document.querySelector('button[type="submit"]');
            if (submitButton) {
                submitButton.disabled = true;
                submitButton.textContent = message;
            }
        }
    }

    showMessage(message, type) {
        if (window.messageHandler) {
            window.messageHandler.show(message, type);
        } else {
            // フォールバック
            const existingMessage = document.querySelector('.message');
            if (existingMessage) {
                existingMessage.remove();
            }

            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ' + type;
            messageDiv.textContent = message;

            // フォームの後に挿入
            const form = document.querySelector('form');
            if (form && form.parentNode) {
                form.parentNode.insertBefore(messageDiv, form.nextSibling);
            }
        }
    }
}

// グローバルインスタンスを作成
window.formHandler = new FormHandler();
