// 統一されたローディング表示システム
class LoadingHandler {
  constructor() {
    this.loadingOverlay = null;
    this.progressBar = null;
    this.loadingText = null;
    this.init();
  }

  init() {
    // ローディングオーバーレイを作成
    this.loadingOverlay = document.createElement('div');
    this.loadingOverlay.id = 'loading-overlay';
    this.loadingOverlay.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-color: rgba(0, 0, 0, 0.7);
      z-index: 9999;
      display: none;
      align-items: center;
      justify-content: center;
      flex-direction: column;
    `;

    // ローディングコンテナ
    const loadingContainer = document.createElement('div');
    loadingContainer.style.cssText = `
      background-color: #3a3a3a;
      padding: 30px;
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5);
      text-align: center;
      min-width: 300px;
      max-width: 500px;
    `;

    // スピナー
    const spinner = document.createElement('div');
    spinner.className = 'loading-spinner-large';
    spinner.style.cssText = `
      width: 40px;
      height: 40px;
      border: 4px solid #555;
      border-radius: 50%;
      border-top-color: #ffca28;
      animation: spin 1s ease-in-out infinite;
      margin: 0 auto 20px auto;
    `;

    // ローディングテキスト
    this.loadingText = document.createElement('div');
    this.loadingText.style.cssText = `
      color: #f0f0f0;
      font-size: 16px;
      margin-bottom: 20px;
      font-weight: 500;
    `;
    this.loadingText.textContent = '読み込み中...';

    // プログレスバー
    this.progressBar = document.createElement('div');
    this.progressBar.style.cssText = `
      width: 100%;
      height: 6px;
      background-color: #555;
      border-radius: 3px;
      overflow: hidden;
      margin-bottom: 10px;
    `;

    const progressFill = document.createElement('div');
    progressFill.id = 'progress-fill';
    progressFill.style.cssText = `
      height: 100%;
      background-color: #ffca28;
      border-radius: 3px;
      width: 0%;
      transition: width 0.3s ease;
    `;

    this.progressBar.appendChild(progressFill);

    // プログレステキスト
    this.progressText = document.createElement('div');
    this.progressText.style.cssText = `
      color: #999;
      font-size: 12px;
    `;
    this.progressText.textContent = '0%';

    // 組み立て
    loadingContainer.appendChild(spinner);
    loadingContainer.appendChild(this.loadingText);
    loadingContainer.appendChild(this.progressBar);
    loadingContainer.appendChild(this.progressText);
    this.loadingOverlay.appendChild(loadingContainer);
    document.body.appendChild(this.loadingOverlay);
  }

  // ローディング表示
  show(message = '読み込み中...', showProgress = false) {
    this.loadingText.textContent = message;
    this.progressBar.style.display = showProgress ? 'block' : 'none';
    this.progressText.style.display = showProgress ? 'block' : 'none';
    this.loadingOverlay.style.display = 'flex';
    
    // アニメーション
    this.loadingOverlay.style.opacity = '0';
    setTimeout(() => {
      this.loadingOverlay.style.opacity = '1';
    }, 10);
  }

  // ローディング非表示
  hide() {
    this.loadingOverlay.style.opacity = '0';
    setTimeout(() => {
      this.loadingOverlay.style.display = 'none';
      this.resetProgress();
    }, 300);
  }

  // プログレス更新
  updateProgress(percentage, message = null) {
    const progressFill = document.getElementById('progress-fill');
    if (progressFill) {
      progressFill.style.width = `${Math.min(100, Math.max(0, percentage))}%`;
      this.progressText.textContent = `${Math.round(percentage)}%`;
    }
    
    if (message) {
      this.loadingText.textContent = message;
    }
  }

  // プログレスリセット
  resetProgress() {
    this.updateProgress(0);
  }

  // 段階的ローディング
  async showWithSteps(steps, onStepComplete = null) {
    this.show('初期化中...', true);
    
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const percentage = ((i + 1) / steps.length) * 100;
      
      this.updateProgress(percentage, step.message);
      
      try {
        if (step.action) {
          await step.action();
        }
        
        if (onStepComplete) {
          onStepComplete(step, i);
        }
        
        // ステップ間の遅延
        if (step.delay) {
          await new Promise(resolve => setTimeout(resolve, step.delay));
        }
      } catch (error) {
        console.error(`Step ${i + 1} failed:`, error);
        this.hide();
        throw error;
      }
    }
    
    this.hide();
  }
}

// グローバルインスタンス
window.loadingHandler = new LoadingHandler();

// 便利な関数
window.showLoading = function(message, showProgress) {
  return window.loadingHandler.show(message, showProgress);
};

window.hideLoading = function() {
  return window.loadingHandler.hide();
};

window.updateLoadingProgress = function(percentage, message) {
  return window.loadingHandler.updateProgress(percentage, message);
};

// フォーム送信時の自動ローディング
document.addEventListener('DOMContentLoaded', function() {
  // フォーム送信時のローディング表示
  document.addEventListener('submit', function(e) {
    const form = e.target;
    if (form.tagName === 'FORM' && !form.hasAttribute('data-no-loading')) {
      const submitButton = form.querySelector('button[type="submit"], input[type="submit"]');
      if (submitButton) {
        const originalText = submitButton.textContent || submitButton.value;
        submitButton.disabled = true;
        submitButton.textContent = '送信中...';
        submitButton.value = '送信中...';
        
        // フォーム送信完了時の処理
        form.addEventListener('submit', function() {
          setTimeout(() => {
            submitButton.disabled = false;
            submitButton.textContent = originalText;
            submitButton.value = originalText;
          }, 1000);
        }, { once: true });
      }
    }
  });

  // AJAX リクエスト時のローディング表示
  const originalFetch = window.fetch;
  window.fetch = function(...args) {
    const url = args[0];
    const options = args[1] || {};
    
    // 特定のURLパターンでローディング表示
    if (typeof url === 'string' && (
      url.includes('/api/') || 
      url.includes('/auth/') ||
      url.includes('/shifts/') ||
      url.includes('/dashboard/')
    )) {
      window.loadingHandler.show('通信中...');
      
      return originalFetch.apply(this, args)
        .finally(() => {
          window.loadingHandler.hide();
        });
    }
    
    return originalFetch.apply(this, args);
  };
});

// CSS アニメーション
const style = document.createElement('style');
style.textContent = `
  .loading-spinner-large {
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  #loading-overlay {
    transition: opacity 0.3s ease;
  }
`;
document.head.appendChild(style);
