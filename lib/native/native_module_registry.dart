import 'package:material_ui/material_ui.dart';

import '../models/service.dart';
import 'builtin/service_overview_module.dart';
import 'native_module.dart';

/// Lists installed native modules and resolves a service's explicit link.
class NativeModuleRegistry {
  NativeModuleRegistry._() {
    resetToDefaults();
  }

  static final NativeModuleRegistry instance = NativeModuleRegistry._();

  final List<NativeModule> _modules = <NativeModule>[];

  List<NativeModule> get installed => List<NativeModule>.unmodifiable(_modules);

  void register(NativeModule module) {
    if (_modules.any((NativeModule item) => item.id == module.id)) {
      return;
    }
    _modules.add(module);
  }

  /// Registers [module], replacing an imported module with the same id.
  void replace(NativeModule module) {
    _modules.removeWhere((NativeModule item) => item.id == module.id && !item.isBuiltin);
    register(module);
  }

  void unregister(String id) {
    _modules.removeWhere((NativeModule item) => item.id == id && !item.isBuiltin);
  }

  NativeModule? byId(String? id) {
    if (id == null) {
      return null;
    }
    for (final NativeModule module in _modules) {
      if (module.id == id) {
        return module;
      }
    }
    return null;
  }

  /// The module a service is explicitly linked to, if it is still installed and
  /// compatible. Returns null when the user has not linked one.
  NativeModule? linkedModule(Service service) {
    final NativeModule? module = byId(service.nativeModuleId);
    if (module == null || !module.supports(service)) {
      return null;
    }
    return module;
  }

  List<NativeModule> compatibleModules(Service service) => _modules
      .where((NativeModule module) => module.supports(service))
      .toList(growable: false);

  @visibleForTesting
  void clearForTests() {
    _modules.clear();
  }

  @visibleForTesting
  void resetToDefaults() {
    _modules.clear();
    register(const ServiceOverviewNativeModule());
  }
}
