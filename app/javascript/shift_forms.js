// シフトフォーム関連のJS機能

// フォームバリデーション
function validateShiftForm(formId) {
    return CommonUtils.validateRequiredFields(`#${formId}`);
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
