import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/app.dart';
import 'package:landeck/core/theme/theme_controller.dart';
import 'package:landeck/models/device.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  late LanDeckRepository repository;

  setUp(() async {
    repository = await createTestRepository();
  });

  testWidgets('fresh install shows real empty states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('我的网络'), findsOneWidget);
    expect(find.text('还没有添加服务'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('全部设备 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-add-service')),
      findsOneWidget,
    );
  });

  testWidgets('manual add writes the service and updates home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    final Finder addButton = find.byKey(
      const ValueKey<String>('home-add-service'),
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('service-name-field')),
      '书房 NAS',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('service-url-field')),
      '192.168.1.10:5666',
    );

    final Finder save = find.byKey(
      const ValueKey<String>('service-save-button'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.services.length, 1);
    expect(repository.services.single.name, '书房 NAS');
    expect(repository.services.single.url, 'http://192.168.1.10:5666');
    expect(find.text('书房 NAS'), findsWidgets);
  });

  testWidgets('device quick add only needs a port and generates URL', (
    WidgetTester tester,
  ) async {
    final Device? device = await tester.runAsync<Device>(
      () => repository.addDevice(
        name: '飞牛 NAS',
        deviceType: DeviceType.nas,
        primaryAddress: '192.168.1.10',
      ),
    );
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('nav-destination-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设备管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('device-${device!.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('device-add-service')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('飞牛 NAS'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey<String>('service-port-field')),
      '8096',
    );
    await tester.pump();
    final Finder save = find.byKey(
      const ValueKey<String>('service-save-button'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.services.length, 1);
    expect(repository.services.single.name, 'Jellyfin');
    expect(repository.services.single.url, 'http://192.168.1.10:8096');
    expect(find.text('Jellyfin'), findsWidgets);
  });

  testWidgets('theme selector switches to light and dark', (
    WidgetTester tester,
  ) async {
    final ThemeController controller = ThemeController.inMemory();
    await tester.pumpWidget(
      LanDeckApp(repository: repository, themeController: controller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('nav-destination-2')));
    await tester.pumpAndSettle();
    final Finder selector = find.byKey(
      const ValueKey<String>('theme-mode-selector'),
    );
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.light);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.dark);
  });

  testWidgets('bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('nav-destination-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('当前网络'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('nav-destination-2')));
    await tester.pumpAndSettle();
    expect(find.text('设备管理'), findsOneWidget);
  });
}
