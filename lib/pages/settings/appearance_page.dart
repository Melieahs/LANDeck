import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/feedback.dart';

/// Seed colours offered as one-tap theme swatches.
const List<Color> kThemeSeeds = <Color>[
  Color(0xFF2E6BE6),
  Color(0xFF6750A4),
  Color(0xFF8E4585),
  Color(0xFFD81B60),
  Color(0xFFC62828),
  Color(0xFFE8710A),
  Color(0xFFF9A825),
  Color(0xFF2E7D32),
  Color(0xFF00695C),
  Color(0xFF00838F),
  Color(0xFF455A64),
  Color(0xFF7A5C46),
];

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController controller = ThemeScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('主题')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kSettingsPageMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: <Widget>[
              const _SectionLabel('主题模式'),
              SegmentedButton<ThemeMode>(
                key: const ValueKey<String>('theme-mode-selector'),
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    label: Text('自动'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('浅色'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('深色'),
                  ),
                ],
                selected: <ThemeMode>{controller.mode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<ThemeMode> values) {
                  controller.setMode(values.first);
                },
              ),
              const SizedBox(height: 26),
              Row(
                children: <Widget>[
                  const Expanded(child: _SectionLabel('主题色彩')),
                  TextButton.icon(
                    key: const ValueKey<String>('theme-colors-reset'),
                    onPressed: () {
                      controller.setDynamicColor(false);
                      controller.setSeedColor(null);
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('重置'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DynamicColorBuilder(
                builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                  final bool dynamicSupported =
                      lightDynamic != null || darkDynamic != null;
                  return LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int columns = (c.maxWidth / 92).floor().clamp(3, 8);
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: <Widget>[
                          _DynamicSwatchTile(
                            supported: dynamicSupported,
                            selected: controller.dynamicColor,
                            onTap: () {
                              if (!dynamicSupported) {
                                showAppSnackBar(context, '当前系统不支持动态取色');
                                return;
                              }
                              controller.setDynamicColor(true);
                            },
                          ),
                          for (final Color seed in kThemeSeeds)
                            _SeedSwatchTile(
                              seed: seed,
                              selected:
                                  !controller.dynamicColor &&
                                  (controller.seedColor ?? AppThemeSeed.blue) ==
                                      seed,
                              onTap: () {
                                controller.setDynamicColor(false);
                                controller.setSeedColor(seed);
                              },
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 26),
              const _SectionLabel('其他'),
              const SizedBox(height: 6),
              Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      key: const ValueKey<String>('amoled-switch'),
                      secondary: const Icon(Icons.contrast_rounded),
                      title: const Text('纯黑模式'),
                      subtitle: const Text('深色模式下把页面背景换成纯黑（OLED 省电）'),
                      value: controller.amoled,
                      onChanged: controller.setAmoled,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      key: const ValueKey<String>('text-scale-switch'),
                      secondary: const Icon(Icons.format_size_rounded),
                      title: const Text('文本缩放'),
                      subtitle: Text(
                        '${(controller.textScale * 100).round()}% · 拖到 130% 适合大屏远看',
                      ),
                      value: controller.textScale != 1,
                      onChanged: (bool enabled) {
                        controller.setTextScale(enabled ? 1.1 : 1);
                      },
                    ),
                    if (controller.textScale != 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Slider(
                          key: const ValueKey<String>('text-scale-slider'),
                          min: ThemeController.minTextScale,
                          max: ThemeController.maxTextScale,
                          divisions: 9,
                          value: controller.textScale,
                          label: '${(controller.textScale * 100).round()}%',
                          onChanged: controller.setTextScale,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience alias so swatch selection can name the brand blue.
abstract final class AppThemeSeed {
  static const Color blue = Color(0xFF2E6BE6);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _DynamicSwatchTile extends StatelessWidget {
  const _DynamicSwatchTile({
    required this.supported,
    required this.selected,
    required this.onTap,
  });

  final bool supported;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _SwatchFrame(
      selected: selected,
      onTap: onTap,
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 26,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SeedSwatchTile extends StatelessWidget {
  const _SeedSwatchTile({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final Color seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme seedScheme = AppTheme.schemeFor(
      brightness: Brightness.light,
      seedColor: seed,
    ).colorScheme;
    return _SwatchFrame(
      selected: selected,
      onTap: onTap,
      child: Center(
        child: ClipOval(
          child: SizedBox(
            width: 42,
            height: 42,
            child: CustomPaint(
              painter: _QuadrantPainter(<Color>[
                seedScheme.primary,
                seedScheme.secondary,
                seedScheme.tertiary,
                seedScheme.primaryContainer,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwatchFrame extends StatelessWidget {
  const _SwatchFrame({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: child),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuadrantPainter extends CustomPainter {
  _QuadrantPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()..isAntiAlias = true;
    final List<Rect> quadrants = <Rect>[
      Rect.fromLTWH(rect.left, rect.top, size.width / 2, size.height / 2),
      Rect.fromLTWH(rect.center.dx, rect.top, size.width / 2, size.height / 2),
      Rect.fromLTWH(rect.left, rect.center.dy, size.width / 2, size.height / 2),
      Rect.fromLTWH(
        rect.center.dx,
        rect.center.dy,
        size.width / 2,
        size.height / 2,
      ),
    ];
    for (int i = 0; i < quadrants.length; i++) {
      canvas.drawRect(quadrants[i], paint..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(_QuadrantPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
