import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/app.dart';
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
}
