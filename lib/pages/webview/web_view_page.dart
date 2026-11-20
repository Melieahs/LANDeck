import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/feedback.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import 'widgets/http_auth_dialog.dart';
import 'widgets/more_actions_sheet.dart';
import 'widgets/service_switcher_sheet.dart';
import 'widgets/web_error_view.dart';
import 'widgets/web_view_toolbar.dart';

/// Immersive viewer for a user-added service URL.
///
/// Android/iOS use the platform WebView. On Flutter Web and in widget tests,
/// where no system WebView is available, the page says so explicitly instead
/// of rendering demo content.
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  LanDeckRepository? _repository;
  Service? _service;
  bool _initialized = false;

  late final bool _nativeWebView;
  WebViewController? _controller;
  int _webViewGeneration = 0;

  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _hasError = false;
  String? _error;
  double _progress = 0;
  bool _loading = false;
  Timer? _loadTimeout;
  DateTime? _lastHealthWrite;

  bool _toolbarVisible = false;
  Timer? _autoHideTimer;

  // HTTP authentication state. Credentials are kept in memory for this
  // WebView session unless the user explicitly chooses to remember them.
  final Map<String, HttpCredential> _sessionCredentials =
      <String, HttpCredential>{};
  final Set<String> _autoTriedScopes = <String>{};
  final Set<String> _cancelledScopes = <String>{};
  final Set<String> _blockedHosts = <String>{};
  bool _authDialogOpen = false;
  int _authAttempts = 0;
  bool _immersive = false;

  @override
  void initState() {
    super.initState();
    _nativeWebView = !kIsWeb && WebViewPlatform.instance != null;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LanDeckRepository repository = AppScope.of(context);
    _repository = repository;
    final Service? latest = repository.serviceById(widget.serviceId);
    if (!_initialized) {
      _initialized = true;
      _service = latest;
      if (latest != null && _nativeWebView) {
        _controller = _createController();
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadUrl());
      }
      return;
    }
    if (latest != null) {
      _service = latest;
    }
    if (MediaQuery.viewInsetsOf(context).bottom > 0 && _toolbarVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _toolbarVisible) {
          _collapseToolbar();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _loadTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_immersive && !kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  WebViewController _createController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Theme.of(context).colorScheme.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: _onProgress,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onWebResourceError: _onResourceError,
          onNavigationRequest: _onNavigationRequest,
          onHttpAuthRequest: _onHttpAuthRequest,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Load lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _loadUrl() async {
    final WebViewController? controller = _controller;
    final Service? service = _service;
    if (!mounted || controller == null || service == null) {
      return;
    }
    _resetAuthState();
    setState(() {
      _loading = true;
      _progress = 0.03;
      _hasError = false;
      _error = null;
    });
    _armTimeout();
    try {
      await controller.loadRequest(Uri.parse(service.url));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _clearTimeout();
      setState(() {
        _loading = false;
        _hasError = true;
        _error = error.toString();
      });
      _markHealth(ServiceStatus.offline);
    }
  }

  void _armTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_loading || _hasError) {
        return;
      }
      setState(() {
        _loading = false;
        _hasError = true;
        _error = '连接超时，请检查设备是否在线';
      });
      _markHealth(ServiceStatus.offline);
    });
  }

  void _clearTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = null;
  }

  void _onPageStarted(String url) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _progress = 0.03;
      _hasError = false;
      _error = null;
    });
    _armTimeout();
  }

  void _onProgress(int progress) {
    if (!mounted) {
      return;
    }
    final double value = progress.clamp(0, 100) / 100;
    setState(() {
      _progress = value;
      _loading = value < 1;
    });
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted) {
      return;
    }
    _clearTimeout();
    setState(() {
      _loading = false;
      _hasError = false;
      _error = null;
    });
    _authAttempts = 0;
    _markHealth(ServiceStatus.online);
    await _syncNavigationState();
  }

  void _onResourceError(WebResourceError error) {
    if (!mounted || error.isForMainFrame == false) {
      return;
    }
    _clearTimeout();
    setState(() {
      _loading = false;
      _hasError = true;
      _error = error.description;
    });
    _markHealth(ServiceStatus.offline);
  }

  /// HTTP(S) pages stay inside the WebView; custom schemes go to the OS.
  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final Uri? uri = Uri.tryParse(request.url);
    if (uri == null) {
      return NavigationDecision.prevent;
    }
    const Set<String> webSchemes = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
      'file',
      'javascript',
    };
    if (webSchemes.contains(uri.scheme)) {
      return NavigationDecision.navigate;
    }
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showAppSnackBar(context, '无法打开外部应用');
    }
    return NavigationDecision.prevent;
  }

  // ---------------------------------------------------------------------------
  // HTTP authentication
  // ---------------------------------------------------------------------------

  static String _normalizeHost(String host) =>
      host.toLowerCase().replaceAll(RegExp(r'\.$'), '');

  void _resetAuthState() {
    _autoTriedScopes.clear();
    _cancelledScopes.clear();
    _blockedHosts.clear();
    _authAttempts = 0;
  }

  String _addressFor(Service service) {
    final Uri? uri = Uri.tryParse(service.url);
    if (uri == null || uri.host.isEmpty) {
      return service.address;
    }
    final int port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' ? 443 : 80);
    return '${uri.host}:$port';
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
      // Multiple subresources can challenge at once. One dialog is enough;
      // cancel duplicates instead of stacking prompts or looping.
      request.onCancel();
      return;
    }

    HttpCredential? credential = _sessionCredentials[scope];
    credential ??= await HttpCredentialStore.instance.find(
      service.id,
      host: requestHost,
      realm: realm,
    );
    if (!mounted) {
      request.onCancel();
      return;
    }

    if (credential != null && !_autoTriedScopes.contains(scope)) {
      _autoTriedScopes.add(scope);
      _sessionCredentials[scope] = credential;
      // A stored credential is tried once per page load. If it is wrong the
      // next challenge opens the dialog instead of retrying forever.
      _authAttempts = 1;
      request.onProceed(
        WebViewCredential(
          user: credential.username,
          password: credential.password,
        ),
      );
      return;
    }

    if (_autoTriedScopes.contains(scope)) {
      // The automatically tried credential was rejected. Remove it so a bad
      // password is not kept and retried on every future page load.
      try {
        await HttpCredentialStore.instance.deleteScope(
          service.id,
          host: requestHost,
          realm: realm,
        );
      } on Object {
        // Secure-storage cleanup is best effort; the dialog still opens.
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
      address: _addressFor(service),
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
      // Do not re-prompt automatically after an explicit cancel. The page
      // keeps its 401 response; a refresh starts a new attempt.
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
      try {
        await HttpCredentialStore.instance.save(fresh);
      } on Object {
        if (mounted) {
          showAppSnackBar(context, '凭据无法安全保存，本次仅用于当前会话');
        }
      }
    }
    if (!mounted) {
      request.onCancel();
      return;
    }
    request.onProceed(
      WebViewCredential(user: fresh.username, password: fresh.password),
    );
  }

  Future<void> _syncNavigationState() async {
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
    } on PlatformException {
      // The controller can detach while a page is closing.
    }
  }

  /// Persists the actual reachability of the page, throttled so SPA navigation
  /// does not write on every history event.
  void _markHealth(ServiceStatus status) {
    final LanDeckRepository? repository = _repository;
    final Service? service = _service;
    if (repository == null || service == null) {
      return;
    }
    final DateTime now = DateTime.now();
    if (_lastHealthWrite != null &&
        now.difference(_lastHealthWrite!) < const Duration(seconds: 15)) {
      return;
    }
    _lastHealthWrite = now;
    unawaited(repository.recordHealth(service.id, status));
  }

  // ---------------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------------

  void _toggleToolbar() {
    if (_toolbarVisible) {
      _collapseToolbar();
      return;
    }
    setState(() => _toolbarVisible = true);
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (!_toolbarVisible) {
      return;
    }
    _autoHideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        _collapseToolbar();
      }
    });
  }

  void _collapseToolbar() {
    _autoHideTimer?.cancel();
    if (_toolbarVisible) {
      setState(() => _toolbarVisible = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation / actions
  // ---------------------------------------------------------------------------

  Future<void> _goBack() async {
    final WebViewController? controller = _controller;
    if (controller != null && _canGoBack) {
      await controller.goBack();
      await _syncNavigationState();
    }
  }

  Future<void> _goForward() async {
    final WebViewController? controller = _controller;
    if (controller != null && _canGoForward) {
      await controller.goForward();
      await _syncNavigationState();
    }
  }

  void _handleSystemBack() {
    if (View.of(context).viewInsets.bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_toolbarVisible) {
      _collapseToolbar();
      return;
    }
    if (_nativeWebView && _canGoBack) {
      _goBack();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _handleToolbarBack() async {
    _scheduleAutoHide();
    if (_nativeWebView && _canGoBack) {
      await _goBack();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _handleRefresh() async {
    _scheduleAutoHide();
    if (!_nativeWebView) {
      showAppSnackBar(context, '当前平台没有可用的系统 WebView');
      return;
    }
    await _loadUrl();
  }

  Future<void> _retry() async {
    await _loadUrl();
  }

  Future<void> _openServiceSwitcher() async {
    final LanDeckRepository? repository = _repository;
    final Service? current = _service;
    if (repository == null || current == null) {
      return;
    }
    _collapseToolbar();
    final Service? picked = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: current,
      deviceNameFor: repository.deviceNameFor,
    );
    if (!mounted || picked == null || picked.id == current.id) {
      return;
    }
    _resetAuthState();
    setState(() {
      _service = picked;
      _hasError = false;
      _error = null;
      _progress = 0.03;
      _loading = _nativeWebView;
      _canGoBack = false;
      _canGoForward = false;
      _webViewGeneration++;
    });
    if (_nativeWebView) {
      _clearTimeout();
      _controller = _createController();
      await _loadUrl();
    }
  }

  Future<String> _currentUrl() async {
    final Service? service = _service;
    final WebViewController? controller = _controller;
    if (!_nativeWebView || controller == null) {
      return service?.url ?? '';
    }
    try {
      return await controller.currentUrl() ?? service?.url ?? '';
    } on PlatformException {
      return service?.url ?? '';
    }
  }

  Future<void> _openMore() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    _collapseToolbar();
    final String currentUrl = await _currentUrl();
    if (!mounted) {
      return;
    }
    final MoreAction? action = await showMoreActionsSheet(
      context,
      service: service,
      deviceName: _repository?.deviceNameFor(service) ?? '未分配设备',
      immersive: _immersive,
      nativeWebView: _nativeWebView,
      currentUrl: currentUrl,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MoreAction.openExternal:
        final Uri? uri = Uri.tryParse(currentUrl);
        bool opened = false;
        if (uri != null) {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted && !opened) {
          showAppSnackBar(context, '无法打开系统浏览器');
        }
        return;
      case MoreAction.copyAddress:
        await Clipboard.setData(ClipboardData(text: currentUrl));
        if (mounted) {
          showAppSnackBar(context, '地址已复制到剪贴板');
        }
        return;
      case MoreAction.shareAddress:
        showAppSnackBar(context, '系统分享将在后续版本开放');
        return;
      case MoreAction.toggleImmersive:
        _setImmersive(!_immersive);
        return;
      case MoreAction.pageInfo:
        await showPageInfoSheet(
          context,
          service: service,
          deviceName: _repository?.deviceNameFor(service) ?? '未分配设备',
          currentUrl: currentUrl,
          nativeWebView: _nativeWebView,
        );
        return;
    }
  }

  void _setImmersive(bool value) {
    setState(() => _immersive = value);
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(
        value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
    showAppSnackBar(context, value ? '已进入沉浸模式' : '已恢复普通模式');
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _buildSurface() {
    final Service? service = _service;
    if (service == null) {
      return _MissingServiceView(onBack: () => Navigator.of(context).pop());
    }
    if (!_nativeWebView || _controller == null) {
      return _UnsupportedWebView(
        service: service,
        onOpenExternal: _openExternally,
        onSwitchService: _openServiceSwitcher,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        WebViewWidget(
          key: ValueKey<String>(
            'native-webview-${service.id}-$_webViewGeneration',
          ),
          controller: _controller!,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final Service? service = _service;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) {
            return;
          }
          _handleSystemBack();
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            top: !_immersive,
            bottom: false,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      if (_toolbarVisible &&
                          notification is ScrollStartNotification) {
                        _collapseToolbar();
                      }
                      return false;
                    },
                    child: _buildSurface(),
                  ),
                ),
                if (_loading && service != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progress.clamp(0.02, 1.0),
                        child: const _ProgressPaint(),
                      ),
                    ),
                  ),
                if (service != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedSize(
                            duration: const Duration(milliseconds: 170),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.bottomCenter,
                            child: _toolbarVisible
                                ? WebViewToolbar(
                                    key: const Key('webview-toolbar'),
                                    onBack: _handleToolbarBack,
                                    onForward: _goForward,
                                    onRefresh: _handleRefresh,
                                    onSwitchService: _openServiceSwitcher,
                                    onMore: _openMore,
                                    canGoForward:
                                        _nativeWebView && _canGoForward,
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                          if (_toolbarVisible) const SizedBox(height: 8),
                          WebViewHandle(
                            key: const Key('webview-handle'),
                            expanded: _toolbarVisible,
                            onTap: _toggleToolbar,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPaint extends StatelessWidget {
  const _ProgressPaint();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.55),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _MissingServiceView extends StatelessWidget {
  const _MissingServiceView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.link_off_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                '服务不存在或已被删除',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '它可能已在服务列表中被移除。',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onBack, child: const Text('返回')),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsupportedWebView extends StatelessWidget {
  const _UnsupportedWebView({
    required this.service,
    required this.onOpenExternal,
    required this.onSwitchService,
  });

  final Service service;
  final VoidCallback onOpenExternal;
  final VoidCallback onSwitchService;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.language_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '未启用 WebView',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.phone_android_rounded,
                            size: 26,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          '当前平台没有系统 WebView',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Android APK 会使用系统 WebView 打开下面的真实地址。'
                          '这里的网页预览不会渲染模拟内容。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.6,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            service.url,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: onOpenExternal,
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                ),
                                label: const Text('外部浏览器'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onSwitchService,
                                child: const Text('切换服务'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
