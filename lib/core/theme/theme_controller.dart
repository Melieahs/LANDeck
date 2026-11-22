import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';

/// Persists the user's light / dark / system preference in the local database.
class ThemeController extends ChangeNotifier {
  ThemeController._(
    this._database,
    this._mode,
    this._dynamicColor,
    this._seedColor,
    this._amoled,
    this._textScale,
  );

  // Keeps the public parameter name while storing a private field.
  // ignore: prefer_initializing_formals
  ThemeController.inMemory({
    bool dynamicColor = true,
    Color? seedColor,
    bool amoled = false,
    double textScale = 1,
  }) : _database = null,
       _mode = ThemeMode.system,
       // ignore: prefer_initializing_formals
       _dynamicColor = dynamicColor,
       // ignore: prefer_initializing_formals
       _seedColor = seedColor,
       // ignore: prefer_initializing_formals
       _amoled = amoled,
       // ignore: prefer_initializing_formals
       _textScale = textScale;

  static const String settingKey = 'theme_mode';
  static const String dynamicColorKey = 'dynamic_color';
  static const String seedColorKey = 'theme_seed';
  static const String amoledKey = 'amoled_black';
  static const String textScaleKey = 'text_scale';

  final AppDatabase? _database;
  ThemeMode _mode;
  bool _dynamicColor;
  Color? _seedColor;
  bool _amoled;
  double _textScale;

  ThemeMode get mode => _mode;

  /// Material You is enabled by default. Unsupported platforms fall back to
  /// the LANDeck brand scheme (the app checks the dynamic scheme availability).
  bool get dynamicColor => _dynamicColor;

  /// Custom brand seed; null keeps the stock LANDeck blue.
  Color? get seedColor => _seedColor;

  /// AMOLED mode: a true black page instead of the charcoal dark theme.
  bool get amoled => _amoled;

  /// Multiplier applied to every text style.
  double get textScale => _textScale;

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;

  static Future<ThemeController> load(AppDatabase database) async {
    ThemeMode mode = ThemeMode.system;
    bool dynamicColor = true;
    Color? seedColor;
    bool amoled = false;
    double textScale = 1;
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
      final String? storedSeed = await database.readSetting(seedColorKey);
      final int? seedValue = int.tryParse(storedSeed ?? '');
      if (seedValue != null) {
        seedColor = Color(seedValue);
      }
      final String? storedAmoled = await database.readSetting(amoledKey);
      amoled = storedAmoled == 'true';
      final String? storedScale = await database.readSetting(textScaleKey);
      final double? scale = double.tryParse(storedScale ?? '');
      if (scale != null) {
        textScale = scale.clamp(minTextScale, maxTextScale);
      }
    } on Object {
      // A missing or unreadable preference simply falls back to defaults.
    }
    return ThemeController._(
      database,
      mode,
      dynamicColor,
      seedColor,
      amoled,
      textScale,
    );
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

  Future<void> setSeedColor(Color? color) async {
    if (_seedColor == color) {
      return;
    }
    _seedColor = color;
    notifyListeners();
    if (color == null) {
      await _database?.writeSetting(seedColorKey, '');
    } else {
      await _database?.writeSetting(seedColorKey, color.toARGB32().toString());
    }
  }

  Future<void> setAmoled(bool enabled) async {
    if (_amoled == enabled) {
      return;
    }
    _amoled = enabled;
    notifyListeners();
    await _database?.writeSetting(amoledKey, enabled ? 'true' : 'false');
  }

  Future<void> setTextScale(double scale) async {
    final double clamped = scale.clamp(minTextScale, maxTextScale);
    if (_textScale == clamped) {
      return;
    }
    _textScale = clamped;
    notifyListeners();
    await _database?.writeSetting(textScaleKey, clamped.toStringAsFixed(2));
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
