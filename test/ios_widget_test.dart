import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/core/theme/theme_controller.dart';
import 'package:landeck/ios/lan_deck_ios_app.dart';
import 'package:landeck/models/device.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import 'test_helpers.dart';

Finder _field(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
}

void main() {
  late LanDeckRepository repository;
  late ThemeController themeController;

  setUp(() async {
    repository = await createTestRepository();
    themeController = ThemeController.inMemory();
  });

  testWidgets('iOS home shows native empty states and adds a device', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LanDeckIosApp(
        repository: repository,
        themeController: themeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LANDeck'), findsOneWidget);
    expect(find.text('还没有收藏的服务'), findsOneWidget);
    expect(find.text('添加第一台设备'), findsOneWidget);
    expect(find.text('还没有添加服务'), findsOneWidget);

    await tester.tap(find.text('添加第一台设备'));
    await tester.pumpAndSettle();
    expect(find.text('添加设备'), findsWidgets);

    await tester.enterText(
      _field(const ValueKey<String>('ios-device-name')),
      '书房 NAS',
    );
    await tester.enterText(
      _field(const ValueKey<String>('ios-device-address')),
      '192.168.1.20',
    );
    await tester.tap(find.byKey(const ValueKey<String>('ios-device-save')));
    await tester.pumpAndSettle();

    expect(repository.devices.single.name, '书房 NAS');
    expect(repository.devices.single.primaryAddress, '192.168.1.20');
    expect(find.text('书房 NAS'), findsWidgets);
  });

  testWidgets('iOS quick add builds URL from port only', (
    WidgetTester tester,
  ) async {
    await tester.runAsync<Device>(
      () => repository.addDevice(
        name: '客厅 NAS',
        deviceType: DeviceType.nas,
        primaryAddress: '192.168.1.10',
      ),
    );
    await tester.pumpWidget(
      LanDeckIosApp(
        repository: repository,
        themeController: themeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('客厅 NAS').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('添加服务'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      _field(const ValueKey<String>('ios-service-port')),
      '8096',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('ios-service-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(repository.services.single.name, 'Jellyfin');
    expect(repository.services.single.url, 'http://192.168.1.10:8096');
  });

  testWidgets('iOS settings switches appearance mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LanDeckIosApp(
        repository: repository,
        themeController: themeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('ios-theme-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(themeController.mode, ThemeMode.dark);
  });
}
