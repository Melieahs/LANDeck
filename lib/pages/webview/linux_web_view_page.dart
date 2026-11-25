import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../models/service_mode.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import '../../services/web_password_fill.dart';
import 'widgets/http_auth_dialog.dart';
import 'widgets/more_actions_sheet.dart';
import 'widgets/service_switcher_sheet.dart';
import 'widgets/web_error_view.dart';
import 'widgets/web_password_dialogs.dart';
import 'widgets/webview_bar_action.dart';

/// Web viewer for Linux backed by WebKitGTK through `webview_all`.
///
/// The page mirrors the viewer chrome used by mobile and Windows: a compact
/// Material 3 top bar, the shared more-actions sheet and the same password
/// autofill pipeline. The embedded engine is WebKitGTK 4.1.
class LinuxWebViewPage extends StatefulWidget {
  const LinuxWebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<LinuxWebViewPage> createState() => _LinuxWebViewPageState();
}

class _LinuxWebViewPageState extends State<LinuxWebViewPage> {
  WebViewController? _controller;
  Service? _service;
  bool _configured = false;

  bool _loading = true;
  int _progress = 0;
  bool _hasError = false;
  String? _error;
  String? _currentUrl;
  String? _title;
  bool _canGoBack = false;
  bool _canGoForward = false;

  String? _pageScope;
  final Set<String> _loginFocusPrompts = <String>{};
  bool _passwordPromptOpen = false;

  bool _authDialogOpen = false;
  int _authAttempts = 0;
  final Set<String> _autoTriedScopes = <String>{};
  final Set<String> _cancelledScopes = <String>{};
  final Set<String> _blockedHosts = <String>{};
  final Map<String, HttpCredential> _sessionCredentials = <String, HttpCredential>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Service? current = AppScope.of(context).serviceById(widget.serviceId);
    if (current == null || _configured) {
      return;
    }
    _service = current;
    _configured = true;
    _configure(current);
  }

  void _configure(Service service) {
    final Uri uri = Uri.parse(service.url);
    final WebViewController controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onProgress: (int progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loading = progress < 100;
              _progress = progress;
            });
          },
          onHttpAuthRequest: _onHttpAuthRequest,
          onWebResourceError: (WebResourceError error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }
            setState(() {
              _loading = false;
              _hasError = true;
              _error = error.description;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'LandeckPasswordBridge',
        onMessageReceived: _onPasswordBridgeMessage,
      )
      ..loadRequest(uri);
    setState(() {
      _controller = controller;
    });
  }

  void _onPageStarted(String url) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _progress = 0;
      _hasError = false;
      _error = null;
      _currentUrl = url;
      _pageScope = WebPasswordFill.scopeHostOf(Uri.tryParse(url));
      _loginFocusPrompts.clear();
    });
    _refreshHistory();
  }

  void _onPageFinished(String url) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _progress = 100;
      _currentUrl = url;
    });
    _refreshHistory();
    unawaited(_autoFillSavedLogin(url));
  }

  Future<void> _refreshHistory() async {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final bool back = await controller.canGoBack();
      final bool forward = await controller.canGoForward();
      if (!mounted) {
        return;
      }
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    } on Object {
      // History queries are best effort.
    }
  }

  Future<void> _back() async {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.goBack();
    await _refreshHistory();
  }

  Future<void> _forward() async {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.goForward();
    await _refreshHistory();
  }

  Future<void> _reload() async {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    setState(() {
      _hasError = false;
      _loading = true;
    });
    await controller.reload();
  }

  void _exit() {
    Navigator.of(context).maybePop();
  }

  Future<void> _openServiceSwitcher(Service service) async {
    final LanDeckRepository repository = AppScope.of(context);
    final ServiceSelection? selection = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: service,
      currentMode: ServiceMode.web,
      deviceNameFor: repository.deviceNameFor,
      openServiceIds: const <String>{},
    );
    if (!mounted || selection == null || selection.service.id == service.id) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            LinuxWebViewPage(serviceId: selection.service.id),
      ),
    );
  }

  String _statusLabel(Service service) {
    if (_hasError) {
      return '加载失败';
    }
    if (_loading) {
      return _progress > 0 ? '加载中 $_progress%' : '正在打开网页';
    }
    return _title == null || _title!.isEmpty ? service.address : _title!;
  }

  Future<void> _showMore(Service service) async {
    final LanDeckRepository repository = AppScope.of(context);
    final String deviceName = repository.deviceNameFor(service);
    final MoreAction? action = await showMoreActionsSheet(
      context,
      service: service,
      deviceName: deviceName,
      immersive: false,
      nativeWebView: false,
      canGoForward: _canGoForward,
      currentUrl: _currentUrl,
      includeImmersive: false,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MoreAction.refresh:
        await _reload();
      case MoreAction.goForward:
        await _forward();
      case MoreAction.openExternal:
        await _openExternal();
      case MoreAction.copyAddress:
        await _copyAddress();
      case MoreAction.fillPassword:
        await _fillLogin(service);
      case MoreAction.savePassword:
        await _saveLogin(service);
      case MoreAction.shareAddress:
        showAppSnackBar(context, '分享地址暂未在 Linux 版开放');
      case MoreAction.downloads:
        showAppSnackBar(context, '下载保存由 WebKitGTK 处理');
      case MoreAction.toggleImmersive:
        break;
      case MoreAction.pageInfo:
        await showPageInfoSheet(
          context,
          service: service,
          deviceName: deviceName,
          currentUrl: _currentUrl,
        );
    }
  }

  Future<void> _openExternal() async {
    final String? url = _currentUrl;
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      if (mounted) {
        showAppSnackBar(context, '无法打开系统浏览器');
      }
    }
  }

  Future<void> _copyAddress() async {
    final String? url = _currentUrl;
    if (url == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      showAppSnackBar(context, '已复制地址');
    }
  }

  Future<void> _autoFillSavedLogin(String url) async {
    final WebViewController? controller = _controller;
    final Service? current = _service;
    if (!mounted || controller == null || current == null) {
      return;
    }
    final Service service =
        AppScope.of(context).serviceById(current.id) ?? current;
    if (service.passwordFillMode != PasswordFillMode.auto) {
      return;
    }
    final Uri? pageUri = Uri.tryParse(url);
    final Uri? serviceUri = Uri.tryParse(service.url);
    if (pageUri == null || serviceUri == null) {
      return;
    }
    if (pageUri.host.toLowerCase() != serviceUri.host.toLowerCase()) {
      return;
    }
    final String? scope = WebPasswordFill.scopeHostOf(pageUri);
    if (scope == null) {
      return;
    }
    try {
      final List<HttpCredential> accounts = await HttpCredentialStore.instance
          .accountsFor(service.id, host: scope, realm: WebPasswordFill.webRealm);
      if (accounts.isEmpty || !mounted) {
        return;
      }
      final HttpCredential? saved =
          _preferredAccount(accounts, service.defaultCredentialUsername);
      if (saved == null) {
        return;
      }
      await controller.runJavaScript(
        WebPasswordFill.autoFillScript(
          username: saved.username,
          password: saved.password,
        ),
      );
    } on Object {
      // Auto-fill is opportunistic; never interrupt page loading.
    }
  }

  HttpCredential? _preferredAccount(
    List<HttpCredential> accounts,
    String? preferredUsername,
  ) {
    if (accounts.isEmpty) {
      return null;
    }
    if (preferredUsername != null) {
      for (final HttpCredential account in accounts) {
        if (account.username == preferredUsername) {
          return account;
        }
      }
    }
    return accounts.first;
  }

  Future<void> _promptFillOnFocus(String host) async {
    final Service? current = _service;
    if (!mounted || current == null || _passwordPromptOpen) {
      return;
    }
    final Service service =
        AppScope.of(context).serviceById(current.id) ?? current;
    if (service.passwordFillMode != PasswordFillMode.ask) {
      return;
    }
    if (_pageScope == null || _pageScope != host) {
      return;
    }
    final String pageKey = '${service.id}|${_pageScope!}';
    if (_loginFocusPrompts.contains(pageKey)) {
      return;
    }
    try {
      final List<HttpCredential> accounts = await HttpCredentialStore.instance
          .accountsFor(service.id, host: host, realm: WebPasswordFill.webRealm);
      if (accounts.isEmpty || !mounted) {
        return;
      }
      _loginFocusPrompts.add(pageKey);
      _passwordPromptOpen = true;
      final HttpCredential? chosen = await showCredentialPicker(
        context,
        credentials: accounts,
        defaultUsername: service.defaultCredentialUsername,
      );
      _passwordPromptOpen = false;
      if (!mounted || chosen == null) {
        return;
      }
      final Map<String, Object?>? result = await _runWebJson(
        WebPasswordFill.fillScript(
          username: chosen.username,
          password: chosen.password,
        ),
      );
      if (!mounted) {
        return;
      }
      if (result?['ok'] == true) {
        showAppSnackBar(context, '已填充 ${chosen.username} 的登录信息');
      }
    } on Object {
      _passwordPromptOpen = false;
    }
  }

  Future<void> _fillLogin(Service service) async {
    final Uri? uri = _currentUrl == null ? null : Uri.tryParse(_currentUrl!);
    final String? scope = uri == null ? null : WebPasswordFill.scopeHostOf(uri);
    if (scope == null) {
      return;
    }
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(service.id, host: scope, realm: WebPasswordFill.webRealm);
    if (!mounted) {
      return;
    }
    if (accounts.isEmpty) {
      showAppSnackBar(context, '没有保存的登录信息');
      return;
    }
    final HttpCredential? chosen = await showCredentialPicker(
      context,
      credentials: accounts,
      defaultUsername: service.defaultCredentialUsername,
    );
    if (!mounted || chosen == null) {
      return;
    }
    final Map<String, Object?>? result = await _runWebJson(
      WebPasswordFill.fillScript(
        username: chosen.username,
        password: chosen.password,
      ),
    );
    if (mounted && result?['ok'] == true) {
      showAppSnackBar(context, '已填充 ${chosen.username} 的登录信息');
    }
  }

  Future<void> _saveLogin(Service service) async {
    final Uri? uri = _currentUrl == null ? null : Uri.tryParse(_currentUrl!);
    final String? scope = uri == null ? null : WebPasswordFill.scopeHostOf(uri);
    if (scope == null) {
      return;
    }
    final Map<String, Object?>? captured = await _runWebJson(
      WebPasswordFill.captureScript,
    );
    if (!mounted || captured == null) {
      return;
    }
    final String username = (captured['username'] as String? ?? '').trim();
    final String password = captured['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      showAppSnackBar(context, '页面上没有可保存的登录信息');
      return;
    }
    final bool confirmed = await showSaveWebPasswordDialog(
      context,
      serviceName: service.name,
      host: scope,
      username: username,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await HttpCredentialStore.instance.save(
      HttpCredential(
        serviceId: service.id,
        host: scope,
        realm: WebPasswordFill.webRealm,
        username: username,
        password: password,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) {
      showAppSnackBar(context, '已保存登录信息');
    }
  }

  void _onPasswordBridgeMessage(JavaScriptMessage message) {
    try {
      final Object? decoded = jsonDecode(message.message);
      if (decoded is! Map) {
        return;
      }
      final String? type = decoded['type'] as String?;
      if (type == 'login-focus') {
        final String host = (decoded['host'] as String? ?? '').trim();
        if (host.isNotEmpty) {
          unawaited(_promptFillOnFocus(host));
        }
        return;
      }
      if (type != 'credentials') {
        return;
      }
      final String username = (decoded['username'] as String? ?? '').trim();
      final String password = decoded['password'] as String? ?? '';
      final String host = (decoded['host'] as String? ?? '').trim();
      final Service? service = _service;
      if (username.isEmpty ||
          password.isEmpty ||
          host.isEmpty ||
          service == null) {
        return;
      }
      final Uri? serviceUri = Uri.tryParse(service.url);
      final String? pageScope = _pageScope;
      if (serviceUri == null ||
          pageScope == null ||
          host.toLowerCase() != pageScope ||
          serviceUri.host.toLowerCase() !=
              Uri.tryParse('http://$host')?.host.toLowerCase()) {
        return;
      }
      unawaited(_promptSaveLoginFromPage(pageScope, username, password));
    } on Object {
      // Ignore malformed messages from page scripts.
    }
  }

  Future<void> _promptSaveLoginFromPage(
    String host,
    String username,
    String password,
  ) async {
    final Service? service = _service;
    if (!mounted || service == null || _passwordPromptOpen) {
      return;
    }
    final List<HttpCredential> savedAccounts = await HttpCredentialStore
        .instance
        .accountsFor(service.id, host: host, realm: WebPasswordFill.webRealm);
    if (!mounted) {
      return;
    }
    for (final HttpCredential account in savedAccounts) {
      if (account.username == username && account.password == password) {
        return;
      }
    }
    _passwordPromptOpen = true;
    final bool confirmed = await showSaveWebPasswordDialog(
      context,
      serviceName: service.name,
      host: host,
      username: username,
    );
    _passwordPromptOpen = false;
    if (!mounted || !confirmed) {
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
  }

  Future<void> _onHttpAuthRequest(HttpAuthRequest request) async {
    final Service? service = _service;
    if (service == null) {
      request.onCancel();
      return;
    }
    final Uri? serviceUri = Uri.tryParse(service.url);
    final String requestHost = _normalizeHost(request.host);
    final String serviceHost = _normalizeHost(serviceUri?.host ?? '');
    if (serviceHost.isEmpty || requestHost != serviceHost) {
      request.onCancel();
      if (mounted && _blockedHosts.add(requestHost)) {
        showAppSnackBar(context, '已阻止来自 $requestHost 的认证请求');
      }
      return;
    }
    final String realm = request.realm ?? '';
    final String scope = '$requestHost|$realm';
    if (_cancelledScopes.contains(scope)) {
      request.onCancel();
      return;
    }
    if (_authDialogOpen) {
      request.onCancel();
      return;
    }
    HttpCredential? credential = _sessionCredentials[scope];
    credential ??= await HttpCredentialStore.instance.find(
      service.id,
      host: requestHost,
      realm: realm,
      preferUsername: service.defaultCredentialUsername,
    );
    if (!mounted) {
      request.onCancel();
      return;
    }
    if (credential != null && !_autoTriedScopes.contains(scope)) {
      _autoTriedScopes.add(scope);
      _sessionCredentials[scope] = credential;
      _authAttempts = 1;
      request.onProceed(
        WebViewCredential(
          user: credential.username,
          password: credential.password,
        ),
      );
      return;
    }
    if (_autoTriedScopes.contains(scope) && credential != null) {
      try {
        await HttpCredentialStore.instance.deleteCredential(
          service.id,
          host: requestHost,
          realm: realm,
          username: credential.username,
        );
      } on Object {
        // Best effort.
      }
    }
    if (!mounted) {
      request.onCancel();
      return;
    }
    _authDialogOpen = true;
    final HttpAuthResult? result = await showHttpAuthDialog(
      context,
      serviceName: service.name,
      address: service.address,
      host: requestHost,
      realm: realm,
      initialUsername: credential?.username,
      errorText: _authAttempts > 0 ? '认证失败，请检查用户名和密码' : null,
    );
    _authDialogOpen = false;
    if (!mounted) {
      request.onCancel();
      return;
    }
    if (result == null) {
      _cancelledScopes.add(scope);
      request.onCancel();
      return;
    }
    _authAttempts++;
    final HttpCredential fresh = HttpCredential(
      serviceId: service.id,
      host: requestHost,
      realm: realm,
      username: result.username,
      password: result.password,
      updatedAt: DateTime.now(),
    );
    _sessionCredentials[scope] = fresh;
    _autoTriedScopes.add(scope);
    if (result.remember) {
      await HttpCredentialStore.instance.save(fresh);
    }
    request.onProceed(
      WebViewCredential(user: fresh.username, password: fresh.password),
    );
  }

  static String _normalizeHost(String host) {
    final String value = host.trim().toLowerCase();
    if (value.startsWith('[') && value.endsWith(']')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  Future<Map<String, Object?>?> _runWebJson(String script) async {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return null;
    }
    try {
      final Object raw = await controller.runJavaScriptReturningResult(script);
      final Object? decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        return decoded.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        );
      }
    } on Object {
      // Page context may reject the script.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Service? service = _service;
    if (service == null) {
      return Scaffold(
        appBar: webViewerAppBar(
          surface: scheme.surfaceContainer,
          leading: WebViewBarAction(
            icon: Icons.close_rounded,
            tooltip: '退出',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('服务'),
          actions: const <Widget>[],
        ),
        body: const Center(child: Text('服务不存在或已被删除')),
      );
    }
    return Scaffold(
      appBar: webViewerAppBar(
        surface: scheme.surfaceContainer,
        leading: WebViewBarAction(
          icon: Icons.close_rounded,
          tooltip: '退出',
          onPressed: _exit,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              service.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
              ),
            ),
            Text(
              _statusLabel(service),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          WebViewBarAction(
            icon: Icons.undo_rounded,
            tooltip: '后退',
            onPressed: _canGoBack ? _back : null,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.redo_rounded,
            tooltip: '前进',
            onPressed: _canGoForward ? _forward : null,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.more_horiz_rounded,
            tooltip: '更多',
            onPressed: () => _showMore(service),
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.swap_horiz_rounded,
            tooltip: '切换服务',
            onPressed: () => _openServiceSwitcher(service),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _hasError
          ? WebErrorView(
              service: service,
              onRetry: _reload,
              onSwitchService: () => _openServiceSwitcher(service),
              detail: _error,
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: WebViewWidget(controller: _controller!),
                    ),
                    if (_loading && _progress > 0)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: _progress / 100,
                        ),
                      ),
                  ],
                ),
    );
  }
}
