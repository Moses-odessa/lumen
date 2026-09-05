import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/persistence.dart';
import 'data/repositories/player_repository.dart';

/// DSN Sentry передаётся при сборке: `--dart-define=SENTRY_DSN=...`.
/// Пусто → мониторинг выключен, dev и тесты работают как обычно.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // Состояние игрока загружается до первого кадра — иначе у прошедшего
  // калибровку мигнёт онбординг (инвариант из README).
  await bootstrapPersistence(container);

  final app = UncontrolledProviderScope(
    container: container,
    child: const LumenApp(),
  );

  if (_sentryDsn.isEmpty) {
    runApp(app);
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      // Приватность: ни PII, ни трейсинга — только краши.
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0;
    },
    appRunner: () => runApp(app),
  );
}

class LumenApp extends ConsumerWidget {
  const LumenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Язык интерфейса — отдельная настройка от родного языка игрока:
    // можно учить немецкий с украинского, а интерфейс держать английским.
    final uiLang = ref.watch(playerControllerProvider)?.uiLang;

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Небо — основное состояние приложения, поэтому тёмная по умолчанию.
      themeMode: ThemeMode.dark,
      locale: uiLang == null ? null : Locale(uiLang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
