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
        if (window.loadingHandler) {
            window.loadingHandler.show('送信中...');
        }

        // フォーム送信後、少し遅延してからローディングを非表示
        // （リダイレクトが発生する場合があるため）
        setTimeout(() => {
            if (window.loadingHandler) {
                window.loadingHandler.hide();
            }
        }, 1000);
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
        if (window.loadingHandler) {
            window.loadingHandler.show('送信中...');
        }

        // フォーム送信後、少し遅延してからローディングを非表示
        // （リダイレクトが発生する場合があるため）
        setTimeout(() => {
            if (window.loadingHandler) {
                window.loadingHandler.hide();
            }
        }, 1000);
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
