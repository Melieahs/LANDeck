import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/app.dart';
import 'package:landeck/pages/webview/widgets/web_view_toolbar.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  late LanDeckRepository repository;

  setUp(() async {
    repository = await createTestRepository();
    await repository.addService(
      name: '测试服务',
      customUrl: 'http://192.168.1.10:8080',
      isFavorite: true,
    );
  });

  testWidgets('webview chrome is hidden and real URL is shown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(Key('favorite-${repository.services.single.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('webview-handle')), findsOneWidget);
    expect(find.byKey(const Key('webview-toolbar')), findsNothing);
    expect(find.text('当前平台没有系统 WebView'), findsOneWidget);
    expect(find.text('http://192.168.1.10:8080'), findsOneWidget);
  });

  testWidgets('toolbar expands and opens the service switcher', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(LanDeckApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('favorite-${repository.services.single.id}')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('webview-handle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('webview-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('webview-back')), findsOneWidget);
    expect(find.byKey(const Key('webview-more')), findsOneWidget);

    await tester.tap(find.byKey(const Key('webview-service-switch')));
    await tester.pumpAndSettle();
    expect(find.text('切换服务'), findsWidgets);
    expect(find.text('测试服务'), findsWidgets);
  });

  testWidgets('long press wheel selects a shortcut and centre cancels', (
    WidgetTester tester,
  ) async {
    int refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: WebViewHandle(
              key: const Key('webview-handle'),
              expanded: false,
              onTap: () {},
              onBack: () {},
              onRefresh: () => refreshCount++,
              onSwitchService: () {},
              onMore: () {},
              onExit: () {},
            ),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(
      find.byKey(const Key('webview-handle')),
    );
    final TestGesture gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 620));
    expect(find.byKey(const Key('quick-action-wheel')), findsOneWidget);

    await gesture.moveBy(const Offset(-30, -110));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-action-wheel')), findsNothing);
    expect(refreshCount, 1);

    final TestGesture cancelGesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 620));
    expect(find.byKey(const Key('quick-action-wheel')), findsOneWidget);
    await cancelGesture.moveBy(const Offset(-100, -80));
    await tester.pump();
    await cancelGesture.moveTo(center);
    await tester.pump();
    await cancelGesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-action-wheel')), findsNothing);
    expect(refreshCount, 1);
  });
}
