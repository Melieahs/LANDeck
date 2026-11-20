import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'repositories/service_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final AppDatabase database = await AppDatabase.open();
    final LanDeckRepository repository = LanDeckRepository(database);
    await repository.load();
    runApp(LanDeckApp(repository: repository));
  } on Object catch (error, stack) {
    debugPrint('LANDeck database startup failed: $error\n$stack');
    runApp(_BootstrapFailureApp(message: error.toString()));
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LANDeck',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.storage_rounded,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '本地数据库无法打开',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
