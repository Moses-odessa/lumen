import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/l10n/app_localizations.dart';
import 'core/l10n/interface_lang.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_service.dart';
import 'data/repositories/persistence.dart';

/// DSN Sentry передаётся при сборке: `--dart-define=SENTRY_DSN=...`.
/// Пусто → мониторинг выключен, dev и тесты работают как обычно.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

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

class LumenApp extends ConsumerStatefulWidget {
  const LumenApp({super.key});

  @override
  ConsumerState<LumenApp> createState() => _LumenAppState();
}

class _LumenAppState extends ConsumerState<LumenApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Игрок сменил язык телефона, не выходя из игры.
  ///
  /// Локали системы — вход `interfaceLangProvider`, но вход, о смене которого
  /// Riverpod не знает: провайдер пересчитывается по зависимостям, а не по
  /// сигналам платформы. Без этого сброса интерфейс переключился бы сразу
  /// (его переспрашивает Flutter сам), а имена созвездий остались бы на
  /// прежнем языке до перезапуска — ровно то расхождение, ради которого язык
  /// интерфейса решается одним провайдером.
  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(interfaceLangProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Язык интерфейса — отдельная настройка от родного языка игрока: можно
    // учить немецкий с украинского, а интерфейс держать английским. Решает
    // его `interfaceLangProvider`, и локаль здесь ему подчиняется, а не
    // выбирается заново: тот же провайдер отвечает за язык имён созвездий,
    // и подчинённый интерфейс с подписями разойтись не может. Два
    // независимых разрешения локали — могут.
    final interfaceLang = ref.watch(interfaceLangProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Небо — основное состояние приложения, поэтому тёмная по умолчанию.
      themeMode: ThemeMode.dark,
      locale: Locale(interfaceLang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
