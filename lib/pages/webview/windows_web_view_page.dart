import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
///
/// Every opened service keeps its own `WebviewController` alive, so switching
/// services behaves like browser tabs: the previous page is not reloaded when
/// the user comes back. Controllers are released when the viewer is closed.
class WindowsWebViewPage extends StatefulWidget {
  const WindowsWebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<WindowsWebViewPage> createState() => _WindowsWebViewPageState();
}

class _WindowsTab {
  _WindowsTab(this.service) : controller = WebviewController();

  Service service;
  final WebviewController controller;
  final List<StreamSubscription<dynamic>> subscriptions =
      <StreamSubscription<dynamic>>[];

  /// Hosts whose saved basic-auth account was already tried automatically.
  /// A second challenge for the same host always asks the user.
  final Set<String> basicAuthAttemptedHosts = <String>{};

  /// Hosts that already showed the account picker on this page load.
  final Set<String> loginFocusPrompts = <String>{};

  String? currentUrl;
  bool ready = false;
  bool loading = true;
  bool canGoBack = false;
  bool canGoForward = false;
  String? error;
  int lastUsed = 0;
  bool disposed = false;

  Future<void> dispose() async {
    disposed = true;
    for (final StreamSubscription<dynamic> subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    await controller.dispose();
  }
}

class _WindowsWebViewPageState extends State<WindowsWebViewPage> {
  static const int _maxTabs = 4;

  final Map<String, _WindowsTab> _tabs = <String, _WindowsTab>{};
  String? _activeId;
  int _tick = 0;
  bool _bootstrapped = false;
  bool _missingService = false;
  bool _exiting = false;
  bool _authPromptOpen = false;
  bool _savePromptOpen = false;
  bool _fillPromptOpen = false;

  _WindowsTab? get _active => _activeId == null ? null : _tabs[_activeId];
  Service? get _service => _active?.service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LanDeckRepository repository = AppScope.of(context);
    if (!_bootstrapped) {
      _bootstrapped = true;
      final Service? service = repository.serviceById(widget.serviceId);
      if (service == null) {
        setState(() => _missingService = true);
        return;
      }
      _activeId = service.id;
      unawaited(repository.markServiceOpened(service.id));
      unawaited(_openTab(service));
      return;
    }
    final _WindowsTab? active = _active;
    if (active != null) {
      final Service? latest = repository.serviceById(active.service.id);
      if (latest != null) {
        active.service = latest;
      }
    }
  }

  @override
  void dispose() {
    for (final _WindowsTab tab in _tabs.values) {
      unawaited(tab.dispose());
    }
    _tabs.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tabs

  Future<_WindowsTab?> _openTab(Service service) async {
    final _WindowsTab? existing = _tabs[service.id];
    if (existing != null) {
      existing.service = service;
      existing.lastUsed = ++_tick;
      return existing;
    }
    final _WindowsTab tab = _WindowsTab(service)..lastUsed = ++_tick;
    _tabs[service.id] = tab;
    _trimTabs();
    _attach(tab);
    if (mounted) {
      setState(() {});
    }
    try {
      await tab.controller.initialize();
      if (tab.disposed) {
        return tab;
      }
      tab.ready = true;
      // Expose the same bridge object the mobile scripts expect, backed by
      // WebView2's postMessage channel.
      await tab.controller.addScriptToExecuteOnDocumentCreated(
        '${_bridgeShim()}\n${WebPasswordFill.hookScript}',
      );
      await tab.controller.loadUrl(service.url);
    } on Object catch (error) {
      tab.error = '无法启动内嵌浏览器：$error';
      tab.loading = false;
    }
    if (mounted) {
      setState(() {});
    }
    return tab;
  }

  void _trimTabs() {
    if (_tabs.length <= _maxTabs) {
      return;
    }
    final List<_WindowsTab> candidates = _tabs.values
        .where((_WindowsTab tab) => tab.service.id != _activeId)
        .toList()
      ..sort((_WindowsTab a, _WindowsTab b) => a.lastUsed.compareTo(b.lastUsed));
    for (final _WindowsTab tab in candidates) {
      if (_tabs.length <= _maxTabs) {
        break;
      }
      _tabs.remove(tab.service.id);
      unawaited(tab.dispose());
    }
  }

  void _attach(_WindowsTab tab) {
    tab.subscriptions.add(
      tab.controller.loadingState.listen((LoadingState state) {
        tab.loading = state == LoadingState.loading;
        if (!tab.loading) {
          tab.error = null;
        }
        _refresh(tab);
        if (state == LoadingState.none) {
          unawaited(_autoFillSavedLogin(tab));
        }
      }),
    );
    tab.subscriptions.add(
      tab.controller.historyChanged.listen((HistoryChanged history) {
        tab.canGoBack = history.canGoBack;
        tab.canGoForward = history.canGoForward;
        _refresh(tab);
      }),
    );
    tab.subscriptions.add(
      tab.controller.onLoadError.listen((WebErrorStatus status) {
        tab.error = '网页加载失败（$status）';
        tab.loading = false;
        _refresh(tab);
      }),
    );
    tab.subscriptions.add(
      tab.controller.url.listen((String url) {
        tab.currentUrl = url;
        tab.loginFocusPrompts.clear();
        _refresh(tab);
      }),
    );
    tab.subscriptions.add(
      tab.controller.webMessage.listen(
        (dynamic message) => _onWebMessage(tab, message),
        onError: (Object _) {},
      ),
    );
    tab.subscriptions.add(
      tab.controller.basicAuthRequested.listen(
        (BasicAuthChallenge challenge) =>
            unawaited(_onBasicAuthChallenge(tab, challenge)),
      ),
    );
    tab.subscriptions.add(
      tab.controller.downloadStarting.listen(
        (DownloadStarting event) => unawaited(_onDownload(tab, event)),
      ),
    );
  }

  void _refresh(_WindowsTab tab) {
    if (!mounted) {
      return;
    }
    if (tab == _active) {
      setState(() {});
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
  // Downloads

  Future<void> _onDownload(_WindowsTab tab, DownloadStarting event) async {
    try {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: event.suggestedFileName,
      );
      if (location == null) {
        await tab.controller.respondDownload(event.id, cancel: true);
        return;
      }
      await tab.controller.respondDownload(event.id, path: location.path);
      if (mounted) {
        showAppSnackBar(context, '开始下载 ${event.suggestedFileName}');
      }
    } on Object catch (error) {
      await tab.controller.respondDownload(event.id, cancel: true);
      if (mounted) {
        showAppSnackBar(context, '无法保存下载文件：$error');
      }
    }
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

  String? _formScope(_WindowsTab tab) {
    final Uri? uri = Uri.tryParse(tab.currentUrl ?? '');
    if (uri != null) {
      return WebPasswordFill.scopeHostOf(uri);
    }
    return WebPasswordFill.scopeHostOf(Uri.tryParse(tab.service.url));
  }

  Future<void> _autoFillSavedLogin(_WindowsTab tab) async {
    final Service service = tab.service;
    if (service.passwordFillMode == PasswordFillMode.off) {
      return;
    }
    final String? host = _formScope(tab);
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
      await tab.controller.executeScript(
        WebPasswordFill.autoFillScript(
          username: account.username,
          password: account.password,
        ),
      );
    }
  }

  void _onWebMessage(_WindowsTab tab, dynamic message) {
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
        unawaited(_promptFillOnFocus(tab, host));
        break;
      case 'credentials':
        final String host = data['host']?.toString() ?? '';
        final String username = data['username']?.toString() ?? '';
        final String password = data['password']?.toString() ?? '';
        if (username.isEmpty || password.isEmpty) {
          return;
        }
        unawaited(_promptSaveLogin(tab, host, username, password));
        break;
    }
  }

  Future<void> _promptFillOnFocus(_WindowsTab tab, String host) async {
    if (tab.service.passwordFillMode != PasswordFillMode.ask ||
        host.isEmpty ||
        _fillPromptOpen ||
        tab.loginFocusPrompts.contains(host)) {
      return;
    }
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(
            tab.service.id, host: host, realm: WebPasswordFill.webRealm);
    if (accounts.isEmpty || !mounted) {
      return;
    }
    tab.loginFocusPrompts.add(host);
    _fillPromptOpen = true;
    try {
      final HttpCredential? account = await showCredentialPicker(
        context,
        credentials: accounts,
        defaultUsername: tab.service.defaultCredentialUsername,
      );
      if (account == null || !mounted) {
        return;
      }
      await tab.controller.executeScript(
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
    _WindowsTab tab,
    String host,
    String username,
    String password,
  ) async {
    if (host.isEmpty || _savePromptOpen) {
      return;
    }
    final List<HttpCredential> saved = await HttpCredentialStore.instance
        .accountsFor(
            tab.service.id, host: host, realm: WebPasswordFill.webRealm);
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
        serviceName: tab.service.name,
        host: host,
        username: username,
      );
      if (!remember) {
        return;
      }
      await HttpCredentialStore.instance.save(
        HttpCredential(
          serviceId: tab.service.id,
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

  Future<void> _onBasicAuthChallenge(
    _WindowsTab tab,
    BasicAuthChallenge challenge,
  ) async {
    if (_authPromptOpen) {
      await tab.controller.respondBasicAuth(challenge.id, cancel: true);
      return;
    }
    final String host = challenge.host;
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(tab.service.id, host: host, realm: '');
    final HttpCredential? saved = _preferredAccount(
      accounts,
      tab.service.defaultCredentialUsername,
    );

    // Try one saved account silently, then ask the user. WebView2 gives us no
    // success signal, so a repeated challenge means the guess was rejected.
    if (saved != null &&
        tab.service.passwordFillMode == PasswordFillMode.auto &&
        !tab.basicAuthAttemptedHosts.contains(host)) {
      tab.basicAuthAttemptedHosts.add(host);
      await tab.controller.respondBasicAuth(
        challenge.id,
        username: saved.username,
        password: saved.password,
      );
      return;
    }

    if (!mounted) {
      await tab.controller.respondBasicAuth(challenge.id, cancel: true);
      return;
    }
    _authPromptOpen = true;
    try {
      final HttpCredential? stale =
          tab.basicAuthAttemptedHosts.contains(host) ? saved : null;
      if (stale != null) {
        await HttpCredentialStore.instance.deleteCredential(
          tab.service.id,
          host: host,
          realm: '',
          username: stale.username,
        );
      }
      if (!mounted) {
        await tab.controller.respondBasicAuth(challenge.id, cancel: true);
        return;
      }
      final HttpAuthResult? result = await showHttpAuthDialog(
        context,
        serviceName: tab.service.name,
        address: tab.service.address,
        host: host,
        realm: '受限资源',
        initialUsername: stale?.username,
        errorText: stale != null ? '认证失败，请检查用户名和密码' : null,
      );
      if (result == null) {
        await tab.controller.respondBasicAuth(challenge.id, cancel: true);
        return;
      }
      if (result.remember) {
        await HttpCredentialStore.instance.save(
          HttpCredential(
            serviceId: tab.service.id,
            host: host,
            realm: '',
            username: result.username,
            password: result.password,
            updatedAt: DateTime.now(),
          ),
        );
      }
      await tab.controller.respondBasicAuth(
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
    for (final _WindowsTab tab in _tabs.values) {
      unawaited(tab.dispose());
    }
    _tabs.clear();
    Navigator.of(context).maybePop();
  }

  Future<void> _reload(_WindowsTab tab) async {
    setState(() => tab.error = null);
    await tab.controller.reload();
  }

  Future<void> _retry(_WindowsTab tab) async {
    final Service service = tab.service;
    _tabs.remove(service.id);
    await tab.dispose();
    if (!mounted) {
      return;
    }
    setState(() {});
    await _openTab(service);
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
      openServiceIds: _tabs.keys.toSet(),
    );
    if (selection == null || !mounted) {
      return;
    }
    setState(() => _activeId = selection.service.id);
    await _openTab(selection.service);
  }

  @override
  Widget build(BuildContext context) {
    final _WindowsTab? tab = _active;
    final Service? service = tab?.service;
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
                    Uri.tryParse(tab?.currentUrl ?? service.url)?.host ??
                        service.address,
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
            onPressed: tab != null && tab.canGoBack
                ? () => tab.controller.goBack()
                : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-forward'),
            tooltip: '前进',
            icon: const Icon(Icons.redo_rounded),
            onPressed: tab != null && tab.canGoForward
                ? () => tab.controller.goForward()
                : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-reload'),
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: tab != null && tab.ready ? () => _reload(tab) : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-service-switch'),
            tooltip: '切换服务',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: service == null ? null : _openServiceSwitcher,
          ),
        ],
      ),
      body: _buildBody(tab),
    );
  }

  Widget _buildBody(_WindowsTab? tab) {
    if (_missingService || tab == null) {
      return const Center(child: Text('服务不存在或已被删除'));
    }
    if (tab.error != null) {
      return _WindowsWebError(
        message: tab.error!,
        onRetry: () => _retry(tab),
        onOpenExternal: _openExternally,
      );
    }
    if (!tab.ready) {
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
        if (tab.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey<String>(tab.service.id),
            child: Webview(tab.controller),
          ),
        ),
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
