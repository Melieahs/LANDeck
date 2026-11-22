import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/widgets/empty_state.dart';
import 'package:landeck/widgets/list_skeleton.dart';

void main() {
  testWidgets('empty state shows icon, title, message and action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.dns_outlined,
            title: '还没有服务',
            message: '添加设备后再创建服务。',
            action: FilledButton(
              onPressed: () {},
              child: const Text('添加服务'),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
    expect(find.text('还没有服务'), findsOneWidget);
    expect(find.text('添加设备后再创建服务。'), findsOneWidget);
    expect(find.text('添加服务'), findsOneWidget);
  });

  testWidgets('empty state without message or action stays compact', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmptyState(icon: Icons.inbox_outlined, title: '空')),
      ),
    );

    expect(find.text('空'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('skeleton renders one block per row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListSkeleton(rows: 3, padding: EdgeInsets.zero),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ListSkeleton),
        matching: find.byType(Container),
      ),
      findsNWidgets(3 * 4),
    );
  });
}
