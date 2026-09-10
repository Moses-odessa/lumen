import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/core/l10n/interface_lang.dart';
import 'package:lumen/data/content/constellation_naming.dart';
import 'package:lumen/data/content/content_provider.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/data/repositories/player_repository.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/profile/application/stats_controller.dart';
import 'package:lumen/features/profile/presentation/profile_screen.dart';
import 'package:lumen/features/sky/application/sky_controller.dart';
import 'package:lumen/features/sky/presentation/sky_map.dart';
import 'package:lumen/features/sky/presentation/sky_screen.dart';

/// Что происходит с экранами, когда имена созвездий **не приезжают**.
///
/// Соседние файлы (`sky_naming_test.dart`, `profile_naming_test.dart`)
/// проверяют путь имени до подписи; здесь проверяется цена его отсутствия.
/// Отдельный файл потому, что подменяется другое: там — собранное именование,
/// здесь — запрос к базе, то есть путь через настоящий Riverpod. Именно в нём
/// и лежал дефект, которого рассуждением не видно.
///
/// Дефект был такой. `constellationNamingProvider` ловит исключение и отдаёт
/// `ConstellationNaming.slugsOnly()`, и докстрока объявляет этим, что «ошибка
/// не оставит игрока на индикаторе загрузки». Но Riverpod перезапускает
/// упавший провайдер сам — десять попыток с удвоением задержки, — и, пока они
/// идут, элемент стоит в `AsyncLoading`, а его `future` **не завершается**.
/// То есть `catch` не срабатывал вовсе: откат включался на одиннадцатой
/// попытке, секунд через сорок. Небо и профиль эти сорок секунд держали
/// индикатор загрузки, а `ReminderScheduler.reschedule()` — ждал.
///
/// Поэтому все проверки здесь считают **кадры**, а не терпение: фальшивые
/// таймеры виджет-теста не двигаются сами, и `pump()` без длительности не
/// даёт сработать ни одному таймеру повтора. Тест, который прошёл бы «через
/// сорок секунд», здесь падает.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase db;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_naming_fallback');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? support.path
          : null,
    );
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Игрок учит немецкий с украинскими подсказками, интерфейс немецкий.
  ///
  /// `namesFail` — база имён, которая отвечает отказом; подменяется
  /// **запрос**, а не собранное именование, потому что проверяется путь через
  /// настоящий Riverpod. Исключение, а не `Error`, и это не мелочь:
  /// `ProviderContainer.defaultRetry` повторяет исключения и отказывается
  /// повторять ошибки, так что подмена `Error` проверяла бы единственный
  /// путь, на котором дефекта никогда и не было, — web, где контентный
  /// executor бросает `UnsupportedError`. Текст взят с настоящей сборки: так
  /// выглядит ассет прошлого релиза, в котором таблицы имён ещё нет.
  ///
  /// `sky` и `stats` подаются **значением**, а не броском, и это тоже про
  /// повторы: упавший провайдер Riverpod перезапускает, и до ветки ошибки
  /// экран сначала простоял бы сорок секунд на индикаторе. Проверяется здесь
  /// не как ошибка возникает, а что игрок в ней видит.
  ProviderContainer containerFor({
    bool namesFail = false,
    AsyncValue<SkySnapshot>? sky,
    AsyncValue<PlayerStats>? stats,
  }) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (namesFail)
        constellationNamesProvider.overrideWith(
          (ref, lang) => throw Exception(
            'SqliteException(1): no such table: constellation_names, '
            'SQL logic error',
          ),
        ),
      if (sky != null) skySnapshotProvider.overrideWithValue(sky),
      if (stats != null) playerStatsProvider.overrideWithValue(stats),
    ]);
    addTearDown(container.dispose);
    container.read(playerControllerProvider.notifier).replace(
          const Player(
            targetLang: 'de',
            nativeLang: 'uk',
            uiLang: 'de',
            tier: Tier.a0,
            calibrated: true,
          ),
        );
    return container;
  }

  /// Экран в дереве и два кадра.
  ///
  /// Двух хватает и больше не нужно: в первом провайдеры создаются, во втором
  /// видно то, чем они ответили за микрозадачи между кадрами. Длительности у
  /// `pump` нет намеренно — фальшивое время не должно двигаться, иначе тест
  /// согласится и с откатом через сорок секунд повторов. `pumpAndSettle` по
  /// той же причине нельзя: он двигает время до пустой очереди таймеров.
  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer container,
    Widget home,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(container.read(interfaceLangProvider)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('отказ базы имён не держит небо на индикаторе', (tester) async {
    final container = containerFor(namesFail: true);

    // Настоящий ввод-вывод в виджет-тесте живёт только внутри `runAsync`:
    // обычный `await` идёт по фальшивым таймерам и не заканчивается никогда,
    // а состав неба — это копирование ассета в файл и чтение с диска.
    final slug = await tester.runAsync(() async {
      final snapshot = await container.read(skySnapshotProvider.future);
      await container.read(launchedTiersProvider.future);
      return snapshot.placements.first.name;
    });
    container.read(selectedConstellationProvider.notifier).toggle(slug);

    await pumpScreen(tester, container, const SkyScreen());

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'имена не приехали — но небо-то прочитано, ждать нечего');
    expect(find.byType(SkyMap), findsOneWidget);
    // Третье звено отката: слаг на карте. Некрасиво и ровно поэтому полезно —
    // битую сборку он выдаёт заметнее, чем пустой экран.
    expect(find.text(slug!), findsOneWidget);
  });

  testWidgets('отказ базы имён не держит профиль на индикаторе',
      (tester) async {
    final container = containerFor(namesFail: true);

    // Список яркости лежит в конце длинного `ListView`, а `ListView` строит
    // только видимое: на окне 800×600 строк тем просто не существует.
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stats = await tester.runAsync(() async {
      final value = await container.read(playerStatsProvider.future);
      await container.read(launchedTiersProvider.future);
      return value;
    });

    await pumpScreen(tester, container, const ProfileScreen());

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'статистика прочитана — ждать нечего');
    expect(stats!.constellations, isNotEmpty,
        reason: 'на ярусе A0 есть темы — иначе проверять нечего');
    expect(find.text(stats.constellations.first.constellation), findsOneWidget,
        reason: 'без имён профиль подписан слагами, а не пуст');
  });

  test('запись игрока не пересобирает именование', () async {
    // У `Player` нет `==`, поэтому любая запись — тумблер звука, ярус, орбита
    // и час игры в конце каждого ритуала — выглядела для именования сменой
    // зависимости. Провайдер асинхронный, и смена зависимости переводит его в
    // `AsyncLoading` не-seamless; оба экрана сопоставляют только `AsyncData`,
    // то есть подпись роняли в индикатор загрузки. Кадр почти никогда не
    // успевал нарисоваться — запрос уже в кеше, — и проверять его на экране
    // бессмысленно: тест зеленел бы на совпадении, на котором держалась и
    // сама невидимость. Поэтому здесь считаются **состояния** провайдера.
    final container = containerFor();
    await container.read(constellationNamingProvider.future);

    final states = <AsyncValue<ConstellationNaming>>[];
    final sub = container.listen(
      constellationNamingProvider,
      (_, next) => states.add(next),
    );
    addTearDown(sub.close);

    container.read(playerControllerProvider.notifier).setSoundEnabled(false);
    // Пересчёт Riverpod откладывает на конец цикла событий (без вложенного
    // `ProviderScope` — `Timer.zero`), поэтому проверять сразу после записи
    // нельзя: провайдер, который вот-вот перезапустится, ещё молчит.
    await pumpEventQueue();

    expect(states, isEmpty,
        reason: 'звук не имеет отношения к языку подсказок');

    // Обратная сторона: зависимость сужена, а не убрана. Смена языка
    // подсказок обязана пересобрать имена — иначе игрок, сменивший язык,
    // остался бы с подписями на прежнем.
    container.read(playerControllerProvider.notifier).setLanguages(
          nativeLang: 'ru',
        );
    await pumpEventQueue();

    expect(states, isNotEmpty,
        reason: 'смена языка подсказок именование не тронула');
  });

  testWidgets('небо, которое не прочиталось, не показывает исключение',
      (tester) async {
    // Здесь стоял `Text('$error')` — игроку на весь экран уезжал
    // `SqliteException(1): no such table…`. Состояние подаётся значением, а
    // не броском: упавший провайдер Riverpod повторяет, и до ветки ошибки
    // экран сначала простоял бы те же сорок секунд на индикаторе (это верно и
    // для `skySnapshotProvider` — см. отчёт волны).
    final container = containerFor(
      sky: AsyncError(
        Exception('SqliteException(1): no such table: phrases'),
        StackTrace.empty,
      ),
    );

    await pumpScreen(tester, container, const SkyScreen());
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(find.textContaining('Exception'), findsNothing,
        reason: 'исключение Dart — не текст для игрока');
    expect(find.text(l10n.skyEmptyTitle), findsOneWidget);
    expect(find.text(l10n.skyEmptyBody), findsNothing,
        reason: 'причина известна только у пустого яруса, а не у отказа базы');
  });

  testWidgets('профиль, который не прочитался, не показывает исключение',
      (tester) async {
    final container = containerFor(
      stats: AsyncError(
        Exception('SqliteException(1): no such table: word_states'),
        StackTrace.empty,
      ),
    );

    await pumpScreen(tester, container, const ProfileScreen());
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text(l10n.skyEmptyTitle), findsOneWidget);
  });
}
