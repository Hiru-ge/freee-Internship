class MobileMenuHandler {
    constructor() {
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupMobileMenu();
        });
    }

    setupMobileMenu() {
        const toggleButton = document.querySelector('.mobile-menu-toggle');
        if (toggleButton) {
            toggleButton.addEventListener('click', () => {
                this.toggleMobileMenu();
            });
        }
    }

    toggleMobileMenu() {
        const mobileNav = document.getElementById('mobile-nav');
        const toggleButton = document.querySelector('.mobile-menu-toggle');

        if (mobileNav && toggleButton) {
            if (mobileNav.classList.contains('active')) {
                mobileNav.classList.remove('active');
                toggleButton.setAttribute('aria-label', 'メニューを開く');
            } else {
                mobileNav.classList.add('active');
                toggleButton.setAttribute('aria-label', 'メニューを閉じる');
            }
        }
    }
}

new MobileMenuHandler();
