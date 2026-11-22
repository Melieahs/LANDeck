import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../models/service_mode.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import '../../services/web_password_fill.dart';
import 'widgets/http_auth_dialog.dart';
import 'widgets/service_switcher_sheet.dart';
import 'widgets/web_password_dialogs.dart';

/// Desktop (Windows/WebView2) viewer for a service URL.
///
/// `webview_flutter` has no Windows implementation, so desktop uses
/// `webview_windows` (WebView2). It mirrors the mobile feature set as far as
/// WebView2 allows: browsing, HTTP basic authentication with saved accounts,
/// login-form autofill and password capture.
class WindowsWebViewPage extends StatefulWidget {
  const WindowsWebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<WindowsWebViewPage> createState() => _WindowsWebViewPageState();
}

class _WindowsWebViewPageState extends State<WindowsWebViewPage> {
  final WebviewController _controller = WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  /// Hosts whose saved basic-auth account was already tried automatically.
  /// A second challenge for the same host always asks the user.
  final Set<String> _basicAuthAttemptedHosts = <String>{};

  /// Hosts that already showed the account picker on this page load.
  final Set<String> _loginFocusPrompts = <String>{};

  Service? _service;
  String? _currentUrl;
  bool _initStarted = false;
  bool _controllerReady = false;
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _authPromptOpen = false;
  bool _savePromptOpen = false;
  bool _fillPromptOpen = false;
  String? _error;
  bool _exiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LanDeckRepository repository = AppScope.of(context);
    final Service? service = repository.serviceById(
      _service?.id ?? widget.serviceId,
    );
    if (!_initStarted) {
      _initStarted = true;
      _service = service;
      if (service != null) {
        unawaited(repository.markServiceOpened(service.id));
        unawaited(_start(service));
      } else {
        setState(() => _loading = false);
      }
      return;
    }
    if (service != null) {
      _service = service;
    }
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _start(Service service) async {
    try {
      await _controller.initialize();
      _subscriptions.add(
        _controller.loadingState.listen((LoadingState state) {
          if (!mounted) {
            return;
          }
          setState(() {
            _loading = state == LoadingState.loading;
            if (!_loading) {
              _error = null;
            }
          });
          if (state == LoadingState.none) {
            unawaited(_autoFillSavedLogin());
          }
        }),
      );
      _subscriptions.add(
        _controller.historyChanged.listen((HistoryChanged history) {
          if (!mounted) {
            return;
          }
          setState(() {
            _canGoBack = history.canGoBack;
            _canGoForward = history.canGoForward;
          });
        }),
      );
      _subscriptions.add(
        _controller.onLoadError.listen((WebErrorStatus status) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = '网页加载失败（$status）';
            _loading = false;
          });
        }),
      );
      _subscriptions.add(
        _controller.url.listen((String url) {
          _currentUrl = url;
          _loginFocusPrompts.clear();
        }),
      );
      _subscriptions.add(
        _controller.webMessage.listen(_onWebMessage, onError: (Object _) {}),
      );
      _subscriptions.add(
        _controller.basicAuthRequested.listen(_onBasicAuthChallenge),
      );

      // Expose the same bridge object the mobile scripts expect, backed by
      // WebView2's postMessage channel.
      await _controller.addScriptToExecuteOnDocumentCreated(
        '${_bridgeShim()}\n${WebPasswordFill.hookScript}',
      );

      if (!mounted) {
        return;
      }
      setState(() => _controllerReady = true);
      await _controller.loadUrl(service.url);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '无法启动内嵌浏览器：$error';
        _loading = false;
      });
    }
  }

  static String _bridgeShim() {
    return '''
window.LandeckPasswordBridge = window.LandeckPasswordBridge || {
  postMessage: (message) => {
    try { window.chrome.webview.postMessage(message); } catch (e) {}
  }
};
''';
  }

  // ---------------------------------------------------------------------------
  // Credentials

  HttpCredential? _preferredAccount(
    List<HttpCredential> accounts,
    String? defaultUsername,
  ) {
    if (accounts.isEmpty) {
      return null;
    }
    for (final HttpCredential account in accounts) {
      if (account.username == defaultUsername) {
        return account;
      }
    }
    return accounts.first;
  }

  String? _formScope() {
    final Uri? uri = Uri.tryParse(_currentUrl ?? '');
    if (uri != null) {
      return WebPasswordFill.scopeHostOf(uri);
    }
    final String? url = _service?.url;
    return WebPasswordFill.scopeHostOf(Uri.tryParse(url ?? ''));
  }

  Future<void> _autoFillSavedLogin() async {
    final Service? service = _service;
    if (service == null || service.passwordFillMode == PasswordFillMode.off) {
      return;
    }
    final String? host = _formScope();
    if (host == null) {
      return;
    }
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(service.id, host: host, realm: WebPasswordFill.webRealm);
    if (accounts.isEmpty || !mounted) {
      return;
    }
    final HttpCredential? account = _preferredAccount(
      accounts,
      service.defaultCredentialUsername,
    );
    if (account == null) {
      return;
    }
    if (service.passwordFillMode == PasswordFillMode.auto) {
      await _controller.executeScript(
        WebPasswordFill.autoFillScript(
          username: account.username,
          password: account.password,
        ),
      );
    }
  }

  void _onWebMessage(dynamic message) {
    // WebView2 delivers the message as JSON, which for a string payload is a
    // quoted JSON string rather than an object.
    dynamic payload = message;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } on FormatException {
        return;
      }
    }
    if (payload is! Map) {
      return;
    }
    final Map<dynamic, dynamic> data = payload;
    final String type = data['type']?.toString() ?? '';
    switch (type) {
      case 'login-focus':
        final String host = data['host']?.toString() ?? '';
        unawaited(_promptFillOnFocus(host));
        break;
      case 'credentials':
        final String host = data['host']?.toString() ?? '';
        final String username = data['username']?.toString() ?? '';
        final String password = data['password']?.toString() ?? '';
        if (username.isEmpty || password.isEmpty) {
          return;
        }
        unawaited(_promptSaveLogin(host, username, password));
        break;
    }
  }

  Future<void> _promptFillOnFocus(String host) async {
    final Service? service = _service;
    if (service == null ||
        service.passwordFillMode != PasswordFillMode.ask ||
        host.isEmpty ||
        _fillPromptOpen ||
        _loginFocusPrompts.contains(host)) {
      return;
    }
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(service.id, host: host, realm: WebPasswordFill.webRealm);
    if (accounts.isEmpty || !mounted) {
      return;
    }
    _loginFocusPrompts.add(host);
    _fillPromptOpen = true;
    try {
      final HttpCredential? account = await showCredentialPicker(
        context,
        credentials: accounts,
        defaultUsername: service.defaultCredentialUsername,
      );
      if (account == null || !mounted) {
        return;
      }
      await _controller.executeScript(
        WebPasswordFill.fillScript(
          username: account.username,
          password: account.password,
        ),
      );
      if (mounted) {
        showAppSnackBar(context, '已填充账号 ${account.username}');
      }
    } finally {
      _fillPromptOpen = false;
    }
  }

  Future<void> _promptSaveLogin(
    String host,
    String username,
    String password,
  ) async {
    final Service? service = _service;
    if (service == null || host.isEmpty || _savePromptOpen) {
      return;
    }
    final List<HttpCredential> saved = await HttpCredentialStore.instance
        .accountsFor(service.id, host: host, realm: WebPasswordFill.webRealm);
    final bool exists = saved.any(
      (HttpCredential item) =>
          item.username == username && item.password == password,
    );
    if (exists || !mounted) {
      return;
    }
    _savePromptOpen = true;
    try {
      final bool remember = await showSaveWebPasswordDialog(
        context,
        serviceName: service.name,
        host: host,
        username: username,
      );
      if (!remember) {
        return;
      }
      await HttpCredentialStore.instance.save(
        HttpCredential(
          serviceId: service.id,
          host: host,
          realm: WebPasswordFill.webRealm,
          username: username,
          password: password,
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        showAppSnackBar(context, '已保存登录信息');
      }
    } finally {
      _savePromptOpen = false;
    }
  }

  Future<void> _onBasicAuthChallenge(BasicAuthChallenge challenge) async {
    final Service? service = _service;
    if (service == null || _authPromptOpen) {
      await _controller.respondBasicAuth(challenge.id, cancel: true);
      return;
    }
    final String host = challenge.host;
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(service.id, host: host, realm: '');
    final HttpCredential? saved = _preferredAccount(
      accounts,
      service.defaultCredentialUsername,
    );

    // Try one saved account silently, then ask the user. WebView2 gives us no
    // success signal, so a repeated challenge means the guess was rejected.
    if (saved != null &&
        service.passwordFillMode == PasswordFillMode.auto &&
        !_basicAuthAttemptedHosts.contains(host)) {
      _basicAuthAttemptedHosts.add(host);
      await _controller.respondBasicAuth(
        challenge.id,
        username: saved.username,
        password: saved.password,
      );
      return;
    }

    if (!mounted) {
      await _controller.respondBasicAuth(challenge.id, cancel: true);
      return;
    }
    _authPromptOpen = true;
    try {
      final HttpCredential? stale = _basicAuthAttemptedHosts.contains(host)
          ? saved
          : null;
      if (stale != null) {
        await HttpCredentialStore.instance.deleteCredential(
          service.id,
          host: host,
          realm: '',
          username: stale.username,
        );
      }
      if (!mounted) {
        await _controller.respondBasicAuth(challenge.id, cancel: true);
        return;
      }
      final HttpAuthResult? result = await showHttpAuthDialog(
        context,
        serviceName: service.name,
        address: service.address,
        host: host,
        realm: '受限资源',
        initialUsername: stale?.username,
        errorText: stale != null ? '认证失败，请检查用户名和密码' : null,
      );
      if (result == null) {
        await _controller.respondBasicAuth(challenge.id, cancel: true);
        return;
      }
      if (result.remember) {
        await HttpCredentialStore.instance.save(
          HttpCredential(
            serviceId: service.id,
            host: host,
            realm: '',
            username: result.username,
            password: result.password,
            updatedAt: DateTime.now(),
          ),
        );
      }
      await _controller.respondBasicAuth(
        challenge.id,
        username: result.username,
        password: result.password,
      );
    } finally {
      _authPromptOpen = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation

  void _exit() {
    if (_exiting) {
      return;
    }
    _exiting = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    await _controller.reload();
  }

  Future<void> _openExternally() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(service.url);
    if (uri == null) {
      return;
    }
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showAppSnackBar(context, '无法打开系统浏览器');
    }
  }

  Future<void> _openServiceSwitcher() async {
    final LanDeckRepository repository = AppScope.of(context);
    final Service? current = _service;
    if (current == null) {
      return;
    }
    final ServiceSelection? selection = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: current,
      currentMode: ServiceMode.web,
      deviceNameFor: repository.deviceNameFor,
      openServiceIds: const <String>{},
    );
    if (selection == null || !mounted) {
      return;
    }
    setState(() {
      _service = selection.service;
      _error = null;
      _loading = true;
      _canGoBack = false;
      _canGoForward = false;
    });
    _basicAuthAttemptedHosts.clear();
    _loginFocusPrompts.clear();
    await _controller.loadUrl(selection.service.url);
  }

  @override
  Widget build(BuildContext context) {
    final Service? service = _service;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey<String>('windows-webview-exit'),
          tooltip: '退出',
          onPressed: _exit,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: service == null
            ? const Text('服务')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    Uri.tryParse(service.url)?.host ?? service.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('windows-webview-back'),
            tooltip: '后退',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _canGoBack ? _controller.goBack : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-forward'),
            tooltip: '前进',
            icon: const Icon(Icons.redo_rounded),
            onPressed: _canGoForward ? _controller.goForward : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-reload'),
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _controllerReady ? _reload : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-service-switch'),
            tooltip: '切换服务',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: service == null ? null : _openServiceSwitcher,
          ),
        ],
      ),
      body: _buildBody(service),
    );
  }

  Widget _buildBody(Service? service) {
    if (service == null) {
      return const Center(child: Text('服务不存在或已被删除'));
    }
    if (_error != null) {
      return _WindowsWebError(
        message: _error!,
        onRetry: _reload,
        onOpenExternal: _openExternally,
      );
    }
    if (!_controllerReady) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(height: 14),
            Text('正在启动内嵌浏览器…'),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: Webview(_controller)),
      ],
    );
  }
}

class _WindowsWebError extends StatelessWidget {
  const _WindowsWebError({
    required this.message,
    required this.onRetry,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.public_off_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: onOpenExternal,
                    child: const Text('用系统浏览器打开'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
