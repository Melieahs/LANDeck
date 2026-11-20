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

  static String fillScript({
    required String username,
    required String password,
  }) {
    final String user = jsonEncode(username);
    final String pass = jsonEncode(password);
    return '''
(function () {
  const visible = (el) => {
    if (!el || el.disabled) return false;
    const style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden';
  };
  const inputs = Array.from(document.querySelectorAll('input[type="password"]')).filter(visible);
  if (!inputs.length) return JSON.stringify({ok: false, reason: 'no-password'});
  const passwordInput = inputs[0];
  const root = passwordInput.form || document;
  const candidates = Array.from(root.querySelectorAll(
    'input[autocomplete="username"], input[type="email"], input[type="text"], input[name*="user" i], input[name*="email" i], input[id*="user" i]'
  )).filter((el) => visible(el) && el !== passwordInput);
  const usernameInput = candidates.length ? candidates[0] : null;
  const setValue = (el, value) => {
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(el, value);
    el.dispatchEvent(new Event('input', {bubbles: true}));
    el.dispatchEvent(new Event('change', {bubbles: true}));
  };
  if (usernameInput) setValue(usernameInput, $user);
  setValue(passwordInput, $pass);
  return JSON.stringify({
    ok: true,
    username: !!usernameInput,
    host: location.hostname,
  });
})();
''';
  }

  static const String captureScript = '''
(function () {
  const visible = (el) => {
    if (!el || el.disabled) return false;
    const style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden';
  };
  const inputs = Array.from(document.querySelectorAll('input[type="password"]')).filter(visible);
  if (!inputs.length) return JSON.stringify({ok: false, reason: 'no-password'});
  const passwordInput = inputs[0];
  const root = passwordInput.form || document;
  const candidates = Array.from(root.querySelectorAll(
    'input[autocomplete="username"], input[type="email"], input[type="text"], input[name*="user" i], input[name*="email" i], input[id*="user" i]'
  )).filter((el) => visible(el) && el !== passwordInput);
  return JSON.stringify({
    ok: true,
    host: location.hostname,
    username: candidates.length ? candidates[0].value : '',
    password: passwordInput.value || '',
  });
})();
''';

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
