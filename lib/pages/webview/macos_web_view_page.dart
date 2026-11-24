import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import '../../services/web_password_fill.dart';
import 'widgets/http_auth_dialog.dart';
import 'widgets/more_actions_sheet.dart';
import 'widgets/service_switcher_sheet.dart';
import 'widgets/web_error_view.dart';
import 'widgets/web_password_dialogs.dart';
import 'widgets/webview_bar_action.dart';

/// Web viewer for macOS.
///
/// `webview_flutter` has no macOS implementation, so this page uses
/// `flutter_inappwebview` (WKWebView) with the same top bar, auth dialog and
/// password-fill bridge as the mobile viewer.
class MacosWebViewPage extends StatefulWidget {
  const MacosWebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<MacosWebViewPage> createState() => _MacosWebViewPageState();
}

class _MacosWebViewPageState extends State<MacosWebViewPage> {
  InAppWebViewController? _controller;
  Service? _service;

  bool _loading = true;
  double _progress = 0;
  bool _hasError = false;
  String? _error;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _currentUrl;

  bool _authPromptOpen = false;
  final Set<String> _basicAuthAttemptedHosts = <String>{};
  final Set<String> _loginFocusPrompts = <String>{};
  bool _fillPromptOpen = false;
  bool _savePromptOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LanDeckRepository repository = AppScope.of(context);
    final Service? current = repository.serviceById(widget.serviceId);
    if (current != null) {
      _service = current;
    }
  }

  String get _bridgeShim =>
      'window.LandeckPasswordBridge = { postMessage: function (m) { '
      'window.flutter_inappwebview.callHandler("LandeckPasswordBridge", m); } };';

  @override
  Widget build(BuildContext context) {
    final Service? service = _service;
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('服务')),
        body: const Center(child: Text('服务不存在或已被删除')),
      );
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: webViewerAppBar(
        surface: scheme.surfaceContainer,
        leading: WebViewBarAction(
          icon: Icons.arrow_back_rounded,
          tooltip: '退出',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              service.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              service.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          WebViewBarAction(
            icon: Icons.undo_rounded,
            tooltip: '后退',
            onPressed: _canGoBack ? _goBack : null,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.redo_rounded,
            tooltip: '前进',
            onPressed: _canGoForward ? _goForward : null,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.more_horiz_rounded,
            tooltip: '更多',
            onPressed: _controller == null ? null : _showMore,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.swap_horiz_rounded,
            tooltip: '切换服务',
            onPressed: _openServiceSwitcher,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(service.url)),
            initialUserScripts: UnmodifiableListView<UserScript>(
              <UserScript>[
                UserScript(
                  source: '$_bridgeShim\n${WebPasswordFill.hookScript}',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ],
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: false,
            ),
            onWebViewCreated: (InAppWebViewController controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'LandeckPasswordBridge',
                callback: (List<dynamic> args) {
                  if (args.isNotEmpty) {
                    _onBridgeMessage(args.first.toString());
                  }
                  return null;
                },
              );
            },
            onLoadStart: (
              InAppWebViewController controller,
              WebUri? url,
            ) {
              setState(() {
                _loading = true;
                _hasError = false;
                _error = null;
                _loginFocusPrompts.clear();
              });
            },
            onLoadStop: (
              InAppWebViewController controller,
              WebUri? url,
            ) async {
              setState(() {
                _loading = false;
                _currentUrl = url?.toString();
              });
              await _syncHistory(controller);
              await _autoFillSavedLogin(controller);
            },
            onProgressChanged: (
              InAppWebViewController controller,
              int progress,
            ) {
              setState(() => _progress = progress / 100);
            },
            onReceivedError: (
              InAppWebViewController controller,
              WebResourceRequest request,
              WebResourceError error,
            ) {
              if (request.isForMainFrame != true) {
                return;
              }
              setState(() {
                _loading = false;
                _hasError = true;
                _error = error.description;
              });
            },
            onUpdateVisitedHistory: (
              InAppWebViewController controller,
              WebUri? url,
              bool? isReload,
            ) async {
              setState(() => _currentUrl = url?.toString());
              await _syncHistory(controller);
            },
            onReceivedHttpAuthRequest: (
              InAppWebViewController controller,
              URLAuthenticationChallenge challenge,
            ) async {
              if (challenge is! HttpAuthenticationChallenge) {
                return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
              }
              return _onBasicAuthChallenge(challenge);
            },
          ),
          if (_loading && _progress > 0 && _progress < 1)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(value: _progress, minHeight: 2),
            ),
          if (_hasError)
            Positioned.fill(
              child: WebErrorView(
                service: service,
                detail: _error,
                nativeWebView: true,
                onRetry: _retry,
                onSwitchService: _openServiceSwitcher,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _syncHistory(InAppWebViewController controller) async {
    final bool back = await controller.canGoBack();
    final bool forward = await controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _goBack() async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  Future<void> _goForward() async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (await controller.canGoForward()) {
      await controller.goForward();
    }
  }

  Future<void> _retry() async {
    final InAppWebViewController? controller = _controller;
    final Service? service = _service;
    if (controller == null || service == null) {
      return;
    }
    setState(() {
      _hasError = false;
      _loading = true;
    });
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(service.url)));
  }

  // ---------------------------------------------------------------------------
  // Password fill
  // ---------------------------------------------------------------------------

  void _onBridgeMessage(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) {
      return;
    }
    final Map<String, dynamic> data = decoded.map(
      (dynamic key, dynamic value) => MapEntry<String, dynamic>(
        key.toString(),
        value,
      ),
    );
    switch (data['type']?.toString()) {
      case 'login-focus':
        final String host = data['host']?.toString() ?? '';
        unawaited(_promptFillOnFocus(host));
        break;
      case 'credentials':
        final String host = data['host']?.toString() ?? '';
        final String username = data['username']?.toString() ?? '';
        final String password = data['password']?.toString() ?? '';
        if (username.isNotEmpty && password.isNotEmpty) {
          unawaited(_promptSaveLogin(host, username, password));
        }
        break;
    }
  }

  Future<void> _autoFillSavedLogin(InAppWebViewController controller) async {
    final Service? service = _service;
    if (service == null || service.passwordFillMode == PasswordFillMode.off) {
      return;
    }
    final String? url = _currentUrl;
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(
          service.id,
          host: WebPasswordFill.scopeHostOf(uri) ?? service.address,
          realm: WebPasswordFill.webRealm,
        );
    if (accounts.isEmpty) {
      return;
    }
    if (service.passwordFillMode == PasswordFillMode.ask) {
      return;
    }
    final HttpCredential account = _preferredAccount(
      accounts,
      service.defaultCredentialUsername,
    );
    await controller.evaluateJavascript(
      source: WebPasswordFill.autoFillScript(
        username: account.username,
        password: account.password,
      ),
    );
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
      await _controller?.evaluateJavascript(
        source: WebPasswordFill.fillScript(
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

  Future<HttpAuthResponse> _onBasicAuthChallenge(
    HttpAuthenticationChallenge challenge,
  ) async {
    final Service? service = _service;
    if (service == null) {
      return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
    }
    if (_authPromptOpen) {
      return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
    }
    final String host = challenge.protectionSpace.host;
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(service.id, host: host, realm: '');
    final HttpCredential saved = _preferredAccount(
      accounts,
      service.defaultCredentialUsername,
    );
    if (service.passwordFillMode == PasswordFillMode.auto &&
        !_basicAuthAttemptedHosts.contains(host)) {
      _basicAuthAttemptedHosts.add(host);
      return HttpAuthResponse(
        action: HttpAuthResponseAction.PROCEED,
        username: saved.username,
        password: saved.password,
        permanentPersistence: true,
      );
    }
    if (!mounted) {
      return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
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
        return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
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
        return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
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
      return HttpAuthResponse(
        action: HttpAuthResponseAction.PROCEED,
        username: result.username,
        password: result.password,
        permanentPersistence: result.remember,
      );
    } finally {
      _authPromptOpen = false;
    }
  }

  HttpCredential _preferredAccount(
    List<HttpCredential> accounts,
    String? defaultUsername,
  ) {
    if (defaultUsername == null || defaultUsername.isEmpty) {
      return accounts.first;
    }
    for (final HttpCredential account in accounts) {
      if (account.username == defaultUsername) {
        return account;
      }
    }
    return accounts.first;
  }

  // ---------------------------------------------------------------------------
  // Top bar actions
  // ---------------------------------------------------------------------------

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

  Future<void> _openExternally() async {
    final String? url = _currentUrl ?? _service?.url;
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
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

  Future<void> _fillLogin() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final String? url = _currentUrl;
    final Uri? uri = url == null ? null : Uri.tryParse(url);
    final List<HttpCredential> accounts = await HttpCredentialStore.instance
        .accountsFor(
          service.id,
          host: uri == null
              ? service.address
              : (WebPasswordFill.scopeHostOf(uri) ?? service.address),
          realm: WebPasswordFill.webRealm,
        );
    if (accounts.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, '没有保存的网页登录信息');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final HttpCredential? account = await showCredentialPicker(
      context,
      credentials: accounts,
      defaultUsername: service.defaultCredentialUsername,
    );
    if (account == null) {
      return;
    }
    await _controller?.evaluateJavascript(
      source: WebPasswordFill.fillScript(
        username: account.username,
        password: account.password,
      ),
    );
    if (mounted) {
      showAppSnackBar(context, '已填充账号 ${account.username}');
    }
  }

  Future<void> _saveLogin() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final dynamic captured = await _controller?.evaluateJavascript(
      source: WebPasswordFill.captureScript,
    );
    final Map<String, dynamic>? data = WebPasswordFill.decodeResult(captured);
    if (data == null) {
      if (mounted) {
        showAppSnackBar(context, '页面上没有可保存的登录信息');
      }
      return;
    }
    final String username = data['username']?.toString() ?? '';
    final String password = data['password']?.toString() ?? '';
    final String host = data['host']?.toString() ?? '';
    final String? pageHost = _currentUrl == null
        ? null
        : WebPasswordFill.scopeHostOf(Uri.tryParse(_currentUrl!) ?? Uri());
    if (username.isEmpty || password.isEmpty || host.isEmpty) {
      return;
    }
    if (pageHost != null && pageHost != host) {
      return;
    }
    await _promptSaveLogin(host, username, password);
  }

  Future<void> _showMore() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final MoreAction? action = await showMoreActionsSheet(
      context,
      service: service,
      deviceName: service.address,
      immersive: false,
      nativeWebView: true,
      canGoForward: _canGoForward,
      currentUrl: _currentUrl,
      includeImmersive: false,
    );
    switch (action) {
      case MoreAction.refresh:
        await _controller?.reload();
        break;
      case MoreAction.goForward:
        await _goForward();
        break;
      case MoreAction.openExternal:
        await _openExternally();
        break;
      case MoreAction.copyAddress:
        await _copyAddress();
        break;
      case MoreAction.fillPassword:
        await _fillLogin();
        break;
      case MoreAction.savePassword:
        await _saveLogin();
        break;
      case MoreAction.shareAddress:
        if (mounted) {
          showAppSnackBar(context, 'macOS 上暂不支持分享地址');
        }
        break;
      case MoreAction.downloads:
        if (mounted) {
          showAppSnackBar(context, 'macOS 下载暂未开放');
        }
        break;
      case MoreAction.toggleImmersive:
        break;
      case MoreAction.pageInfo:
        await _showPageInfo();
        break;
      case null:
        break;
    }
  }

  Future<void> _showPageInfo() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final String? url = _currentUrl;
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '页面信息',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '服务：${service.name}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                '地址：${url ?? service.url}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openServiceSwitcher() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final LanDeckRepository repository = AppScope.of(context);
    final ServiceSelection? selection = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: service,
      currentMode: service.defaultMode,
      deviceNameFor: repository.deviceNameFor,
      openServiceIds: <String>{service.id},
    );
    if (selection == null || !mounted) {
      return;
    }
    if (selection.service.id == service.id) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            MacosWebViewPage(serviceId: selection.service.id),
      ),
    );
  }
}
