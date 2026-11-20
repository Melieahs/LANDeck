import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';

/// Persists the user's light / dark / system preference in the local database.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._database, this._mode, this._dynamicColor);

  // Keeps the public parameter name while storing a private field.
  // ignore: prefer_initializing_formals
  ThemeController.inMemory({bool dynamicColor = true})
    : _database = null,
      _mode = ThemeMode.system,
      // ignore: prefer_initializing_formals
      _dynamicColor = dynamicColor;

  static const String settingKey = 'theme_mode';
  static const String dynamicColorKey = 'dynamic_color';

  final AppDatabase? _database;
  ThemeMode _mode;
  bool _dynamicColor;

  ThemeMode get mode => _mode;

  /// Material You is enabled by default. Unsupported platforms fall back to
  /// the LANDeck brand scheme (the app checks the dynamic scheme availability).
  bool get dynamicColor => _dynamicColor;

  static Future<ThemeController> load(AppDatabase database) async {
    ThemeMode mode = ThemeMode.system;
    bool dynamicColor = true;
    try {
      final String? stored = await database.readSetting(settingKey);
      mode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final String? storedDynamic = await database.readSetting(dynamicColorKey);
      if (storedDynamic == 'false') {
        dynamicColor = false;
      }
    } on Object {
      // A missing or unreadable preference simply falls back to defaults.
    }
    return ThemeController._(database, mode, dynamicColor);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    await _database?.writeSetting(settingKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setDynamicColor(bool enabled) async {
    if (_dynamicColor == enabled) {
      return;
    }
    _dynamicColor = enabled;
    notifyListeners();
    await _database?.writeSetting(dynamicColorKey, enabled ? 'true' : 'false');
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final ThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope is missing above this context');
    return scope!.notifier!;
  }
}
