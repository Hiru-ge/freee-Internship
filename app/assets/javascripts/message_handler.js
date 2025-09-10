// 統一されたメッセージ表示システム
class MessageHandler {
  constructor() {
    this.messageContainer = null;
    this.init();
  }

  init() {
    // DOMが準備できてから実行
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.createContainer());
    } else {
      this.createContainer();
    }
  }

  createContainer() {
    // メッセージコンテナを作成
    this.messageContainer = document.createElement('div');
    this.messageContainer.id = 'message-container';
    this.messageContainer.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 1000;
      max-width: 400px;
    `;
    document.body.appendChild(this.messageContainer);
  }

  // メッセージ表示
  show(message, type = 'info', duration = 5000) {
    // コンテナが存在しない場合は作成
    if (!this.messageContainer) {
      this.createContainer();
    }
    const messageElement = this.createMessageElement(message, type);
    this.messageContainer.appendChild(messageElement);

    // 自動削除
    if (duration > 0) {
      setTimeout(() => {
        this.removeMessage(messageElement);
      }, duration);
    }

    return messageElement;
  }

  // 成功メッセージ
  success(message, duration = 5000) {
    return this.show(message, 'success', duration);
  }

  // エラーメッセージ
  error(message, duration = 8000) {
    return this.show(message, 'error', duration);
  }

  // 警告メッセージ
  warning(message, duration = 6000) {
    return this.show(message, 'warning', duration);
  }

  // 情報メッセージ
  info(message, duration = 5000) {
    return this.show(message, 'info', duration);
  }

  // メッセージ要素作成
  createMessageElement(message, type) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message message-${type}`;
    messageDiv.style.cssText = `
      padding: 12px 16px;
      margin-bottom: 10px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      animation: slideIn 0.3s ease-out;
      position: relative;
      cursor: pointer;
    `;

    // タイプ別スタイル
    switch (type) {
      case 'success':
        messageDiv.style.cssText += `
          background-color: #4caf50;
          color: white;
          border-left: 4px solid #2e7d32;
        `;
        break;
      case 'error':
        messageDiv.style.cssText += `
          background-color: #f44336;
          color: white;
          border-left: 4px solid #c62828;
        `;
        break;
      case 'warning':
        messageDiv.style.cssText += `
          background-color: #ff9800;
          color: white;
          border-left: 4px solid #ef6c00;
        `;
        break;
      case 'info':
      default:
        messageDiv.style.cssText += `
          background-color: #2196f3;
          color: white;
          border-left: 4px solid #1565c0;
        `;
        break;
    }

    // メッセージテキスト
    const messageText = document.createElement('span');
    messageText.textContent = message;
    messageDiv.appendChild(messageText);

    // 閉じるボタン
    const closeButton = document.createElement('button');
    closeButton.innerHTML = '×';
    closeButton.style.cssText = `
      position: absolute;
      top: 5px;
      right: 8px;
      background: none;
      border: none;
      color: white;
      font-size: 18px;
      cursor: pointer;
      padding: 0;
      width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
    `;
    closeButton.addEventListener('click', () => {
      this.removeMessage(messageDiv);
    });
    messageDiv.appendChild(closeButton);

    // クリックで閉じる
    messageDiv.addEventListener('click', () => {
      this.removeMessage(messageDiv);
    });

    return messageDiv;
  }

  // メッセージ削除
  removeMessage(messageElement) {
    if (messageElement && messageElement.parentNode) {
      messageElement.style.animation = 'slideOut 0.3s ease-in';
      setTimeout(() => {
        if (messageElement.parentNode) {
          messageElement.parentNode.removeChild(messageElement);
        }
      }, 300);
    }
  }

  // 全メッセージクリア
  clear() {
    while (this.messageContainer.firstChild) {
      this.messageContainer.removeChild(this.messageContainer.firstChild);
    }
  }
}

// グローバルインスタンス
window.messageHandler = new MessageHandler();

// 後方互換性のための関数
window.showMessage = function(message, type, duration) {
  return window.messageHandler.show(message, type, duration);
};

// CSS アニメーション
const messageStyle = document.createElement('style');
messageStyle.textContent = `
  @keyframes slideIn {
    from {
      transform: translateX(100%);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }

  @keyframes slideOut {
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
document.head.appendChild(messageStyle);
