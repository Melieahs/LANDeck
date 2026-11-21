import 'package:material_ui/material_ui.dart';

import '../../models/service.dart';
import '../native_module.dart';
import '../padavan/padavan_native_page.dart';

/// First concrete native module: a real Padavan WAN/WISP control surface.
///
/// It works against the router's own `/device-map/` HTTP endpoints and only
/// exposes the operations confirmed by the firmware source. No configuration
/// writes or firmware-specific guesswork are performed.
class PadavanNativeModule extends NativeModule {
  const PadavanNativeModule();

  static const String moduleId = 'builtin.padavan';

  @override
  String get id => moduleId;

  @override
  String get name => 'Padavan 路由器';

  @override
  String get version => '1.0.0';

  @override
  String get description => '查看 WAN 状态，执行 WAN 重连、断开和无线中继重新关联。';

  @override
  bool supports(Service service) {
    final Uri? uri = service.uri;
    return uri != null && uri.host.isNotEmpty;
  }

  @override
  Widget buildPage(BuildContext context, Service service) =>
      PadavanNativePage(serviceId: service.id);
}
