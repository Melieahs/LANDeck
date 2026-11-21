import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/download_task.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/download_center.dart';
import '../../services/download_probe.dart';
import '../../services/download_request_headers.dart';
import '../../services/download_utils.dart';
import '../../services/http_credential_store.dart';
import '../../services/web_password_fill.dart';
import 'widgets/download_confirm_dialog.dart';
import 'widgets/http_auth_dialog.dart';
import 'widgets/more_actions_sheet.dart';
import 'widgets/service_switcher_sheet.dart';
import 'widgets/web_password_dialogs.dart';
import 'widgets/web_error_view.dart';
import 'widgets/web_view_toolbar.dart';
import '../downloads/downloads_page.dart';

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
  bool _passwordPromptOpen = false;
  int _authAttempts = 0;
  String? _pageScope;
  bool _downloadPromptOpen = false;
  bool _downloadAuthPromptOpen = false;
  final Set<String> _attachmentProbes = <String>{};
  final Set<String> _downloadsInFlight = <String>{};
  final Map<String, DateTime> _recentDownloadPrompts = <String, DateTime>{};
  final Set<String> _handledDownloadUrls = <String>{};
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
        unawaited(_configureFileChooser(_controller!));
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
      )
      ..addJavaScriptChannel(
        'LANDeckDownloads',
        onMessageReceived: _onDownloadBridgeMessage,
      )
      ..addJavaScriptChannel(
        'LandeckPasswordBridge',
        onMessageReceived: _onPasswordBridgeMessage,
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
    _handledDownloadUrls.clear();
    _pageScope = null;
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
    _pageScope = WebPasswordFill.scopeHostOf(Uri.tryParse(url));
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
    await _syncNavigationState();
    await _installDownloadIframeHook();
    await _installPasswordHooks();
    await _autoFillSavedLogin(url);
    _markHealth(ServiceStatus.online);
  }

  /// PS5-like appliances start downloads by assigning a one-shot URL to a
  /// hidden iframe. If the WebView cancels that navigation, the appliance sees
  /// a disconnected client and fails the task. Intercept the assignment before
  /// it reaches the network, then let the native downloader perform the only GET.
  Future<void> _installDownloadIframeHook() async {
    final WebViewController? controller = _controller;
    if (controller == null || !_nativeWebView) {
      return;
    }
    try {
      await controller.runJavaScript(_downloadIframeHook);
    } on Object {
      // Pages without iframe downloads simply keep the normal path.
    }
  }

  void _onDownloadBridgeMessage(JavaScriptMessage message) {
    try {
      final Object? decoded = jsonDecode(message.message);
      if (decoded is! Map) {
        return;
      }
      final String? url = decoded['url'] as String?;
      final String? name = decoded['name'] as String?;
      final Uri? uri = url == null ? null : Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        unawaited(_handleDownload(uri, suggestedName: name));
      }
    } on Object {
      // Ignore malformed messages from page scripts.
    }
  }

  Future<void> _installPasswordHooks() async {
    final WebViewController? controller = _controller;
    if (controller == null || !_nativeWebView) {
      return;
    }
    try {
      await controller.runJavaScript(WebPasswordFill.hookScript);
    } on Object {
      // Pages without a login form simply keep the normal path.
    }
  }

  Future<void> _autoFillSavedLogin(String url) async {
    final WebViewController? controller = _controller;
    final Service? service = _service;
    if (!mounted || controller == null || service == null) {
      return;
    }
    final Uri? pageUri = Uri.tryParse(url);
    final Uri? serviceUri = Uri.tryParse(service.url);
    if (pageUri == null || serviceUri == null) {
      return;
    }
    final String? scope = WebPasswordFill.scopeHostOf(pageUri);
    if (scope == null ||
        pageUri.host.toLowerCase() != serviceUri.host.toLowerCase()) {
      return;
    }
    try {
      final List<HttpCredential> credentials = await HttpCredentialStore
          .instance
          .credentialsFor(service.id);
      HttpCredential? saved;
      for (final HttpCredential credential in credentials) {
        if (credential.realm == WebPasswordFill.webRealm &&
            credential.matches(scope, WebPasswordFill.webRealm)) {
          saved = credential;
          break;
        }
      }
      if (saved == null || !mounted) {
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

  void _onPasswordBridgeMessage(JavaScriptMessage message) {
    try {
      final Object? decoded = jsonDecode(message.message);
      if (decoded is! Map) {
        return;
      }
      if (decoded['type'] != 'credentials') {
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
    final HttpCredential? existing = await HttpCredentialStore.instance.find(
      service.id,
      host: host,
      realm: WebPasswordFill.webRealm,
    );
    if (!mounted) {
      return;
    }
    if (existing != null &&
        existing.username == username &&
        existing.password == password) {
      return;
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
    try {
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已保存登录信息')));
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('登录信息保存失败')));
    }
  }

  static const String _downloadIframeHook = r'''
(function () {
  if (window.__landeckIframeDownloadHook) return;
  window.__landeckIframeDownloadHook = true;
  var downloadPath = /\/api\/download(?:\?|$)/;
  function report(url) {
    try {
      var absolute = new URL(url, location.href);
      if (!downloadPath.test(absolute.pathname + absolute.search)) return false;
      var namePromise = Promise.resolve('');
      try {
        namePromise = fetch('/api/tasks', { credentials: 'include' })
          .then(function (response) { return response.ok ? response.json() : null; })
          .then(function (data) {
            var id = absolute.searchParams.get('id');
            var tasks = (data && data.tasks) || [];
            for (var i = 0; i < tasks.length; i++) {
              var task = tasks[i];
              if (String(task.id || task.task_id) === String(id)) {
                var src = String(task.src || '');
                return src.split('/').filter(Boolean).pop() || '';
              }
            }
            return '';
          })
          .catch(function () { return ''; });
      } catch (e) {}
      namePromise.then(function (name) {
        window.LANDeckDownloads.postMessage(JSON.stringify({ url: absolute.href, name: name }));
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  var descriptor = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'src');
  if (descriptor && descriptor.set && descriptor.get) {
    Object.defineProperty(HTMLIFrameElement.prototype, 'src', {
      configurable: true,
      get: function () { return descriptor.get.call(this); },
      set: function (value) {
        if (typeof value === 'string' && report(value)) {
          descriptor.set.call(this, 'about:blank');
          return;
        }
        descriptor.set.call(this, value);
      }
    });
  }
  var originalSetAttribute = HTMLIFrameElement.prototype.setAttribute;
  HTMLIFrameElement.prototype.setAttribute = function (name, value) {
    if (String(name).toLowerCase() === 'src' && typeof value === 'string' && report(value)) {
      originalSetAttribute.call(this, 'src', 'about:blank');
      return;
    }
    return originalSetAttribute.call(this, name, value);
  };
  function rememberFolderInput(input) {
    if (input && input.tagName === 'INPUT' && input.type === 'file' && input.webkitdirectory) {
      window.__landeckFolderPicker = true;
    }
  }
  document.addEventListener('click', function (event) {
    rememberFolderInput(event.target);
  }, true);
  document.addEventListener('change', function (event) {
    rememberFolderInput(event.target);
  }, true);
  var originalInputClick = HTMLInputElement.prototype.click;
  HTMLInputElement.prototype.click = function () {
    rememberFolderInput(this);
    return originalInputClick.apply(this, arguments);
  };
})();
''';

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
    if (<String>{'http', 'https'}.contains(uri.scheme)) {
      if (looksLikeDownloadUrl(request.url)) {
        unawaited(_handleDownload(uri));
        return NavigationDecision.prevent;
      }
      // Content-Disposition: attachment can be returned by URLs without a
      // file extension. The WebView download listener gives us no metadata,
      // so probe only page-like URLs that may actually be attachments.
      if (request.isMainFrame && shouldProbeForAttachment(request.url)) {
        unawaited(_probeForAttachment(uri));
      }
      return NavigationDecision.navigate;
    }
    const Set<String> webSchemes = <String>{
      'about',
      'data',
      'blob',
      'file',
      'javascript',
    };
    if (webSchemes.contains(uri.scheme)) {
      if (uri.scheme == 'blob' && request.isMainFrame) {
        showAppSnackBar(context, '网页生成的 blob 下载暂不支持，请使用文件直链');
      }
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
  // Downloads
  // ---------------------------------------------------------------------------

  HttpCredential? _sessionCredentialFor(Uri uri) {
    for (final HttpCredential credential in _sessionCredentials.values) {
      if (credential.matches(uri.host, credential.realm)) {
        return credential;
      }
    }
    return null;
  }

  Future<Map<String, String>> _downloadHeaders(Service service, Uri uri) async {
    return DownloadRequestHeaders.build(
      service: service,
      url: uri.toString(),
      sessionCredential: _sessionCredentialFor(uri),
    );
  }

  Future<void> _handleDownload(Uri uri, {String? suggestedName}) async {
    final Service? service = _service;
    final String requestKey = uri.toString();
    if (!mounted ||
        service == null ||
        _downloadPromptOpen ||
        _handledDownloadUrls.contains(requestKey) ||
        _isRecentDownloadPrompt(requestKey) ||
        !_downloadsInFlight.add(requestKey)) {
      return;
    }
    _recentDownloadPrompts[requestKey] = DateTime.now();
    try {
      final ({DownloadProbeResult probe, Map<String, String> headers})? result =
          await _probeDownloadWithAuth(service, uri);
      if (!mounted || result == null) {
        return;
      }
      await _presentDownload(
        service,
        uri,
        result.probe,
        result.headers,
        suggestedName: suggestedName,
      );
    } on Object {
      if (mounted) {
        showAppSnackBar(context, '无法读取下载信息，请重试');
      }
    } finally {
      _downloadsInFlight.remove(requestKey);
    }
  }

  /// Probes a download URL, and if the server demands HTTP Basic auth, asks
  /// for credentials in the app, retries once, and returns the headers that
  /// must be passed to the native downloader. The WebView itself is never
  /// rebuilt and credentials are never placed in the URL.
  Future<({DownloadProbeResult probe, Map<String, String> headers})?>
  _probeDownloadWithAuth(Service service, Uri uri) async {
    Map<String, String> headers = await _downloadHeaders(service, uri);
    DownloadProbeResult probe = await DownloadProbe(headers: headers)
        .probe(uri);
    if (probe.statusCode != 401 ||
        probe.authChallenge == null ||
        _downloadAuthPromptOpen) {
      return (probe: probe, headers: headers);
    }
    if (!probe.authChallenge!.toLowerCase().contains('basic')) {
      if (mounted) {
        showAppSnackBar(context, '该服务使用暂不支持的认证方式，无法下载');
      }
      return null;
    }
    if (!mounted) {
      return null;
    }
    final String host = uri.host;
    final String realm = _realmFromChallenge(probe.authChallenge!);
    final HttpCredential? stale = await HttpCredentialStore.instance.find(
      service.id,
      host: host,
      realm: realm,
    );
    if (stale != null) {
      // The saved credential was already tried by DownloadRequestHeaders and
      // rejected; remove it so a wrong password is not retried forever.
      await HttpCredentialStore.instance.deleteScope(
        service.id,
        host: host,
        realm: realm,
      );
    }
    if (!mounted) {
      return null;
    }
    _downloadAuthPromptOpen = true;
    try {
      final HttpAuthResult? result = await showHttpAuthDialog(
        context,
        serviceName: service.name,
        address: service.address,
        host: host,
        realm: realm.isEmpty ? '受限资源' : realm,
        initialUsername: stale?.username,
        errorText: stale != null ? '认证失败，请检查用户名和密码' : null,
      );
      if (!mounted || result == null) {
        if (mounted) {
          showAppSnackBar(context, '需要登录后才能下载');
        }
        return null;
      }
      final HttpCredential credential = HttpCredential(
        serviceId: service.id,
        host: host,
        realm: realm,
        username: result.username,
        password: result.password,
        updatedAt: DateTime.now(),
      );
      _sessionCredentials[_authScope(host, realm)] = credential;
      if (result.remember) {
        await HttpCredentialStore.instance.save(credential);
      }
      headers = await _downloadHeaders(service, uri);
      probe = await DownloadProbe(headers: headers).probe(uri);
      if (probe.statusCode == 401) {
        if (mounted) {
          showAppSnackBar(context, '认证失败，请检查用户名和密码后重试');
        }
        return null;
      }
      return (probe: probe, headers: headers);
    } finally {
      _downloadAuthPromptOpen = false;
    }
  }

  static String _realmFromChallenge(String challenge) {
    final RegExpMatch? match = RegExp(
      r'realm\s*=\s*"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(challenge);
    return match?.group(1) ?? '';
  }

  /// A page can retry a canceled/blocked download on its own. Suppress the
  /// duplicate confirmation sheet for a few seconds instead of stacking
  /// dialogs that appear impossible to close.
  bool _isRecentDownloadPrompt(String key) {
    final DateTime? last = _recentDownloadPrompts[key];
    if (last == null) {
      return false;
    }
    if (DateTime.now().difference(last) < const Duration(seconds: 8)) {
      return true;
    }
    _recentDownloadPrompts.remove(key);
    return false;
  }

  Future<void> _probeForAttachment(Uri uri) async {
    final String key = uri.toString();
    if (_attachmentProbes.contains(key) ||
        _downloadPromptOpen ||
        _downloadsInFlight.contains(key) ||
        _handledDownloadUrls.contains(key) ||
        _isRecentDownloadPrompt(key)) {
      return;
    }
    _attachmentProbes.add(key);
    _recentDownloadPrompts[key] = DateTime.now();
    try {
      final Service? service = _service;
      if (service == null || !mounted) {
        return;
      }
      final Map<String, String> headers = await _downloadHeaders(service, uri);
      final DownloadProbeResult probe = await DownloadProbe(headers: headers)
          .probe(uri);
      if (!mounted || !probe.attachment) {
        return;
      }
      await _presentDownload(service, uri, probe, headers);
    } on Object {
      // A background probe must never interrupt ordinary navigation.
    } finally {
      _attachmentProbes.remove(key);
    }
  }

  Future<void> _presentDownload(
    Service service,
    Uri uri,
    DownloadProbeResult probe,
    Map<String, String> headers, {
    String? suggestedName,
  }) async {
    if (!mounted || _downloadPromptOpen) {
      return;
    }
    final List<String> hintedParts = suggestedName == null
        ? const <String>[]
        : suggestedName
              .split(RegExp(r'[/\\]'))
              .where((s) => s.isNotEmpty)
              .toList();
    final String? hintedName = hintedParts.isEmpty ? null : hintedParts.last;
    final String fileName = safeFileName(hintedName ?? probe.fileName);
    _downloadPromptOpen = true;
    try {
      final bool confirmed = await showDownloadConfirmDialog(
        context,
        serviceName: service.name,
        data: DownloadConfirmation(
          fileName: fileName,
          url: uri.toString(),
          mimeType: probe.mimeType,
          totalBytes: probe.totalBytes,
          risky: isRiskyFileName(fileName),
          namePending: hintedName == null && !probe.nameKnown,
        ),
      );
      if (!mounted || !confirmed) {
        return;
      }
      final String? destination = await DownloadCenter.instance.fileBridge
          .pickSaveFile(fileName: fileName, mimeType: probe.mimeType);
      if (!mounted) {
        return;
      }
      if (destination == null) {
        showAppSnackBar(context, '已取消，未选择保存位置');
        return;
      }
      await DownloadCenter.instance.requestNotificationPermission();
      if (!mounted) {
        return;
      }
      final DownloadTask? task = await DownloadCenter.instance.enqueue(
        service: service,
        url: uri.toString(),
        fileName: fileName,
        mimeType: probe.mimeType,
        totalBytes: probe.totalBytes,
        destinationUri: destination,
        headers: headers,
      );
      if (!mounted) {
        return;
      }
      if (task != null) {
        // Some pages poll/retry the same download URL after the native task
        // starts. Keep one confirmation per page load; a refresh clears this.
        _handledDownloadUrls.add(uri.toString());
      }
      showAppSnackBar(context, task == null ? '无法开始下载' : '已开始下载：$fileName');
    } finally {
      _downloadPromptOpen = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Uploads (system file picker)
  // ---------------------------------------------------------------------------

  Future<void> _configureFileChooser(WebViewController controller) async {
    if (!_nativeWebView) {
      return;
    }
    try {
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setOnShowFileSelector(_onShowFileSelector);
      }
    } on Object {
      // Older/custom platforms may not expose a file chooser.
    }
  }

  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    if (params.mode == FileSelectorMode.save) {
      final String? destination = await DownloadCenter.instance.fileBridge
          .pickSaveFile(
            fileName: params.filenameHint ?? 'download',
            mimeType: params.acceptTypes.isEmpty
                ? 'application/octet-stream'
                : params.acceptTypes.first,
          );
      return destination == null ? <String>[] : <String>[destination];
    }
    bool wantsFolder = false;
    try {
      final Object? flag = await _controller?.runJavaScriptReturningResult(
        'window.__landeckFolderPicker === true',
      );
      wantsFolder = flag == true || flag.toString() == 'true';
      await _controller?.runJavaScript('window.__landeckFolderPicker = false;');
    } on Object {
      // Pages without the hook fall back to file selection.
    }
    if (wantsFolder) {
      // Canceled folder selection cancels the page's request; do not open a
      // second (file) picker immediately after it.
      return DownloadCenter.instance.fileBridge.pickFolderFiles();
    }
    final List<String> files = await DownloadCenter.instance.fileBridge
        .pickFiles(
          acceptTypes: params.acceptTypes,
          multiple: params.mode == FileSelectorMode.openMultiple,
          capture: params.isCaptureEnabled,
        );
    return files;
  }

  // ---------------------------------------------------------------------------
  // HTTP authentication
  // ---------------------------------------------------------------------------

  static String _normalizeHost(String host) =>
      host.toLowerCase().replaceAll(RegExp(r'\.$'), '');

  static String _authScope(String host, String realm) =>
      '${_normalizeHost(host)}|$realm';

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

  void _exitWebView() {
    // PopScope(canPop: false) blocks maybePop, so exit must pop the route
    // directly. This intentionally ignores page history.
    Navigator.of(context).pop();
  }

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
      unawaited(_configureFileChooser(_controller!));
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

  bool _isServiceHost(String? currentUrl, Service service) {
    final Uri? current = Uri.tryParse(currentUrl ?? '');
    final Uri? serviceUri = Uri.tryParse(service.url);
    if (current == null || serviceUri == null) {
      return false;
    }
    return current.host.toLowerCase() == serviceUri.host.toLowerCase();
  }

  Future<Map<String, Object?>?> _runWebJson(String script) async {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return null;
    }
    try {
      final Object raw = await controller.runJavaScriptReturningResult(script);
      return WebPasswordFill.decodeResult(raw);
    } on Object {
      return null;
    }
  }

  Future<void> _fillLogin(Service service, String currentUrl) async {
    final Uri? current = Uri.tryParse(currentUrl);
    if (current == null || !_isServiceHost(currentUrl, service)) {
      showAppSnackBar(context, '只能在当前服务的页面中填充登录信息');
      return;
    }
    final String? scope = WebPasswordFill.scopeHostOf(current);
    if (scope == null) {
      showAppSnackBar(context, '无法识别当前页面地址');
      return;
    }
    final List<HttpCredential> all = await HttpCredentialStore.instance
        .credentialsFor(service.id);
    final List<HttpCredential> exact = all
        .where(
          (HttpCredential item) =>
              item.realm == WebPasswordFill.webRealm &&
              item.normalizedHost == scope,
        )
        .toList(growable: false);
    final List<HttpCredential> legacy = exact.isNotEmpty
        ? const <HttpCredential>[]
        : all
              .where(
                (HttpCredential item) =>
                    item.realm == WebPasswordFill.webRealm &&
                    item.normalizedHost == current.host.toLowerCase(),
              )
              .toList(growable: false);
    final List<HttpCredential> matching = <HttpCredential>[...exact, ...legacy];
    if (!mounted) {
      return;
    }
    if (matching.isEmpty) {
      showAppSnackBar(context, '没有找到该服务的已保存登录信息');
      return;
    }
    HttpCredential selected = matching.first;
    if (matching.length > 1) {
      final HttpCredential? chosen = await showCredentialPicker(
        context,
        credentials: matching,
      );
      if (chosen == null || !mounted) {
        return;
      }
      selected = chosen;
    }
    final Map<String, Object?>? result = await _runWebJson(
      WebPasswordFill.fillScript(
        username: selected.username,
        password: selected.password,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result?['ok'] == true) {
      showAppSnackBar(context, '已填充 ${selected.username} 的登录信息');
    } else if (result?['reason'] == 'no-password') {
      showAppSnackBar(context, '当前页面没有找到密码输入框');
    } else {
      showAppSnackBar(context, '无法填充当前页面，请手动输入');
    }
  }

  Future<void> _saveLogin(Service service, String currentUrl) async {
    final Uri? current = Uri.tryParse(currentUrl);
    if (current == null || !_isServiceHost(currentUrl, service)) {
      showAppSnackBar(context, '只能在当前服务的页面中保存登录信息');
      return;
    }
    final Map<String, Object?>? captured = await _runWebJson(
      WebPasswordFill.captureScript,
    );
    if (!mounted) {
      return;
    }
    if (captured == null || captured['ok'] != true) {
      showAppSnackBar(context, '当前页面没有找到可保存的登录表单');
      return;
    }
    final String username = (captured['username'] as String? ?? '').trim();
    final String password = captured['password'] as String? ?? '';
    final String pageHost = (captured['host'] as String? ?? '').toLowerCase();
    if (username.isEmpty || password.isEmpty) {
      showAppSnackBar(context, '请先在网页中填写用户名和密码');
      return;
    }
    final String? scope = WebPasswordFill.scopeHostOf(current);
    if (scope == null || pageHost != scope) {
      showAppSnackBar(context, '页面地址已变化，请重试');
      return;
    }
    final bool confirmed = await showSaveWebPasswordDialog(
      context,
      serviceName: service.name,
      host: pageHost,
      username: username,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await HttpCredentialStore.instance.save(
        HttpCredential(
          serviceId: service.id,
          host: pageHost,
          realm: WebPasswordFill.webRealm,
          username: username,
          password: password,
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        showAppSnackBar(context, '登录信息已加密保存');
      }
    } on Object {
      if (mounted) {
        showAppSnackBar(context, '登录信息保存失败');
      }
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
      case MoreAction.fillPassword:
        await _fillLogin(service, currentUrl);
        return;
      case MoreAction.savePassword:
        await _saveLogin(service, currentUrl);
        return;
      case MoreAction.shareAddress:
        showAppSnackBar(context, '系统分享将在后续版本开放');
        return;
      case MoreAction.downloads:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const DownloadsPage()));
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
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
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
                                    onExit: _exitWebView,
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
                            onBack: _handleToolbarBack,
                            onRefresh: _handleRefresh,
                            onSwitchService: _openServiceSwitcher,
                            onMore: _openMore,
                            onExit: _exitWebView,
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
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
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
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
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
