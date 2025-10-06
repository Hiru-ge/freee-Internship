// 関数ベースのローディングユーティリティ
let loadingOverlay = null;
let progressBar = null;
let loadingText = null;
let progressText = null;

function createOverlay() {
  loadingOverlay = createOverlayElement();
  const loadingContainer = createLoadingContainer();
  const spinner = createSpinner();
  loadingText = createLoadingText();
  progressBar = createProgressBar();
  progressText = createProgressText();
  loadingContainer.appendChild(spinner);
  loadingContainer.appendChild(loadingText);
  loadingContainer.appendChild(progressBar);
  loadingContainer.appendChild(progressText);
  loadingOverlay.appendChild(loadingContainer);
  document.body.appendChild(loadingOverlay);
}

function ensureOverlay() {
  if (loadingOverlay) return;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', createOverlay);
  } else {
    createOverlay();
  }
}

function createOverlayElement() {
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

function createLoadingContainer() {
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

function createSpinner() {
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

function createLoadingText() {
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

function createProgressBar() {
  const bar = document.createElement('div');
  bar.style.cssText = `
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
  bar.appendChild(progressFill);
  return bar;
}

function createProgressText() {
  const text = document.createElement('div');
  text.style.cssText = `
    color: #999;
    font-size: 12px;
  `;
  text.textContent = '0%';
  return text;
}

function show(message = '読み込み中...', showProgress = false) {
  ensureOverlay();
  if (!loadingOverlay || !loadingText) {
    // DOMContentLoaded前に呼ばれた場合のフォールバック
    document.addEventListener('DOMContentLoaded', () => show(message, showProgress));
    return;
  }
  loadingText.textContent = message;
  progressBar.style.display = showProgress ? 'block' : 'none';
  progressText.style.display = showProgress ? 'block' : 'none';
  loadingOverlay.style.display = 'flex';
  loadingOverlay.style.opacity = '0';
  setTimeout(() => {
    loadingOverlay.style.opacity = '1';
  }, 10);
}

function hide() {
  if (!loadingOverlay) return;
  loadingOverlay.style.opacity = '0';
  setTimeout(() => {
    loadingOverlay.style.display = 'none';
    resetProgress();
  }, 300);
}

function updateProgress(percentage, message = null) {
  const progressFill = document.getElementById('progress-fill');
  if (progressFill && progressText) {
    progressFill.style.width = `${Math.min(100, Math.max(0, percentage))}%`;
    progressText.textContent = `${Math.round(percentage)}%`;
  }
  if (message && loadingText) {
    loadingText.textContent = message;
  }
}

function resetProgress() {
  updateProgress(0);
}

window.loadingHandler = { show, hide, updateProgress, resetProgress };


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
