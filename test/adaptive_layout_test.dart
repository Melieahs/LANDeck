import 'package:flutter/foundation.dart';
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

  testWidgets('desktop windows use the narrow icon rail', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(1024, 768));
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    final Finder rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).width, lessThanOrEqualTo(100));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('全部服务'), findsOneWidget);
  });

  testWidgets('narrow desktop windows fall back to one column', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(760, 700));
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    // Favorites and services are stacked, not side by side, so their left
    // edges line up.
    final double favoritesLeft = tester.getTopLeft(find.text('收藏')).dx;
    final double servicesLeft = tester.getTopLeft(find.text('全部服务')).dx;
    expect(servicesLeft, moreOrLessEquals(favoritesLeft, epsilon: 1));
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
