// フラッシュメッセージのJavaScript

// 初期化
document.addEventListener('DOMContentLoaded', function () {
    // フラッシュメッセージを即座にトースト形式で表示
    setTimeout(function () {
        try {
            showFlashMessages();
        } catch (error) {
            console.error('フラッシュメッセージ表示エラー:', error);
            showFallbackMessages();
        }
    }, 100); // 100ms遅延で他のスクリプトの初期化を待つ
});

// フラッシュメッセージの表示
function showFlashMessages() {
    const body = document.body;
    if (!body) return;

    // 各フラッシュメッセージタイプをチェック
    const flashTypes = [
        { key: 'flashSuccess', type: 'success' },
        { key: 'flashError', type: 'error' },
        { key: 'flashWarning', type: 'warning' },
        { key: 'flashInfo', type: 'info' },
        { key: 'flashNotice', type: 'success' },
        { key: 'flashAlert', type: 'error' }
    ];

    flashTypes.forEach(({ key, type }) => {
        const datasetKey = key.charAt(0).toLowerCase() + key.slice(1);
        const message = body.dataset[datasetKey];
        if (message) {
            showFlashMessage(message, type);
        }
    });
}

// フォールバックメッセージの表示
function showFallbackMessages() {
    const body = document.body;
    if (!body) return;

    // フォールバック: アラートで表示
    const fallbackTypes = [
        { key: 'flashNotice', type: 'notice' },
        { key: 'flashAlert', type: 'alert' },
        { key: 'flashError', type: 'error' },
        { key: 'flashSuccess', type: 'success' }
    ];

    fallbackTypes.forEach(({ key, type }) => {
        const message = body.dataset[key];
        if (message) {
            alert(message);
        }
    });
}

// フラッシュメッセージの表示
function showFlashMessage(message, type) {
    if (window.messageHandler) {
        window.messageHandler.show(message, type);
    } else {
        createFallbackToast(message, type);
    }
}

// 簡易トースト通知の作成
function createFallbackToast(message, type) {
    // 既存のトーストコンテナを取得または作成
    let toastContainer = document.getElementById('fallback-toast-container');
    if (!toastContainer) {
        toastContainer = document.createElement('div');
        toastContainer.id = 'fallback-toast-container';
        toastContainer.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 1000;
      max-width: 400px;
    `;
        document.body.appendChild(toastContainer);
    }

    // トースト要素を作成
    const toast = document.createElement('div');
    toast.style.cssText = `
    padding: 12px 16px;
    margin-bottom: 10px;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    animation: slideInRight 0.3s ease-out;
    position: relative;
    cursor: pointer;
    color: white;
    font-weight: 500;
  `;

    // タイプに応じたスタイルを適用
    const typeStyles = {
        success: 'background-color: #4caf50; border-left: 4px solid #2e7d32;',
        error: 'background-color: #f44336; border-left: 4px solid #c62828;',
        warning: 'background-color: #ff9800; border-left: 4px solid #ef6c00;',
        info: 'background-color: #2196f3; border-left: 4px solid #1565c0;'
    };

    toast.style.cssText += typeStyles[type] || typeStyles.info;
    toast.textContent = message;

    // クリックで閉じる機能
    toast.addEventListener('click', () => {
        removeToast(toast);
    });

    // コンテナに追加
    toastContainer.appendChild(toast);

    // 5秒後に自動で閉じる
    setTimeout(() => {
        removeToast(toast);
    }, 5000);
}

// トーストの削除
function removeToast(toast) {
    if (toast && toast.parentNode) {
        toast.style.animation = 'slideOutRight 0.3s ease-out';
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    }
}

// グローバル関数として登録
window.showFlashMessage = function (message, type) {
    showFlashMessage(message, type);
};

// スタイルを動的に追加
const flashMessageStyle = document.createElement('style');
flashMessageStyle.textContent = `
  @keyframes slideInRight {
    from {
      transform: translateX(100%);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }

  @keyframes slideOutRight {
    from {
      transform: translateX(0);
      opacity: 1;
    }
    to {
      transform: translateX(100%);
      opacity: 0;
    }
  }
`;
document.head.appendChild(flashMessageStyle);
