// ヘッダー関連のJS機能

// モバイルメニューの制御
function toggleMobileMenu() {
    const mobileNav = document.getElementById('mobile-nav');
    const toggleButton = document.querySelector('.mobile-menu-toggle');

    if (mobileNav.classList.contains('active')) {
        mobileNav.classList.remove('active');
        toggleButton.setAttribute('aria-label', 'メニューを開く');
    } else {
        mobileNav.classList.add('active');
        toggleButton.setAttribute('aria-label', 'メニューを閉じる');
    }
}

// メニュー外クリックで閉じる
function setupMobileMenuClickOutside() {
    document.addEventListener('click', function (event) {
        const mobileNav = document.getElementById('mobile-nav');
        const toggleButton = document.querySelector('.mobile-menu-toggle');

        if (!mobileNav.contains(event.target) && !toggleButton.contains(event.target)) {
            mobileNav.classList.remove('active');
            toggleButton.setAttribute('aria-label', 'メニューを開く');
        }
    });
}

// ログアウト確認
function setupLogoutConfirmation() {
    const logoutForms = document.querySelectorAll('.logout-form, .mobile-logout-form');

    logoutForms.forEach(form => {
        form.addEventListener('submit', function (e) {
            if (!confirm('ログアウトしますか？')) {
                e.preventDefault();
            }
        });
    });
}

// ページ初期化
function initializeHeader() {
    setupMobileMenuClickOutside();
    setupLogoutConfirmation();
}

// DOMContentLoaded時に初期化
document.addEventListener('DOMContentLoaded', initializeHeader);

// グローバルに公開
window.toggleMobileMenu = toggleMobileMenu;
window.HeaderUtils = {
    toggleMobileMenu,
    setupMobileMenuClickOutside,
    setupLogoutConfirmation,
    initializeHeader
};
