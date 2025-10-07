// 認証関連の共通JS機能

// 認証コード入力制限の共通関数
function setupVerificationCodeInput(inputId) {
    const input = document.getElementById(inputId);
    if (!input) return;

    // 数字以外を除去
    input.addEventListener('input', function (e) {
        e.target.value = e.target.value.replace(/[^0-9]/g, '');

        // 6桁を超えた場合は切り詰め
        if (e.target.value.length > 6) {
            e.target.value = e.target.value.substring(0, 6);
        }
    });

    // フォーカス時の全選択
    input.addEventListener('focus', function (e) {
        e.target.select();
    });
}

// 認証コードバリデーション
function validateVerificationCode(code) {
    if (!code || code.length !== 6) {
        return { valid: false, message: '認証コードは6桁で入力してください。' };
    }

    if (!/^[0-9]{6}$/.test(code)) {
        return { valid: false, message: '認証コードは数字のみで入力してください。' };
    }

    return { valid: true };
}

// パスワードバリデーション
function validatePassword(password) {
    if (password.length < 8) {
        return { valid: false, message: 'パスワードは8文字以上で入力してください。' };
    }

    if (!/[a-zA-Z]/.test(password)) {
        return { valid: false, message: 'パスワードには英字を含める必要があります。' };
    }

    if (!/[0-9]/.test(password)) {
        return { valid: false, message: 'パスワードには数字を含める必要があります。' };
    }

    return { valid: true };
}

// パスワード確認バリデーション
function validatePasswordConfirmation(password, confirmPassword) {
    if (password !== confirmPassword) {
        return { valid: false, message: 'パスワードが一致しません。' };
    }

    return { valid: true };
}

// 従業員選択バリデーション
function validateEmployeeSelection(selectId) {
    const select = document.getElementById(selectId);
    if (!select || !select.value) {
        return { valid: false, message: '従業員を選択してください。' };
    }

    return { valid: true };
}

// フォーム送信時のローディング表示
function showFormLoading(form, message = '送信中...') {
    const submitButton = form.querySelector('button[type="submit"]');
    if (submitButton) {
        submitButton.disabled = true;
        submitButton.textContent = message;
    }

    if (window.loadingHandler) {
        window.loadingHandler.show(message);
    }
}

// フォーム送信完了時のローディング非表示
function hideFormLoading(form) {
    const submitButton = form.querySelector('button[type="submit"]');
    if (submitButton) {
        submitButton.disabled = false;
        submitButton.textContent = submitButton.dataset.originalText || '送信';
    }

    if (window.loadingHandler) {
        window.loadingHandler.hide();
    }
}

// エラーメッセージ表示
function showErrorMessage(message, focusElement = null) {
    if (window.messageHandler) {
        window.messageHandler.show(message, 'error');
    } else {
        alert(message);
    }

    if (focusElement) {
        focusElement.focus();
    }
}

// ログインフォームの設定
function setupLoginForm() {
    const form = document.getElementById('login-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const employeeId = document.getElementById('employee-select')?.value;
        const password = document.getElementById('password')?.value;

        if (!employeeId) {
            e.preventDefault();
            showErrorMessage('従業員を選択してください', document.getElementById('employee-select'));
            return;
        }

        if (!password) {
            e.preventDefault();
            showErrorMessage('パスワードを入力してください', document.getElementById('password'));
            return;
        }

        showFormLoading(form, 'ログイン処理中...');
    });
}

// パスワード忘れフォームの設定
function setupForgotPasswordForm() {
    const form = document.getElementById('email-verification-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const employeeSelect = document.getElementById('employee-select');
        const validation = validateEmployeeSelection('employee-select');

        if (!validation.valid) {
            e.preventDefault();
            showErrorMessage(validation.message, employeeSelect);
            return;
        }
    });
}

// 認証コードフォームの設定
function setupVerificationCodeForm(formId, inputId) {
    const form = document.getElementById(formId);
    if (!form) return;

    // 認証コード入力制限を設定
    setupVerificationCodeInput(inputId);

    form.addEventListener('submit', function (e) {
        const code = document.getElementById(inputId)?.value;
        const validation = validateVerificationCode(code);

        if (!validation.valid) {
            e.preventDefault();
            showErrorMessage(validation.message, document.getElementById(inputId));
            return;
        }

        showFormLoading(form, '認証中...');
    });
}

// パスワードリセットフォームの設定
function setupPasswordResetForm() {
    const form = document.getElementById('password-reset-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const newPassword = document.getElementById('new-password')?.value;
        const confirmPassword = document.getElementById('confirm-password')?.value;

        const passwordValidation = validatePassword(newPassword);
        if (!passwordValidation.valid) {
            e.preventDefault();
            showErrorMessage(passwordValidation.message, document.getElementById('new-password'));
            return;
        }

        const confirmValidation = validatePasswordConfirmation(newPassword, confirmPassword);
        if (!confirmValidation.valid) {
            e.preventDefault();
            showErrorMessage(confirmValidation.message, document.getElementById('confirm-password'));
            return;
        }
    });
}

// パスワード変更フォームの設定
function setupPasswordChangeForm() {
    const form = document.getElementById('password-change-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const currentPassword = document.getElementById('current-password')?.value;
        const newPassword = document.getElementById('new-password')?.value;
        const confirmPassword = document.getElementById('confirm-password')?.value;

        if (!currentPassword) {
            e.preventDefault();
            showErrorMessage('現在のパスワードを入力してください', document.getElementById('current-password'));
            return;
        }

        const passwordValidation = validatePassword(newPassword);
        if (!passwordValidation.valid) {
            e.preventDefault();
            showErrorMessage(passwordValidation.message, document.getElementById('new-password'));
            return;
        }

        const confirmValidation = validatePasswordConfirmation(newPassword, confirmPassword);
        if (!confirmValidation.valid) {
            e.preventDefault();
            showErrorMessage(confirmValidation.message, document.getElementById('confirm-password'));
            return;
        }
    });
}

// 初回パスワード設定フォームの設定
function setupInitialPasswordForm() {
    const form = document.getElementById('password-setup-form');
    if (!form) return;

    form.addEventListener('submit', function (e) {
        const newPassword = document.getElementById('new-password')?.value;
        const confirmPassword = document.getElementById('confirm-password')?.value;

        const passwordValidation = validatePassword(newPassword);
        if (!passwordValidation.valid) {
            e.preventDefault();
            showErrorMessage(passwordValidation.message, document.getElementById('new-password'));
            return;
        }

        const confirmValidation = validatePasswordConfirmation(newPassword, confirmPassword);
        if (!confirmValidation.valid) {
            e.preventDefault();
            showErrorMessage(confirmValidation.message, document.getElementById('confirm-password'));
            return;
        }
    });
}

// ページ初期化
function initializeAuthPage() {
    // ログインフォーム
    setupLoginForm();

    // パスワード忘れフォーム
    setupForgotPasswordForm();

    // 認証コードフォーム
    setupVerificationCodeForm('verify-code-form', 'code-input');
    setupVerificationCodeForm('verification-form', 'verification-code');

    // パスワードリセットフォーム
    setupPasswordResetForm();

    // パスワード変更フォーム
    setupPasswordChangeForm();

    // 初回パスワード設定フォーム
    setupInitialPasswordForm();
}

// DOMContentLoaded時に初期化
document.addEventListener('DOMContentLoaded', initializeAuthPage);

// グローバルに公開
window.AuthUtils = {
    setupVerificationCodeInput,
    validateVerificationCode,
    validatePassword,
    validatePasswordConfirmation,
    validateEmployeeSelection,
    showFormLoading,
    hideFormLoading,
    showErrorMessage,
    setupLoginForm,
    setupForgotPasswordForm,
    setupVerificationCodeForm,
    setupPasswordResetForm,
    setupPasswordChangeForm,
    setupInitialPasswordForm,
    initializeAuthPage
};
