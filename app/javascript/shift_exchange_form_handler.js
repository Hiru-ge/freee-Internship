class ShiftExchangeFormHandler {
    constructor() {
        this.applicantId = null;
        this.date = null;
        this.startTime = null;
        this.endTime = null;
        this.employees = [];
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupEventListeners();
            this.loadEmployees();
        });
    }

    setupEventListeners() {
        // フォーム送信イベント
        const form = document.getElementById('request-form');
        if (form) {
            form.addEventListener('submit', (e) => this.handleFormSubmit(e));
        }

        // 戻るボタンのイベント
        const backBtn = document.querySelector('[data-action="go-back"]');
        if (backBtn) {
            backBtn.addEventListener('click', (e) => {
                e.preventDefault();
                this.goBack();
            });
        }
    }

    setData(applicantId, date, startTime, endTime, employees) {
        this.applicantId = applicantId;
        this.date = date;
        this.startTime = startTime;
        this.endTime = endTime;
        this.employees = employees;
    }

    loadEmployees() {
        if (!this.employees || this.employees.length === 0) {
            this.showMessage('従業員データが取得できません', 'error');
            return;
        }

        const employeeSelect = document.getElementById('employee-select');
        if (!employeeSelect) return;

        employeeSelect.innerHTML = '<option value="">従業員を選択してください</option>';

        this.employees.forEach(employee => {
            const option = document.createElement('option');
            option.value = employee.id;
            option.textContent = employee.display_name;
            employeeSelect.appendChild(option);
        });
    }

    handleFormSubmit(e) {
        const selectedEmployees = this.getSelectedEmployees();

        if (selectedEmployees.length === 0) {
            e.preventDefault();
            this.showMessage('交代相手を選択してください', 'error');
            return;
        }

        if (selectedEmployees.length > 1) {
            e.preventDefault();
            this.showMessage('交代相手は1人まで選択できます', 'error');
            return;
        }

        const selectedEmployee = selectedEmployees[0];
        if (selectedEmployee === this.applicantId) {
            e.preventDefault();
            this.showMessage('自分自身を交代相手に選択することはできません', 'error');
            return;
        }

        // フォームデータを設定
        const form = e.target;
        const employeeIdInput = form.querySelector('input[name="shift_exchange[employee_id]"]');
        if (employeeIdInput) {
            employeeIdInput.value = selectedEmployee;
        }

        // ローディング表示
        if (window.loadingHandler) {
            window.loadingHandler.show('シフト交代依頼を送信中...');
        }
    }

    getSelectedEmployees() {
        const checkboxes = document.querySelectorAll('input[name="selected_employees[]"]:checked');
        return Array.from(checkboxes).map(checkbox => checkbox.value);
    }

    goBack() {
        window.history.back();
    }

    showMessage(message, type) {
        if (window.messageHandler) {
            window.messageHandler.show(message, type);
        } else {
            const messageDiv = document.getElementById('message');
            if (messageDiv) {
                messageDiv.textContent = message;
                messageDiv.className = 'message ' + type;
                messageDiv.style.display = 'block';
                setTimeout(() => {
                    messageDiv.style.display = 'none';
                }, 5000);
            }
        }
    }
}

// グローバルインスタンスを作成
window.shiftExchangeFormHandler = new ShiftExchangeFormHandler();
