import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/app.dart';
import 'package:landeck/models/device.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:landeck/widgets/add_service_button.dart';
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
    expect(find.text('0 个本地服务'), findsOneWidget);
    expect(find.text('还没有添加服务'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('设备分类'), findsOneWidget);
    expect(find.byType(AddServiceButton), findsOneWidget);
  });

  testWidgets('manual add writes the service and updates home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    final Finder addButton = find.byType(AddServiceButton);
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
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.services.length, 1);
    expect(repository.services.single.name, '书房 NAS');
    expect(repository.services.single.url, 'http://192.168.1.10:5666');
    expect(find.text('书房 NAS'), findsWidgets);
    expect(find.text('1 个本地服务'), findsOneWidget);
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
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.services.length, 1);
    expect(repository.services.single.name, 'Jellyfin');
    expect(repository.services.single.url, 'http://192.168.1.10:8096');
    expect(find.text('Jellyfin'), findsWidgets);
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
