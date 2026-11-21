import 'package:material_ui/material_ui.dart';

import '../models/service.dart';

/// A native control surface for one or more services.
///
/// This is deliberately a compile-time interface for now. Dynamic discovery,
/// signing and execution of third-party modules are out of scope for this
/// iteration.
abstract class NativeModule {
  const NativeModule();

  String get id;
  String get name;
  String get version;
  String get description;

  /// Whether this module can control [service]. Compatibility is explicit and
  /// never inferred from a service name or address.
  bool supports(Service service);

  /// The Flutter content rendered inside the native service page.
  Widget buildPage(BuildContext context, Service service);
}

