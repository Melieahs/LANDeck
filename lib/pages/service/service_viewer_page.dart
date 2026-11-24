import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../models/service.dart';
import '../../models/service_mode.dart';
import '../../native/native_module.dart';
import '../../native/native_module_registry.dart';
import '../../repositories/service_repository.dart';
import '../webview/macos_web_view_page.dart';
import '../webview/web_view_page.dart';
import '../webview/windows_web_view_page.dart';
import 'native_service_page.dart';

/// Chooses the presentation for an existing service without duplicating the
/// service record. Used by every "open service" entry point.
class ServiceViewerPage extends StatelessWidget {
  const ServiceViewerPage({
    super.key,
    required this.serviceId,
    this.initialMode,
  });

  final String serviceId;
  final ServiceMode? initialMode;

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Service? service = repository.serviceById(serviceId);
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('服务')),
        body: const Center(child: Text('服务不存在或已被删除')),
      );
    }
    final NativeModule? module = NativeModuleRegistry.instance.linkedModule(
      service,
    );
    final ServiceMode mode = initialMode ?? service.defaultMode;
    if (mode == ServiceMode.native && module != null) {
      return NativeServicePage(
        serviceId: service.id,
        moduleId: module.id,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return WindowsWebViewPage(serviceId: service.id);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return MacosWebViewPage(serviceId: service.id);
    }
    return WebViewPage(serviceId: service.id);
  }
}
