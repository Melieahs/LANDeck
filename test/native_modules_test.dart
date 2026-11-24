import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/core/app_scope.dart';
import 'package:landeck/core/theme/app_theme.dart';
import 'package:landeck/models/service.dart';
import 'package:landeck/models/service_mode.dart';
import 'package:landeck/native/builtin/service_overview_module.dart';
import 'package:landeck/native/native_module_registry.dart';
import 'package:landeck/pages/service/native_service_page.dart';
import 'package:landeck/pages/services/service_editor_page.dart';
import 'package:landeck/pages/service/service_viewer_page.dart';
import 'package:landeck/pages/webview/widgets/service_switcher_sheet.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:flutter/material.dart';

import 'test_helpers.dart';

void main() {
  late LanDeckRepository repository;
  late Service service;

  setUp(() async {
    repository = await createTestRepository();
    service = await repository.addService(
      name: '测试 NAS',
      customUrl: 'http://192.168.1.10:8080',
      nativeModuleId: ServiceOverviewNativeModule.moduleId,
    );
  });

  test('built-in overview module is installed and compatible', () {
    final NativeModuleRegistry registry = NativeModuleRegistry.instance;
    expect(registry.byId(ServiceOverviewNativeModule.moduleId), isNotNull);
    expect(registry.linkedModule(service), isNotNull);
    expect(
      registry.compatibleModules(service).map((m) => m.id),
      contains(ServiceOverviewNativeModule.moduleId),
    );
  });

  test('service mode is persisted and defaults to web', () async {
    expect(service.defaultMode, ServiceMode.web);
    await repository.setDefaultMode(service.id, ServiceMode.native);
    expect(repository.serviceById(service.id)!.defaultMode, ServiceMode.native);
    expect(
      (Service.fromMap(
        repository.serviceById(service.id)!.toMap(),
      )).defaultMode,
      ServiceMode.native,
    );
  });

  testWidgets('native service page renders real service metadata', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await repository.setDefaultMode(service.id, ServiceMode.native);
      await repository.markServiceOpened(service.id);
    });
    await tester.pumpWidget(
      AppScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: NativeServicePage(
            serviceId: service.id,
            moduleId: ServiceOverviewNativeModule.moduleId,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('服务概览'), findsOneWidget);
    expect(find.text('访问地址'), findsOneWidget);
    expect(find.text('http://192.168.1.10:8080'), findsOneWidget);
    expect(find.byKey(const Key('native-service-switcher')), findsOneWidget);
  });

  testWidgets('native exit pops the page without looping', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await repository.setDefaultMode(service.id, ServiceMode.native);
      await repository.markServiceOpened(service.id);
    });
    bool popped = false;
    await tester.pumpWidget(
      AppScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => NativeServicePage(
                          serviceId: service.id,
                          moduleId: ServiceOverviewNativeModule.moduleId,
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('打开原生页'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开原生页'));
    await tester.pumpAndSettle();
    expect(find.text('服务概览'), findsOneWidget);

    await tester.tap(find.byKey(const Key('native-service-exit')));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(find.byKey(const Key('native-service-exit')), findsNothing);
  });

  testWidgets('switcher exposes Web and native modes for a linked service', (
    WidgetTester tester,
  ) async {
    ServiceSelection? selection;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  selection = await showServiceSwitcherSheet(
                    context,
                    services: <Service>[service],
                    current: service,
                    currentMode: ServiceMode.web,
                    deviceNameFor: (_) => '测试设备',
                  );
                },
                child: const Text('打开切换器'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开切换器'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey<String>('service-mode-${service.id}-web')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('service-mode-${service.id}-native')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey<String>('service-mode-${service.id}-native')),
    );
    await tester.pumpAndSettle();
    expect(selection, isNotNull);
    expect(selection!.mode, ServiceMode.native);
    expect(selection!.service.id, service.id);
  });


  testWidgets('service editor can explicitly link a native module', (
    WidgetTester tester,
  ) async {
    final LanDeckRepository repo = repository;
    await tester.pumpWidget(
      AppScope(
        repository: repo,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ServiceEditorPage(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('service-name-field')),
      '原生测试服务',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('service-url-field')),
      'http://192.168.1.30:8080',
    );
    await tester.pump();
    await tester.drag(
      find.byType(ListView).last,
      const Offset(0, -700),
    );
    await tester.pump();
    await tester.drag(
      find.byType(ListView).last,
      const Offset(0, -700),
    );
    await tester.pump();
    final Finder moduleField = find.byKey(
      const ValueKey<String>('service-native-module-field'),
    );
    await tester.ensureVisible(moduleField);
    await tester.pump();
    await tester.tap(moduleField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务概览 · v1.0.0').last);
    await tester.pumpAndSettle();
    final Finder defaultMode = find.byKey(
      const ValueKey<String>('service-default-mode'),
    );
    await tester.ensureVisible(defaultMode);
    await tester.tap(
      find.descendant(of: defaultMode, matching: find.text('原生')),
    );
    await tester.pumpAndSettle();
    final Finder save = find.byKey(
      const ValueKey<String>('service-save-button'),
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final Service saved = repo.services
        .firstWhere((Service item) => item.name == '原生测试服务');
    expect(saved.nativeModuleId, ServiceOverviewNativeModule.moduleId);
    expect(saved.defaultMode, ServiceMode.native);
  });


  testWidgets('service viewer dispatches to the linked native module', (
    WidgetTester tester,
  ) async {
    final Service? linked = await tester.runAsync<Service>(() async {
      final Service created = await repository.addService(
        name: '原生跳转服务',
        customUrl: 'http://192.168.1.40:8080',
        nativeModuleId: ServiceOverviewNativeModule.moduleId,
      );
      await repository.setDefaultMode(created.id, ServiceMode.native);
      return created;
    });
    expect(linked, isNotNull);
    await tester.pumpWidget(
      AppScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ServiceViewerPage(serviceId: linked!.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('原生跳转服务'), findsWidgets);
    expect(find.text('服务概览'), findsWidgets);
  });
}
