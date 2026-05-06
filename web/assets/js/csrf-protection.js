/**
 * CSRF Protection Helper
 * Provides CSRF token management for AJAX requests and forms
 */

class CSRFProtection {
    constructor() {
        this.token = null;
        this.headerName = 'X-CSRF-Token';
        this.parameterName = 'csrf_token';
        this.tokenEndpoint = '/api/csrf/token';
        this.init();
    }

    /**
     * Initialize CSRF protection
     */
    async init() {
        // Get token from meta tag if available
        const metaToken = document.querySelector('meta[name="csrf-token"]');
        if (metaToken) {
            this.token = metaToken.getAttribute('content');
        }

        // Fetch token from server if not available
        if (!this.token) {
            await this.fetchToken();
        }

        // Setup automatic token refresh
        this.setupTokenRefresh();

        // Setup form protection
        this.setupFormProtection();

        // Setup AJAX protection
        this.setupAJAXProtection();
    }

    /**
     * Fetch CSRF token from server
     */
    async fetchToken() {
        try {
            const response = await fetch(this.tokenEndpoint, {
                method: 'GET',
                credentials: 'same-origin',
                headers: {
                    'Accept': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                this.token = data.token;
                this.headerName = data.headerName || this.headerName;
                this.parameterName = data.parameterName || this.parameterName;

                // Update meta tag
                this.updateMetaTag();
            }
        } catch (error) {
            console.error('Failed to fetch CSRF token:', error);
        }
    }

    /**
     * Update CSRF token meta tag
     */
    updateMetaTag() {
        let metaTag = document.querySelector('meta[name="csrf-token"]');
        if (!metaTag) {
            metaTag = document.createElement('meta');
            metaTag.name = 'csrf-token';
            document.head.appendChild(metaTag);
        }
        metaTag.setAttribute('content', this.token);
    }

    /**
     * Setup automatic token refresh
     */
    setupTokenRefresh() {
        // Refresh token every 30 minutes
        setInterval(() => {
            this.fetchToken();
        }, 30 * 60 * 1000);
    }

    /**
     * Setup form protection
     */
    setupFormProtection() {
        // Add CSRF token to all forms
        document.addEventListener('DOMContentLoaded', () => {
            this.protectAllForms();
        });

        // Watch for dynamically added forms
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach((node) => {
                    if (node.nodeType === 1) { // Element node
                        if (node.tagName === 'FORM') {
                            this.protectForm(node);
                        } else {
                            const forms = node.querySelectorAll('form');
                            forms.forEach(form => this.protectForm(form));
                        }
                    }
                });
            });
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    /**
     * Protect all existing forms
     */
    protectAllForms() {
        const forms = document.querySelectorAll('form');
        forms.forEach(form => this.protectForm(form));
    }

    /**
     * Protect a single form
     */
    protectForm(form) {
        // Check if form already has CSRF token
        if (form.querySelector(`input[name="${this.parameterName}"]`)) {
            return;
        }

        // Create CSRF token input
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = this.parameterName;
        input.value = this.token;

        // Add to form
        form.appendChild(input);

        // Add submit handler to refresh token
        form.addEventListener('submit', (e) => {
            // Refresh token before submission
            this.fetchToken().then(() => {
                input.value = this.token;
            });
        });
    }

    /**
     * Setup AJAX protection
     */
    setupAJAXProtection() {
        // Intercept fetch requests
        const originalFetch = window.fetch;
        window.fetch = async (...args) => {
            const [url, options = {}] = args;

            // Add CSRF token to state-changing requests
            if (this.shouldProtectRequest(url, options)) {
                options.headers = options.headers || {};

                // Add CSRF token header
                if (this.token) {
                    options.headers[this.headerName] = this.token;
                }

                // Add CSRF token to body if it's form data
                if (options.body instanceof FormData) {
                    options.body.append(this.parameterName, this.token);
                }

                // Add CSRF token to body if it's URLSearchParams
                if (options.body instanceof URLSearchParams) {
                    options.body.append(this.parameterName, this.token);
                }
            }

            try {
                const response = await originalFetch(...args);

                // Refresh token on successful state-changing requests
                if (this.shouldProtectRequest(url, options) && response.ok) {
                    this.fetchToken();
                }

                return response;
            } catch (error) {
                console.error('Request failed:', error);
                throw error;
            }
        };

        // Intercept XMLHttpRequest
        const originalOpen = XMLHttpRequest.prototype.open;
        const originalSend = XMLHttpRequest.prototype.send;

        XMLHttpRequest.prototype.open = function(method, url, ...args) {
            this._method = method;
            this._url = url;
            return originalOpen.call(this, method, url, ...args);
        };

        XMLHttpRequest.prototype.send = function(body) {
            if (csrfProtection.shouldProtectRequest(this._url, { method: this._method })) {
                // Add CSRF token header
                if (csrfProtection.token) {
                    this.setRequestHeader(csrfProtection.headerName, csrfProtection.token);
                }
            }
            return originalSend.call(this, body);
        };
    }

    /**
     * Check if request should be protected
     */
    shouldProtectRequest(url, options) {
        const method = (options.method || 'GET').toUpperCase();

        // Only protect state-changing methods
        if (!['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
            return false;
        }

        // Check if URL is exempt
        const exemptUrls = [
            '/api/csrf/token',
            '/api/auth/login',
            '/api/auth/logout'
        ];

        return !exemptUrls.some(exemptUrl => url.includes(exemptUrl));
    }

    /**
     * Get current CSRF token
     */
    getToken() {
        return this.token;
    }

    /**
     * Set CSRF token
     */
    setToken(token) {
        this.token = token;
        this.updateMetaTag();
    }

    /**
     * Add CSRF token to options object
     */
    addTokenToOptions(options) {
        options = options || {};
        options.headers = options.headers || {};

        if (this.token) {
            options.headers[this.headerName] = this.token;
        }

        return options;
    }
}

// Initialize CSRF protection
const csrfProtection = new CSRFProtection();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CSRFProtection;
}