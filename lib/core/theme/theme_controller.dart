import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';

/// Persists the user's light / dark / system preference in the local database.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._database, this._mode);

  ThemeController.inMemory()
      : _database = null,
        _mode = ThemeMode.system;

  static const String settingKey = 'theme_mode';

  final AppDatabase? _database;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  static Future<ThemeController> load(AppDatabase database) async {
    ThemeMode mode = ThemeMode.system;
    try {
      final String? stored = await database.readSetting(settingKey);
      mode = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } on Object {
      // A missing or unreadable preference simply falls back to system mode.
    }
    return ThemeController._(database, mode);
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
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final ThemeScope? scope =
        context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope is missing above this context');
    return scope!.notifier!;
  }
}
