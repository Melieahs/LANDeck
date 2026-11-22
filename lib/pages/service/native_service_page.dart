import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../models/service.dart';
import '../../models/service_mode.dart';
import '../../native/native_module.dart';
import '../../native/native_module_registry.dart';
import '../webview/widgets/webview_bar_action.dart';
import '../../repositories/service_repository.dart';
import '../webview/web_view_sessions.dart';
import '../webview/widgets/service_switcher_sheet.dart';
import 'service_viewer_page.dart';

/// A real Flutter-native service screen. It shares the service record and the
/// global switcher with the WebView, so no duplicate service is created.
class NativeServicePage extends StatefulWidget {
  const NativeServicePage({
    super.key,
    required this.serviceId,
    required this.moduleId,
  });

  final String serviceId;
  final String moduleId;

  @override
  State<NativeServicePage> createState() => _NativeServicePageState();
}

class _NativeServicePageState extends State<NativeServicePage> {
  bool _marked = false;
  bool _allowExit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_marked) {
      return;
    }
    _marked = true;
    final LanDeckRepository repository = AppScope.of(context);
    repository.markServiceOpened(widget.serviceId);
  }

  Future<void> _switchService(Service current) async {
    final LanDeckRepository repository = AppScope.of(context);
    final ServiceSelection? selection = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: current,
      currentMode: ServiceMode.native,
      deviceNameFor: repository.deviceNameFor,
      openServiceIds: WebViewSessionRegistry.instance.serviceIds,
    );
    if (!mounted || selection == null) {
      return;
    }
    await repository.markServiceOpened(selection.service.id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ServiceViewerPage(
          serviceId: selection.service.id,
          initialMode: selection.mode,
        ),
      ),
    );
  }

  void _exitViewer() {
    if (_allowExit) {
      return;
    }
    WebViewSessionRegistry.instance.closeAll();
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _switchToWeb(Service service) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ServiceViewerPage(
          serviceId: service.id,
          initialMode: ServiceMode.web,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Service? service = repository.serviceById(widget.serviceId);
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('原生服务')),
        body: const Center(child: Text('服务不存在或已被删除')),
      );
    }
    final NativeModule? module = NativeModuleRegistry.instance.byId(
      widget.moduleId,
    );
    if (module == null || !module.supports(service)) {
      return Scaffold(
        appBar: webViewerAppBar(
          surface: Theme.of(context).colorScheme.surfaceContainer,
          leading: WebViewBarAction(
            key: const Key('native-service-exit'),
            tooltip: '退出',
            icon: Icons.arrow_back_rounded,
            onPressed: _exitViewer,
          ),
          title: Text(service.name),
          actions: const <Widget>[],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.extension_off_rounded, size: 42),
                const SizedBox(height: 12),
                const Text('原生模块不可用或与当前服务不兼容'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _switchToWeb(service),
                  child: const Text('返回 Web 模式'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final ThemeData theme = Theme.of(context);
    return PopScope<Object?>(
      canPop: _allowExit,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _exitViewer();
      },
      child: Scaffold(
        appBar: webViewerAppBar(
          surface: theme.colorScheme.surfaceContainer,
          leading: WebViewBarAction(
            key: const Key('native-service-exit'),
            tooltip: '退出',
            icon: Icons.arrow_back_rounded,
            onPressed: _exitViewer,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                service.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15.5,
                ),
              ),
              Text(
                module.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            WebViewBarAction(
              key: const Key('native-service-switcher'),
              tooltip: '切换服务',
              icon: Icons.swap_horiz_rounded,
              onPressed: () => _switchService(service),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: module.buildPage(context, service),
      ),
    );
  }
}
