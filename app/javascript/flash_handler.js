class FlashHandler {
    constructor() {
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.showFlashMessages();
        });
    }

    showFlashMessages() {
        setTimeout(() => {
            try {
                this.showFlashMessageFromData('success');
                this.showFlashMessageFromData('error');
                this.showFlashMessageFromData('warning');
                this.showFlashMessageFromData('info');
                this.showFlashMessageFromData('notice');
                this.showFlashMessageFromData('alert');
            } catch (error) {
                console.error('フラッシュメッセージ表示エラー:', error);
                this.showFallbackAlerts();
            }
        }, 100);
    }

    showFlashMessageFromData(type) {
        const messageElement = document.querySelector(`[data-flash-${type}]`);
        if (messageElement) {
            const message = messageElement.getAttribute(`data-flash-${type}`);
            this.showFlashMessage(message, type);
        }
    }

    showFlashMessage(message, type) {
        if (window.messageHandler) {
            window.messageHandler.show(message, type);
        } else {
            this.createFallbackToast(message, type);
        }
    }

    createFallbackToast(message, type) {
        const toast = document.createElement('div');
        toast.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background-color: ${this.getBackgroundColor(type)};
      color: white;
      padding: 12px 16px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      z-index: 1000;
      max-width: 400px;
      animation: slideInRight 0.3s ease-out;
      cursor: pointer;
    `;
        toast.textContent = message;

        this.addToastAnimations();
        document.body.appendChild(toast);

        toast.addEventListener('click', () => {
            this.removeToast(toast);
        });

        setTimeout(() => {
            this.removeToast(toast);
        }, 5000);
    }

    getBackgroundColor(type) {
        switch (type) {
            case 'error':
            case 'alert':
                return '#f44336';
            case 'success':
            case 'notice':
                return '#4caf50';
            case 'warning':
                return '#ff9800';
            case 'info':
            default:
                return '#2196f3';
        }
    }

    addToastAnimations() {
        if (!document.getElementById('toast-animations')) {
            const style = document.createElement('style');
            style.id = 'toast-animations';
            style.textContent = `
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
            document.head.appendChild(style);
        }
    }

    removeToast(toast) {
        if (toast.parentNode) {
            toast.style.animation = 'slideOutRight 0.3s ease-out';
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.parentNode.removeChild(toast);
                }
            }, 300);
        }
    }

    showFallbackAlerts() {
        const alerts = ['notice', 'alert', 'error', 'success'];
        alerts.forEach(type => {
            const messageElement = document.querySelector(`[data-flash-${type}]`);
            if (messageElement) {
                const message = messageElement.getAttribute(`data-flash-${type}`);
                alert(message);
            }
        });
    }
}

new FlashHandler();
