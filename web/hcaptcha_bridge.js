(() => {
  let widgetId = null;
  let token = '';
  let attempts = 0;

  const api = {
    render(element) {
      if (!window.hcaptcha) {
        if (++attempts > 40) {
          element.textContent = 'CAPTCHA failed to load. Please refresh the page.';
          return;
        }
        element.textContent = 'Loading CAPTCHA...';
        setTimeout(() => api.render(element), 500);
        return;
      }
      attempts = 0;

      if (widgetId !== null) {
        try { window.hcaptcha.remove(widgetId); } catch (_) {}
        widgetId = null;
      }

      element.textContent = '';
      token = '';

      widgetId = window.hcaptcha.render(element, {
        sitekey: '5d4888e2-3484-4486-9e66-8f1e050002f2',
        size: 'compact',
        callback: (v) => { token = v; },
        'expired-callback': () => { token = ''; },
        'error-callback': () => { token = ''; },
      });
    },
    getToken() { return token; },
    reset() {
      token = '';
      try {
        if (window.hcaptcha && widgetId !== null) window.hcaptcha.reset(widgetId);
      } catch (_) {}
    },
  };

  window.innovistaCaptcha = api;
})();