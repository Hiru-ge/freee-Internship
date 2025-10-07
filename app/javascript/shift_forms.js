// シフトフォーム関連のJS機能

// フォームバリデーション
function validateShiftForm(formId) {
    const form = document.getElementById(formId);
    if (!form) return { valid: false, message: 'フォームが見つかりません' };

    const requiredFields = form.querySelectorAll('[required]');
    for (const field of requiredFields) {
        if (!field.value.trim()) {
            return { valid: false, message: 'すべての項目を入力してください。', field: field };
        }
    }

    return { valid: true };
}

// シフト追加フォームの設定
function setupShiftAdditionForm() {
    const form = document.getElementById('addition-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const validation = validateShiftForm('addition-form');

        if (!validation.valid) {
            e.preventDefault();
            if (window.messageHandler) {
                window.messageHandler.show(validation.message, 'error');
            } else {
                alert(validation.message);
            }
            if (validation.field) {
                validation.field.focus();
            }
            return;
        }

        // ローディング表示
        const submitButton = form.querySelector('button[type="submit"]');
        if (submitButton) {
            submitButton.disabled = true;
            submitButton.textContent = '送信中...';
        }
    });
}

// シフト削除フォームの設定
function setupShiftDeletionForm() {
    const form = document.getElementById('deletion-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const validation = validateShiftForm('deletion-form');

        if (!validation.valid) {
            e.preventDefault();
            if (window.messageHandler) {
                window.messageHandler.show(validation.message, 'error');
            } else {
                alert(validation.message);
            }
            if (validation.field) {
                validation.field.focus();
            }
            return;
        }

        // ローディング表示
        const submitButton = form.querySelector('button[type="submit"]');
        if (submitButton) {
            submitButton.disabled = true;
            submitButton.textContent = '送信中...';
        }
    });
}

// ページ初期化
function initializeShiftForms() {
    setupShiftAdditionForm();
    setupShiftDeletionForm();
}

// DOMContentLoaded時に初期化
document.addEventListener('DOMContentLoaded', initializeShiftForms);

// グローバルに公開
window.ShiftFormUtils = {
    validateShiftForm,
    setupShiftAdditionForm,
    setupShiftDeletionForm,
    initializeShiftForms
};
