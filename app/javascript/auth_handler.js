class AuthHandler {
    constructor() {
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupFormHandlers();
        });
    }

    setupFormHandlers() {
        // ログインフォーム
        this.setupLoginForm();

        // パスワード変更フォーム
        this.setupPasswordChangeForm();

        // アクセス制御フォーム
        this.setupAccessControlForm();

        // 認証コード確認フォーム
        this.setupVerificationForm();

        // パスワードリセットフォーム
        this.setupPasswordResetForm();

        // 初期設定フォーム
        this.setupInitialSetupForm();
    }

    setupLoginForm() {
        const form = document.getElementById('login-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const employeeId = document.getElementById('employee-select').value;
            const password = document.getElementById('password').value;

            if (!employeeId) {
                e.preventDefault();
                this.showMessage('従業員を選択してください', 'error');
                return;
            }

            if (!password) {
                e.preventDefault();
                this.showMessage('パスワードを入力してください', 'error');
                return;
            }

            this.showLoading('ログイン処理中...');
        });
    }

    setupPasswordChangeForm() {
        const form = document.getElementById('password-change-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const currentPassword = document.getElementById('current-password').value;
            const newPassword = document.getElementById('new-password').value;
            const confirmPassword = document.getElementById('confirm-password').value;

            if (!currentPassword) {
                e.preventDefault();
                this.showMessage('現在のパスワードを入力してください', 'error');
                return;
            }

            if (!newPassword) {
                e.preventDefault();
                this.showMessage('新しいパスワードを入力してください', 'error');
                return;
            }

            if (!this.validatePassword(newPassword)) {
                e.preventDefault();
                this.showMessage('パスワードが要件を満たしていません', 'error');
                return;
            }

            if (newPassword !== confirmPassword) {
                e.preventDefault();
                this.showMessage('パスワードが一致しません', 'error');
                return;
            }

            this.showLoading('変更中...');
        });
    }

    setupAccessControlForm() {
        const form = document.getElementById('email-auth-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const email = document.getElementById('email-input').value;

            if (!email) {
                e.preventDefault();
                this.showMessage('メールアドレスを入力してください', 'error');
                return;
            }

            this.showLoading('認証コードを送信中...');
        });
    }

    setupVerificationForm() {
        const form = document.getElementById('verification-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const code = document.getElementById('verification-code').value;

            if (!code) {
                e.preventDefault();
                this.showMessage('認証コードを入力してください', 'error');
                return;
            }

            if (code.length !== 6) {
                e.preventDefault();
                this.showMessage('認証コードは6桁で入力してください', 'error');
                return;
            }

            this.showLoading('認証中...');
        });
    }

    setupPasswordResetForm() {
        const form = document.getElementById('password-reset-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const email = document.getElementById('email-input').value;

            if (!email) {
                e.preventDefault();
                this.showMessage('メールアドレスを入力してください', 'error');
                return;
            }

            if (!this.validateEmail(email)) {
                e.preventDefault();
                this.showMessage('有効なメールアドレスを入力してください', 'error');
                return;
            }

            this.showLoading('パスワードリセットメールを送信中...');
        });
    }

    setupInitialSetupForm() {
        const form = document.getElementById('initial-setup-form');
        if (!form) return;

        form.addEventListener('submit', (e) => {
            const password = document.getElementById('password').value;
            const confirmPassword = document.getElementById('confirm-password').value;

            if (!password) {
                e.preventDefault();
                this.showMessage('パスワードを入力してください', 'error');
                return;
            }

            if (!this.validatePassword(password)) {
                e.preventDefault();
                this.showMessage('パスワードが要件を満たしていません', 'error');
                return;
            }

            if (password !== confirmPassword) {
                e.preventDefault();
                this.showMessage('パスワードが一致しません', 'error');
                return;
            }

            this.showLoading('設定中...');
        });
    }

    validatePassword(password) {
        if (password.length < 8) return false;
        if (!/[a-zA-Z]/.test(password)) return false;
        if (!/[0-9]/.test(password)) return false;
        return true;
    }

    validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
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
            return window.messageHandler.show(message, type);
        } else {
            // フォールバック
            const existingMessage = document.querySelector('.message');
            if (existingMessage) {
                existingMessage.remove();
            }

            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ' + type;
            messageDiv.textContent = message;

            // フォームを探して挿入
            const forms = ['login-form', 'password-change-form', 'email-auth-form', 'verification-form', 'password-reset-form', 'initial-setup-form'];
            for (const formId of forms) {
                const form = document.getElementById(formId);
                if (form && form.parentNode) {
                    form.parentNode.insertBefore(messageDiv, form.nextSibling);
                    break;
                }
            }
        }
    }
}

// グローバルインスタンスを作成
window.authHandler = new AuthHandler();
