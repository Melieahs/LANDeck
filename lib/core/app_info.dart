import 'package:package_info_plus/package_info_plus.dart';

/// Version string of the running bundle, filled once during startup.
///
/// The settings page must never hard-code a version: it drifts every time
/// pubspec.yaml is bumped. [load] is best effort so widget tests and platforms
/// without a bundle simply keep [version] empty.
abstract final class AppInfo {
  static String version = '';

  static Future<void> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      version = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } on Object {
      // Tests and unsupported platforms keep the empty fallback.
    }
  }

  /// Human readable label: `0.9.18+43`, or `开发版` when the platform does not
  /// expose a package version.
  static String get label => version.isEmpty ? '开发版' : version;
}
