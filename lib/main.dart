import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/audio/speech_service.dart';
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

    return SilenceOffScreen(
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Небо — основное состояние приложения, поэтому тёмная по умолчанию.
        themeMode: ThemeMode.dark,
        locale: Locale(interfaceLang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

/// Тишина, когда приложения нет на экране.
///
/// Стоит в корне, и это не лень найти место поточнее. Голос в игре один — его
/// делит забег с калибровкой, — и обе говорят одним `SpeechService`. Поставь
/// остановку в забеге, и онбординг продолжал бы читать фразы в закрытом окне;
/// поставь в каждом экране, который говорит, и правило разъедется при появлении
/// третьего. Приложение уходит с экрана целиком, значит и молчать оно должно
/// целиком.
///
/// Что при этом **не** делается здесь: таймеры круга. Они принадлежат забегу
/// (`RunController.leaveScreen`), и останавливать их должен тот, кто ими
/// владеет, — иначе появилось бы второе место, знающее, из чего состоит темп
/// круга.
///
/// Жалоба владельца, с которой всё началось: «когда я закрыл окно с игрой — она
/// продолжает работать в фоне — я слышу текст». Слышен был не остаток фразы, а
/// забег, который шёл без него; но остановить надо было и его, и голос.
class SilenceOffScreen extends ConsumerStatefulWidget {
  const SilenceOffScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SilenceOffScreen> createState() => _SilenceOffScreenState();
}

class _SilenceOffScreenState extends ConsumerState<SilenceOffScreen> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // В `initState`, а не полем с `late final`: ленивое поле, к которому не
    // обращается `build`, не создалось бы никогда — и молчания бы не было.
    _lifecycle = AppLifecycleListener(onStateChange: _screenChanged);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _screenChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    // `read`, а не `watch`: сервис нам нужен на мгновение и только чтобы
    // замолчать. Если его ещё никто не создавал, `stop` до платформы не
    // дойдёт — движок синтеза создаётся лениво, первым произнесением.
    ref.read(speechServiceProvider).stop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
