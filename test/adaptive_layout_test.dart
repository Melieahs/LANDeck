import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/app.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  late LanDeckRepository repository;

  setUp(() async {
    repository = await createTestRepository();
  });

  void useSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('tablets use the navigation rail and a two-column home', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(1024, 1366));

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('main-navigation-rail')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);

    // Column headers from both columns are visible at the same time.
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('设备'), findsWidgets);
    expect(find.text('全部服务'), findsOneWidget);
  });

  testWidgets('phones keep the bottom navigation bar', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(390, 844));

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('main-navigation-rail')),
      findsNothing,
    );
  });

  testWidgets('landscape phones stay compact', (WidgetTester tester) async {
    useSurface(tester, const Size(844, 390));

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('main-navigation-rail')),
      findsNothing,
    );
  });

  testWidgets('the rail switches tabs on a tablet', (WidgetTester tester) async {
    useSurface(tester, const Size(1024, 1366));

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('设置'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
