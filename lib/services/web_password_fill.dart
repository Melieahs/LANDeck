import 'dart:convert';

/// Helpers for filling and capturing credentials in ordinary web login forms.
///
/// Everything here runs in the page's own JavaScript context. Values are
/// serialized with [jsonEncode] so quotes/newlines cannot break out of the
/// generated script. Passwords are never written to logs.
abstract final class WebPasswordFill {
  /// Realm used by web-form credentials. HTTP Basic realms come from servers.
  static const String webRealm = 'web-form';

  static String? hostOf(String? url) {
    final Uri? uri = Uri.tryParse(url ?? '');
    final String host = uri?.host.trim().toLowerCase() ?? '';
    return host.isEmpty ? null : host;
  }

  /// DOM helpers shared by the capture/fill scripts.
  ///
  /// They deliberately walk open shadow roots and same-origin iframes because
  /// appliances such as CasaOS render their login form inside a web component
  /// and omit the HTML <form> element entirely.
  static const String _helpers = r'''
  const visible = (el) => {
    if (!el || el.disabled || el.type === 'hidden') return false;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false;
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };
  const roots = () => {
    const found = [];
    const visit = (root) => {
      if (!root || found.indexOf(root) !== -1) return;
      found.push(root);
      try {
        root.querySelectorAll('*').forEach((el) => {
          if (el.shadowRoot) visit(el.shadowRoot);
        });
      } catch (e) {}
      try {
        root.querySelectorAll('iframe').forEach((frame) => {
          try {
            if (frame.contentDocument) visit(frame.contentDocument);
          } catch (e) {}
        });
      } catch (e) {}
    };
    visit(document);
    return found;
  };
  const all = (selector) => {
    const out = [];
    roots().forEach((root) => {
      try {
        root.querySelectorAll(selector).forEach((el) => out.push(el));
      } catch (e) {}
    });
    return out;
  };
  const findUsername = (password) => {
    let node = password;
    for (let depth = 0; depth < 8 && node; depth += 1, node = node.parentElement) {
      let candidates = [];
      try {
        candidates = Array.from(node.querySelectorAll(
          'input[autocomplete="username"], input[type="email"], input[type="text"], input:not([type])'
        ));
      } catch (e) {}
      const match = candidates.find((el) => visible(el) && el !== password);
      if (match) return match;
    }
    const inputs = all('input');
    const index = inputs.indexOf(password);
    for (let i = index - 1; i >= 0; i -= 1) {
      const el = inputs[i];
      if (visible(el) && (el.type === 'text' || el.type === 'email' || !el.type)) {
        return el;
      }
    }
    return null;
  };
  const findPassword = (target) => {
    if (target && target.matches && target.matches('input[type="password"]')) return target;
    if (target && target.closest) {
      try {
        const form = target.closest('form');
        if (form) {
          const inside = form.querySelector('input[type="password"]');
          if (inside) return inside;
        }
      } catch (e) {}
      let node = target;
      for (let depth = 0; depth < 8 && node; depth += 1, node = node.parentElement) {
        try {
          const inside = node.querySelector && node.querySelector('input[type="password"]');
          if (inside) return inside;
        } catch (e) {}
      }
    }
    const active = document.activeElement;
    if (active && active.matches && active.matches('input[type="password"]')) return active;
    const passwords = all('input[type="password"]').filter(visible);
    return passwords.find((el) => el.value) || passwords[0] || null;
  };
  const setValue = (el, value) => {
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    el.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
  };
  const bridge = () => window.LandeckPasswordBridge ||
    (window.top && window.top !== window ? window.top.LandeckPasswordBridge : null);
  const credentials = (target) => {
    const password = findPassword(target);
    if (!password || !password.value) return null;
    if ((password.autocomplete || '').toLowerCase() === 'new-password') return null;
    const username = findUsername(password);
    if (!username || !username.value) return null;
    return {
      type: 'credentials',
      host: location.hostname,
      username: username.value,
      password: password.value
    };
  };
''';

  static String fillScript({
    required String username,
    required String password,
  }) {
    final String user = jsonEncode(username);
    final String pass = jsonEncode(password);
    return '''
(function () {
  $_helpers
  const passwords = all('input[type="password"]').filter(visible);
  if (!passwords.length) return JSON.stringify({ok: false, reason: 'no-password'});
  const passwordInput = passwords[0];
  const usernameInput = findUsername(passwordInput);
  if (usernameInput) setValue(usernameInput, $user);
  setValue(passwordInput, $pass);
  return JSON.stringify({
    ok: true,
    username: !!usernameInput,
    host: location.hostname
  });
})();
''';
  }

  static const String captureScript =
      '''
(function () {
  $_helpers
  const password = findPassword(null);
  if (!password) return JSON.stringify({ok: false, reason: 'no-password'});
  const username = findUsername(password);
  return JSON.stringify({
    ok: true,
    host: location.hostname,
    username: username ? username.value : '',
    password: password.value || ''
  });
})();
''';

  /// Installs capture listeners once per document. They only report when the
  /// user actually submits a form or presses a login control, so merely typing
  /// a password never triggers a save prompt.
  ///
  /// CasaOS-style pages have no <form>; the listener therefore falls back to
  /// the closest container, the focused password field, or any visible filled
  /// password field on the page.
  static const String hookScript =
      '''
(function () {
  if (window.__landeckPasswordHooks) return;
  window.__landeckPasswordHooks = true;
  $_helpers
  const send = (target) => {
    const value = credentials(target);
    if (!value) return;
    const channel = bridge();
    if (channel) channel.postMessage(JSON.stringify(value));
  };
  document.addEventListener('submit', (event) => send(event.target), true);
  document.addEventListener('click', (event) => {
    const target = event.target;
    if (!target || !target.closest) return;
    const control = target.closest('button, input[type="submit"], [role="button"], a');
    if (!control) return;
    const label = String(control.innerText || control.value || '').trim();
    if (control.tagName === 'A' && label &&
        !/登录|登陆|login|sign\\s*in|submit/i.test(label)) {
      return;
    }
    send(control);
  }, true);
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') send(event.target);
  }, true);
})();
''';

  /// Fills only empty login fields. It never overwrites text the user has
  /// already typed and never submits the form.
  ///
  /// A login page can be rendered after onPageFinished (Vue/React hydration)
  /// or replaced during client-side routing, so the agent keeps retrying and
  /// watches for newly inserted password fields.
  static String autoFillScript({
    required String username,
    required String password,
  }) {
    final String user = jsonEncode(username);
    final String pass = jsonEncode(password);
    return '''
(function () {
  $_helpers
  const fillOnce = () => {
    let filled = false;
    all('input[type="password"]').filter(visible).forEach((passwordInput) => {
      if (passwordInput.value) return;
      if ((passwordInput.autocomplete || '').toLowerCase() === 'new-password') return;
      if (passwordInput.dataset.landeckAutofilled === '1') return;
      const usernameInput = findUsername(passwordInput);
      if (usernameInput && !usernameInput.value) {
        setValue(usernameInput, $user);
        usernameInput.dataset.landeckAutofilled = '1';
      }
      setValue(passwordInput, $pass);
      passwordInput.dataset.landeckAutofilled = '1';
      filled = true;
    });
    return filled;
  };
  let attempts = 0;
  let debounce;
  const tick = () => {
    attempts += 1;
    fillOnce();
    if (attempts < 20) window.setTimeout(tick, 400);
  };
  tick();
  window.addEventListener('hashchange', () => window.setTimeout(fillOnce, 250));
  window.addEventListener('popstate', () => window.setTimeout(fillOnce, 250));
  try {
    const observer = new MutationObserver(() => {
      window.clearTimeout(debounce);
      debounce = window.setTimeout(fillOnce, 120);
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
    window.setTimeout(() => observer.disconnect(), 30000);
  } catch (e) {}
  return JSON.stringify({ok: true, host: location.hostname});
})();
''';
  }

  static Map<String, Object?>? decodeResult(Object? raw) {
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is String) decoded = jsonDecode(decoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }
}
