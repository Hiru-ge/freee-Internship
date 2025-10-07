// 共通ユーティリティ関数

// 設定読み込みの共通関数
function loadConfigFromContainer(containerSelector, configMap) {
    const container = document.querySelector(containerSelector);
    if (!container) return {};

    const config = {};
    for (const [key, dataKey] of Object.entries(configMap)) {
        const value = container.dataset[dataKey];
        if (value !== undefined) {
            // 数値の場合は変換
            if (dataKey.includes('Year') || dataKey.includes('Month') || dataKey.includes('Id')) {
                config[key] = parseInt(value) || value;
            } else if (dataKey.toLowerCase().includes('isowner') || dataKey.toLowerCase().startsWith('is')) {
                // 'true' / 'false' の文字列を厳密にブールへ
                config[key] = String(value) === 'true';
            } else if (dataKey.toLowerCase().includes('employeesdata') || dataKey.toLowerCase().includes('json')) {
                // data-属性ではJSON内のダブルクオートが &quot; にエスケープされることがあるため復元
                try {
                    const unescaped = (value || '')
                        .replace(/&quot;/g, '"')
                        .replace(/&#34;/g, '"')
                        .replace(/&amp;/g, '&');
                    config[key] = JSON.parse(unescaped || '[]');
                } catch (_) {
                    config[key] = [];
                }
            } else {
                config[key] = value;
            }
        }
    }
    return config;
}

// ページ別設定の統一関数
function createPageConfig(pageType, containerSelector) {
    const configMaps = {
        attendance: {
            currentEmployeeId: 'employeeId',
            currentEmployeeName: 'employeeName',
            attendanceYear: 'attendanceYear',
            attendanceMonth: 'attendanceMonth',
            clockInPath: 'clockInPath',
            clockOutPath: 'clockOutPath',
            clockStatusPath: 'clockStatusPath',
            attendanceHistoryPath: 'attendanceHistoryPath'
        },
        shiftDisplay: {
            currentEmployeeId: 'employeeId',
            isOwner: 'isOwner',
            shiftsDataPath: 'shiftsDataPath',
            employeesWagesPath: 'employeesWagesPath',
            allWagesPath: 'allWagesPath',
            wageInfoPath: 'wageInfoPath',
            newShiftExchangePath: 'newShiftExchangePath',
            newShiftDeletionPath: 'newShiftDeletionPath',
            shiftApprovalsPath: 'shiftApprovalsPath',
            newShiftAdditionPath: 'newShiftAdditionPath'
        },
        shiftExchange: {
            applicantIdFromUrl: 'applicantId',
            dateFromUrl: 'date',
            startFromUrl: 'startTime',
            endFromUrl: 'endTime',
            employees: 'employees'
        }
    };

    return loadConfigFromContainer(containerSelector, configMaps[pageType]);
}

// API呼び出しの共通関数
async function apiCall(url, options = {}) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    const isFormData = options.body instanceof FormData;

    // 基本ヘッダ
    const headers = {
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken
    };
    // JSON送信時のみ Content-Type を付与（FormData のときはブラウザに任せる）
    if (!isFormData && options.body !== undefined) {
        headers['Content-Type'] = 'application/json';
    }

    const mergedOptions = {
        headers,
        ...options
    };

    try {
        const response = await fetch(url, mergedOptions);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error('API呼び出しエラー:', error);
        throw error;
    }
}

// メッセージ表示の共通関数
function showMessage(message, type = 'info') {
    if (window.messageHandler) {
        return window.messageHandler.show(message, type);
    } else {
        // フォールバック
        alert(message);
    }
}

// エラーハンドリングの共通関数
function handleApiError(error, context = '') {
    const errorMessage = context ? `${context}中にエラーが発生しました` : 'エラーが発生しました';
    console.error(errorMessage, error);
    showMessage(errorMessage, 'error');
}

// 初期化の共通関数
function initializePage(initFunction) {
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initFunction);
    } else {
        initFunction();
    }
}

// フォーム送信の共通処理
function setupFormSubmission(formSelector, validationFunction, successCallback) {
    const form = document.querySelector(formSelector);
    if (!form) return;

    form.addEventListener('submit', async function (e) {
        e.preventDefault();

        try {
            // バリデーション
            if (validationFunction && !validationFunction()) {
                return;
            }

            // ローディング表示
            if (window.loadingHandler) {
                window.loadingHandler.show('送信中...');
            }

            // フォームデータの送信
            const formData = new FormData(form);
            const response = await apiCall(form.action, {
                method: 'POST',
                body: formData
            });

            // 成功処理
            if (successCallback) {
                successCallback(response);
            } else {
                showMessage('送信が完了しました', 'success');
            }

        } catch (error) {
            handleApiError(error, 'フォーム送信');
        } finally {
            if (window.loadingHandler) {
                window.loadingHandler.hide();
            }
        }
    });
}

// データテーブル表示の共通関数
function createDataTable(data, columns, containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    if (!data || data.length === 0) {
        container.innerHTML = '<p style="text-align: center; padding: 40px; color: #999;">データがありません</p>';
        return;
    }

    let html = '<table border="1">';
    html += '<thead><tr>';
    columns.forEach(col => {
        html += `<th>${col.header}</th>`;
    });
    html += '</tr></thead>';
    html += '<tbody>';

    data.forEach(row => {
        html += '<tr>';
        columns.forEach(col => {
            const value = col.accessor ? col.accessor(row) : row[col.key];
            html += `<td>${value || ''}</td>`;
        });
        html += '</tr>';
    });

    html += '</tbody></table>';
    container.innerHTML = html;
}

// 日付フォーマットの共通関数
function formatDate(date, format = 'YYYY-MM-DD') {
    if (!date) return '';

    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');

    return format
        .replace('YYYY', year)
        .replace('MM', month)
        .replace('DD', day);
}

// 時間フォーマットの共通関数
function formatTime(time, format = 'HH:mm') {
    if (!time) return '';

    const t = new Date(`2000-01-01T${time}`);
    const hours = String(t.getHours()).padStart(2, '0');
    const minutes = String(t.getMinutes()).padStart(2, '0');

    return format
        .replace('HH', hours)
        .replace('mm', minutes);
}

// ページネーションの共通関数
function createPagination(currentPage, totalPages, onPageChange) {
    const pagination = document.createElement('div');
    pagination.className = 'pagination';

    // 前のページボタン
    const prevBtn = document.createElement('button');
    prevBtn.textContent = '前';
    prevBtn.disabled = currentPage <= 1;
    prevBtn.addEventListener('click', () => onPageChange(currentPage - 1));
    pagination.appendChild(prevBtn);

    // ページ番号
    for (let i = 1; i <= totalPages; i++) {
        const pageBtn = document.createElement('button');
        pageBtn.textContent = i;
        pageBtn.className = i === currentPage ? 'active' : '';
        pageBtn.addEventListener('click', () => onPageChange(i));
        pagination.appendChild(pageBtn);
    }

    // 次のページボタン
    const nextBtn = document.createElement('button');
    nextBtn.textContent = '次';
    nextBtn.disabled = currentPage >= totalPages;
    nextBtn.addEventListener('click', () => onPageChange(currentPage + 1));
    pagination.appendChild(nextBtn);

    return pagination;
}

// フォームバリデーションの共通関数
function validateRequiredFields(formSelector, requiredFieldSelectors = []) {
    const form = document.querySelector(formSelector);
    if (!form) return { valid: false, message: 'フォームが見つかりません' };

    const fieldsToCheck = requiredFieldSelectors.length > 0
        ? requiredFieldSelectors.map(selector => form.querySelector(selector))
        : form.querySelectorAll('[required]');

    for (const field of fieldsToCheck) {
        if (!field || !field.value.trim()) {
            return {
                valid: false,
                message: 'すべての項目を入力してください。',
                field: field
            };
        }
    }

    return { valid: true };
}

// チェックボックス選択バリデーション
function validateCheckboxSelection(checkboxSelector, minCount = 1) {
    const checkboxes = document.querySelectorAll(checkboxSelector);
    const checkedBoxes = document.querySelectorAll(`${checkboxSelector}:checked`);

    if (checkedBoxes.length < minCount) {
        return {
            valid: false,
            message: `少なくとも${minCount}つ選択してください。`
        };
    }

    return { valid: true };
}

// ページ初期化の統一関数
function initializePageWithConfig(pageType, containerSelector, initFunctions) {
    initializePage(() => {
        window.config = createPageConfig(pageType, containerSelector);
        initFunctions.forEach(func => func());
    });
}

// グローバルに公開
window.CommonUtils = {
    loadConfigFromContainer,
    createPageConfig,
    apiCall,
    showMessage,
    handleApiError,
    initializePage,
    initializePageWithConfig,
    setupFormSubmission,
    createDataTable,
    formatDate,
    formatTime,
    createPagination,
    validateRequiredFields,
    validateCheckboxSelection
};
