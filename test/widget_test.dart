import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/app.dart';
import 'package:landeck/core/theme/theme_controller.dart';
import 'package:landeck/models/device.dart';
import 'package:landeck/models/service.dart';
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

    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('还没有添加服务'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('还没有添加设备'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey<String>('appearance-entry')));
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

  testWidgets('home search submit opens dedicated search page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home-search-field')));
    await tester.enterText(find.byType(TextField).first, 'NAS');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('search-page')), findsOneWidget);
    expect(find.textContaining('没有找到与「NAS」'), findsOneWidget);
  });

  testWidgets('home stats open services and devices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home-stat-services')));
    await tester.pumpAndSettle();
    expect(find.text('全部服务'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('home-stat-devices')));
    await tester.pumpAndSettle();
    expect(find.text('设备管理'), findsOneWidget);
  });

  testWidgets('data storage opens backup, import and password manager', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('nav-destination-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('数据存储'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('数据存储'));
    await tester.pumpAndSettle();

    expect(find.text('FTP 数据互通'), findsOneWidget);
    expect(find.text('导出配置'), findsOneWidget);
    expect(find.text('导入配置'), findsOneWidget);
    expect(find.text('密码管理'), findsOneWidget);
  });

  testWidgets('theme segments fit a narrow phone', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('nav-destination-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('appearance-entry')));
    await tester.pumpAndSettle();
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('纯黑模式'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('纯黑模式'), findsOneWidget);
    expect(find.text('文本缩放'), findsOneWidget);
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

  testWidgets('home fits a narrow phone without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final Device device = await repository.addDevice(
        name: '很长的客厅 NAS 设备名称',
        deviceType: DeviceType.nas,
        primaryAddress: '192.168.1.10',
      );
      await repository.addService(
        name: 'Jellyfin 影音服务器',
        deviceId: device.id,
        port: 8096,
        path: '/web',
        isFavorite: true,
      );
      await repository.addService(
        name: 'Home Assistant',
        deviceId: device.id,
        port: 8123,
      );
    });

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('all-services-add')), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
  });
  testWidgets('dragging a favorite card changes its order', (
    WidgetTester tester,
  ) async {
    late Service first;
    late Service second;
    await tester.runAsync(() async {
      first = await repository.addService(
        name: 'A 服务',
        customUrl: 'http://192.168.1.21',
        isFavorite: true,
      );
      second = await repository.addService(
        name: 'B 服务',
        customUrl: 'http://192.168.1.22',
        isFavorite: true,
      );
    });

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    final Finder firstCard = find.byKey(Key('favorite-${first.id}'));
    final Finder secondCard = find.byKey(Key('favorite-${second.id}'));
    expect(firstCard, findsOneWidget);
    expect(secondCard, findsOneWidget);

    await tester.tap(find.byKey(const Key('favorites-edit')));
    await tester.pumpAndSettle();

    final Offset start = tester.getCenter(firstCard);
    final Offset target = tester.getCenter(secondCard);
    final TestGesture gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    expect(
      repository.favorites.map((Service service) => service.id),
      <String>[second.id, first.id],
    );
  });

}
