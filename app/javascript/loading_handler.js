class LoadingHandler {
  constructor() {
    this.loadingOverlay = null;
    this.progressBar = null;
    this.loadingText = null;
    this.init();
  }

  init() {
    document.addEventListener('DOMContentLoaded', () => this.createOverlay());
  }

  createOverlay() {
    this.loadingOverlay = this.createOverlayElement();
    const loadingContainer = this.createLoadingContainer();

    const spinner = this.createSpinner();
    this.loadingText = this.createLoadingText();
    this.progressBar = this.createProgressBar();
    this.progressText = this.createProgressText();

    loadingContainer.appendChild(spinner);
    loadingContainer.appendChild(this.loadingText);
    loadingContainer.appendChild(this.progressBar);
    loadingContainer.appendChild(this.progressText);
    this.loadingOverlay.appendChild(loadingContainer);
    document.body.appendChild(this.loadingOverlay);
  }

  createOverlayElement() {
    const overlay = document.createElement('div');
    overlay.id = 'loading-overlay';
    overlay.style.cssText = `
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
    return overlay;
  }

  createLoadingContainer() {
    const container = document.createElement('div');
    container.style.cssText = `
      background-color: #3a3a3a;
      padding: 30px;
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5);
      text-align: center;
      min-width: 300px;
      max-width: 500px;
    `;
    return container;
  }

  createSpinner() {
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
    return spinner;
  }

  createLoadingText() {
    const text = document.createElement('div');
    text.style.cssText = `
      color: #f0f0f0;
      font-size: 16px;
      margin-bottom: 20px;
      font-weight: 500;
    `;
    text.textContent = '読み込み中...';
    return text;
  }

  createProgressBar() {
    const progressBar = document.createElement('div');
    progressBar.style.cssText = `
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

    progressBar.appendChild(progressFill);
    return progressBar;
  }

  createProgressText() {
    const text = document.createElement('div');
    text.style.cssText = `
      color: #999;
      font-size: 12px;
    `;
    text.textContent = '0%';
    return text;
  }

  show(message = '読み込み中...', showProgress = false) {
    if (!this.loadingOverlay) {
      this.createOverlay();
    }
    this.loadingText.textContent = message;
    this.progressBar.style.display = showProgress ? 'block' : 'none';
    this.progressText.style.display = showProgress ? 'block' : 'none';
    this.loadingOverlay.style.display = 'flex';

    this.loadingOverlay.style.opacity = '0';
    setTimeout(() => {
      this.loadingOverlay.style.opacity = '1';
    }, 10);
  }

  hide() {
    this.loadingOverlay.style.opacity = '0';
    setTimeout(() => {
      this.loadingOverlay.style.display = 'none';
      this.resetProgress();
    }, 300);
  }

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

  resetProgress() {
    this.updateProgress(0);
  }

}

window.loadingHandler = new LoadingHandler();


const loadingStyle = document.createElement('style');
loadingStyle.textContent = `
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
document.head.appendChild(loadingStyle);
