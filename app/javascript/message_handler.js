// 関数ベースのメッセージ表示ユーティリティ
let messageContainer = null;

function ensureMessageContainer() {
  if (messageContainer) return;
  messageContainer = document.createElement('div');
  messageContainer.id = 'message-container';
  messageContainer.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 1000;
    max-width: 400px;
  `;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      document.body.appendChild(messageContainer);
    });
  } else {
    document.body.appendChild(messageContainer);
  }
}

function createMessageDiv(type) {
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
  const typeStyles = {
    success: 'background-color: #4caf50; color: white; border-left: 4px solid #2e7d32;',
    error: 'background-color: #f44336; color: white; border-left: 4px solid #c62828;',
    warning: 'background-color: #ff9800; color: white; border-left: 4px solid #ef6c00;',
    info: 'background-color: #2196f3; color: white; border-left: 4px solid #1565c0;'
  };
  messageDiv.style.cssText += typeStyles[type] || typeStyles.info;
  return messageDiv;
}

function createCloseButton(messageDiv) {
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
    removeMessage(messageDiv);
  });
  return closeButton;
}

function removeMessage(messageElement) {
  if (messageElement && messageElement.parentNode) {
    messageElement.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => {
      if (messageElement.parentNode) {
        messageElement.parentNode.removeChild(messageElement);
      }
    }, 300);
  }
}

function show(message, type = 'info', duration = 5000) {
  ensureMessageContainer();
  const messageDiv = createMessageDiv(type);
  const messageText = document.createElement('span');
  messageText.textContent = message;
  const closeButton = createCloseButton(messageDiv);
  messageDiv.appendChild(messageText);
  messageDiv.appendChild(closeButton);
  // DOMContentLoaded後に追加するためにqueue
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => messageContainer.appendChild(messageDiv));
  } else {
    messageContainer.appendChild(messageDiv);
  }

  if (duration > 0) {
    setTimeout(() => removeMessage(messageDiv), duration);
  }
  return messageDiv;
}

window.messageHandler = {
  show,
  success: (msg, duration = 5000) => show(msg, 'success', duration),
  error: (msg, duration = 8000) => show(msg, 'error', duration),
  warning: (msg, duration = 6000) => show(msg, 'warning', duration),
  info: (msg, duration = 5000) => show(msg, 'info', duration)
};

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
