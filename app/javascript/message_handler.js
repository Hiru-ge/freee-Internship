class MessageHandler {
  constructor() {
    this.messageContainer = null;
    this.init();
  }

  init() {
    document.addEventListener('DOMContentLoaded', () => this.createContainer());
  }

  createContainer() {
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

  show(message, type = 'info', duration = 5000) {
    if (!this.messageContainer) {
      this.createContainer();
    }
    const messageElement = this.createMessageElement(message, type);
    this.messageContainer.appendChild(messageElement);

    if (duration > 0) {
      setTimeout(() => {
        this.removeMessage(messageElement);
      }, duration);
    }

    return messageElement;
  }

  success(message, duration = 5000) {
    return this.show(message, 'success', duration);
  }

  error(message, duration = 8000) {
    return this.show(message, 'error', duration);
  }

  warning(message, duration = 6000) {
    return this.show(message, 'warning', duration);
  }

  info(message, duration = 5000) {
    return this.show(message, 'info', duration);
  }

  createMessageElement(message, type) {
    const messageDiv = this.createMessageDiv(type);
    const messageText = this.createMessageText(message);
    const closeButton = this.createCloseButton(messageDiv);

    messageDiv.appendChild(messageText);
    messageDiv.appendChild(closeButton);
    messageDiv.addEventListener('click', () => {
      this.removeMessage(messageDiv);
    });

    return messageDiv;
  }

  createMessageDiv(type) {
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

  createMessageText(message) {
    const messageText = document.createElement('span');
    messageText.textContent = message;
    return messageText;
  }

  createCloseButton(messageDiv) {
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
    return closeButton;
  }

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

}

window.messageHandler = new MessageHandler();

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
