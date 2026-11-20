import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/models/http_credential.dart';
import 'package:landeck/pages/webview/widgets/http_auth_dialog.dart';

void main() {
  testWidgets('auth dialog collects credentials and remember choice', (
    WidgetTester tester,
  ) async {
    HttpAuthResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showHttpAuthDialog(
                    context,
                    serviceName: 'Padavan',
                    address: '192.168.1.1:80',
                    host: '192.168.1.1',
                    realm: 'Padavan',
                    initialUsername: 'admin',
                    errorText: '认证失败，请检查用户名和密码',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('http-auth-dialog')),
      findsOneWidget,
    );
    expect(find.text('需要身份验证'), findsOneWidget);
    expect(find.text('Padavan'), findsWidgets);
    expect(find.text('认证失败，请检查用户名和密码'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('http-auth-password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey<String>('http-auth-remember')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('http-auth-submit')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.username, 'admin');
    expect(result!.password, 'secret');
    expect(result!.remember, isTrue);
    expect(
      find.byKey(const ValueKey<String>('http-auth-dialog')),
      findsNothing,
    );
  });

  testWidgets('auth dialog cancel returns null and does not submit', (
    WidgetTester tester,
  ) async {
    HttpAuthResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showHttpAuthDialog(
                  context,
                  serviceName: 'Padavan',
                  address: '192.168.1.1:80',
                  host: '192.168.1.1',
                  realm: 'Padavan',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('http-auth-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  test('stored credential does not expose password in toString', () {
    final HttpCredential credential = HttpCredential(
      serviceId: 's',
      host: 'h',
      realm: 'r',
      username: 'u',
      password: 'p',
      updatedAt: DateTime(2026),
    );
    expect(credential.toString(), isNot(contains('password')));
  });
}
