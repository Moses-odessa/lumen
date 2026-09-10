import 'dart:async';
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
import 'package:lumen/features/sky/application/sky_controller.dart';
import 'package:lumen/features/sky/presentation/sky_map.dart';
import 'package:lumen/features/sky/presentation/sky_screen.dart';

/// Имя созвездия от ассета до подписи на небе.
///
/// Проверяется здесь именно весь путь, а не сборка `ConstellationNaming`
/// отдельно: правило показа уже проверено на голых картах
/// (`test/data/constellation_naming_test.dart`), а сломаться после него могло
/// ровно одно — что имя до подписи не доходит. Так оно и было: на карте
/// стоял slug `place_time_price`, хотя все 250 имён лежали в базе.
///
/// Язык интерфейса берётся из настройки игрока и из локалей системы, и обе
/// ветки проверены до подписи на экране, а не до кода языка: системной идёт
/// продакшен у всех, кто интерфейс не трогал, и остановиться на
/// `interfaceLangProvider` значило бы проверить разрешение локали, но не путь
/// от него до текста.
///
/// Чего этот файл не проверяет: локаль `MaterialApp` он подаёт себе сам, и
/// связку в `main.dart` поймать не может — убери оттуда `locale:`, и все
/// тесты здесь останутся зелёными. Охраняет её
/// `test/features/interface_locale_test.dart` на настоящем `LumenApp`; почему
/// обещание пришлось составить из двух половин, написано там.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase db;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_naming');
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

  /// Игрок учит немецкий с украинскими подсказками; язык интерфейса — аргумент.
  ///
  /// `names` подменяет собранное именование своим future — тем самым, ответа
  /// которого экран ждёт вместе с небом. Отдаётся именно future, а не готовое
  /// значение: кадр ожидания и есть то, что проверяется, а завершать его
  /// должен тест, иначе «ждёт имена» не отличить от «ждёт вечно».
  ProviderContainer containerFor({
    required String? uiLang,
    Future<ConstellationNaming>? names,
  }) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (names != null)
        constellationNamingProvider.overrideWith((ref) => names),
    ]);
    addTearDown(container.dispose);
    container.read(playerControllerProvider.notifier).replace(
          Player(
            targetLang: 'de',
            nativeLang: 'uk',
            uiLang: uiLang,
            tier: Tier.a0,
            calibrated: true,
          ),
        );
    return container;
  }

  /// Экран неба с выбранным созвездием: подпись живёт в панели подробностей,
  /// и без выбора её на карте нет вовсе.
  ///
  /// Локаль `MaterialApp` берётся из того же `interfaceLangProvider`, что и
  /// имена: иначе тест проверял бы подпись в отрыве от языка, на котором
  /// игрок читает всё остальное, то есть не то расхождение, от которого
  /// провайдер и заведён. Но подана она здесь **своей рукой** и потому
  /// заменяет `main.dart`, а не проверяет его: строка эта повторяет ту, что
  /// стоит там, и об удалении той строки ни один тест этого файла не узнает.
  /// Отдельный тест на неё живёт в `interface_locale_test.dart`.
  Future<String> pumpSelected(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    // Настоящий ввод-вывод в виджет-тесте живёт только внутри `runAsync`:
    // обычный `await` в `testWidgets` идёт по фальшивым таймерам и не
    // заканчивается никогда, а контентная база — это копирование ассета в
    // файл и чтение с диска. Тест на этом висел до таймаута.
    final slug = await tester.runAsync(() async {
      final snapshot = await container.read(skySnapshotProvider.future);
      await container.read(launchedTiersProvider.future);
      return snapshot.placements.first.name;
    });
    container.read(selectedConstellationProvider.notifier).toggle(slug);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(container.read(interfaceLangProvider)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SkyScreen(),
        ),
      ),
    );
    // Одного кадра хватает: небо прочитано выше, а имена — запрос к уже
    // открытой базе, то есть цепочка микрозадач, которую этот же `pump`
    // и разворачивает. `pumpAndSettle` здесь нельзя: на экране с индикатором
    // загрузки он не заканчивается никогда, а именно этим индикатором держится
    // последний тест файла.
    await tester.pump();

    return slug!;
  }

  /// Имена тем на одном языке — из ассета, а не из констант в тесте: имена
  /// правятся файлами контента, и вписанные здесь устарели бы молча.
  Future<Map<String, String>> namesIn(
    WidgetTester tester,
    ProviderContainer container,
    String lang,
  ) async {
    final names = await tester.runAsync(() => container
        .read(currentContentDatabaseProvider)
        .constellationNamesFor(lang));
    return names!;
  }

  /// Имя одной темы на одном языке.
  Future<String> nameOf(
    WidgetTester tester,
    ProviderContainer container,
    String lang,
    String slug,
  ) async {
    final names = await namesIn(tester, container, lang);
    expect(names[slug], isNotNull, reason: 'у темы $slug нет имени на $lang');
    return names[slug]!;
  }

  testWidgets('подпись созвездия — имя темы, а не slug', (tester) async {
    final container = containerFor(uiLang: 'de');

    final slug = await pumpSelected(tester, container);
    final german = await nameOf(tester, container, 'de', slug);

    expect(find.text(german), findsOneWidget);
    expect(find.text(slug), findsNothing,
        reason: 'slug — идентичность темы, а не подпись');
  });

  testWidgets('интерфейс без имён откатывается на язык подсказок',
      (tester) async {
    // Так живёт француз: интерфейсов шесть, а имён пять языков — французского
    // контента нет вовсе. Показать ему slug вместо украинского имени значило
    // бы потерять последнее звено отката там, где оно и нужно.
    final container = containerFor(uiLang: 'fr');

    final slug = await pumpSelected(tester, container);
    final ukrainian = await nameOf(tester, container, 'uk', slug);
    final german = await nameOf(tester, container, 'de', slug);

    expect(find.text(ukrainian), findsOneWidget);
    expect(find.text(slug), findsNothing);
    expect(find.text(german), findsNothing,
        reason: 'язык изучения — не язык подсказок и не язык интерфейса');

    final naming =
        await tester.runAsync(() => container.read(constellationNamingProvider.future));
    expect(naming?.interfaceNames, isEmpty,
        reason: 'французских имён в базе нет — иначе тест проверяет не откат');
  });

  testWidgets('язык вне интерфейса уводит подпись туда же, куда интерфейс',
      (tester) async {
    // `Player.uiLang` — строка в базе игрока, и совпадать с
    // `supportedLocales` она не обязана: язык интерфейса мог уехать из
    // сборки. `MaterialApp` в таком случае берёт первую поддерживаемую
    // локаль, и подпись обязана поехать за ним. Выражением `names[uiLang]`
    // это не покрылось бы: имена искались бы на языке, которого игрок нигде
    // не видит, и подпись оказалась бы на третьем языке — не интерфейса и не
    // подсказок.
    final container = containerFor(uiLang: 'es');
    expect(container.read(interfaceLangProvider),
        AppLocalizations.supportedLocales.first.languageCode);

    final slug = await pumpSelected(tester, container);
    final resolved = await nameOf(
      tester,
      container,
      AppLocalizations.supportedLocales.first.languageCode,
      slug,
    );

    expect(find.text(resolved), findsOneWidget);
    expect(find.text(slug), findsNothing);
  });

  testWidgets('интерфейс по системе подписывает небо языком системы',
      (tester) async {
    // Ветка `uiLang == null` — та, которой идёт продакшен у всех, кто оставил
    // интерфейс «как в системе». Проверяется она до подписи, а не до кода
    // языка: между разрешением локали и текстом на экране лежит вся сборка
    // именования, и раньше эта ветка обрывалась на `interfaceLangProvider`.
    //
    // Итальянский взят потому, что он есть и в интерфейсе, и в именах, а
    // подсказки у игрока украинские: откатись подпись на язык подсказок —
    // разница видна сразу, а не совпала бы молча.
    binding.platformDispatcher.localesTestValue = const [Locale('it')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);

    final container = containerFor(uiLang: null);
    expect(container.read(interfaceLangProvider), 'it');

    final slug = await pumpSelected(tester, container);
    final italian = await nameOf(tester, container, 'it', slug);
    final ukrainian = await nameOf(tester, container, 'uk', slug);

    expect(find.text(italian), findsOneWidget);
    expect(find.text(slug), findsNothing);
    expect(find.text(ukrainian), findsNothing,
        reason: 'язык подсказок — второе звено отката, а не первое');
  });

  test('интерфейс по системе сведён к поддерживаемым локалям', () {
    // Продолжение ветки `uiLang == null` там, где до подписи её не довести:
    // испанского нет ни в интерфейсе, ни в именах, и проверять на экране
    // нечего — но свести локаль система обязана так же, как её сводит
    // Flutter, иначе подпись уйдёт на язык, которого игрок нигде не видит.
    // Путь до текста проверен тестом выше.
    final container = containerFor(uiLang: null);
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);

    binding.platformDispatcher.localesTestValue = const [Locale('it')];
    expect(container.read(interfaceLangProvider), 'it');

    binding.platformDispatcher.localesTestValue = const [Locale('es')];
    container.invalidate(interfaceLangProvider);
    expect(container.read(interfaceLangProvider),
        AppLocalizations.supportedLocales.first.languageCode);
  });

  testWidgets('карта дожидается имён и ни в одном кадре не подписана слагами',
      (tester) async {
    // Мигание хуже слага: подпись, меняющаяся у игрока на глазах со
    // `place_time_price` на «Место, время, цена», читается как поломка
    // отрисовки. Поэтому экран ждёт имена вместе с небом, а не показывает
    // карту раньше них.
    //
    // Проверяется это в два хода, и оба нужны. Первый: пока имён нет, карты
    // нет вовсе — то есть подписывать ещё нечего, и `findsNothing` на слаге
    // не может пройти «потому что на экране пусто». Второй: имена приходят,
    // и подпись появляется — иначе «ждёт имена» ничем не отличалось бы от
    // «ждёт вечно», а именно так тест и был написан: подменённый future не
    // завершался никогда, и на индикаторе загрузки навсегда он согласился бы
    // с тем же успехом.
    final gate = Completer<ConstellationNaming>();
    final container = containerFor(uiLang: 'de', names: gate.future);

    final slug = await pumpSelected(tester, container);

    expect(find.byType(SkyMap), findsNothing,
        reason: 'карта показана до имён — значит, подписана слагами');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final german = await nameOf(tester, container, 'de', slug);
    // База ответила — тем же, чем ответила бы настоящему провайдеру.
    gate.complete(ConstellationNaming(
      interfaceNames: await namesIn(tester, container, 'de'),
      nativeNames: await namesIn(tester, container, 'uk'),
    ));

    // Кадры до подписи считаются по одному: слаг, мигнувший в любом из них,
    // и есть та поломка отрисовки, от которой экран ждёт. Кадров с запасом —
    // ответ провайдера доезжает за один-два, а не за десять.
    for (var frame = 0; frame < 10 && !tester.any(find.text(german)); frame++) {
      expect(find.text(slug), findsNothing,
          reason: 'кадр $frame подписан слагом');
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text(german), findsOneWidget,
        reason: 'экран не дождался имён — индикатор навсегда');
    expect(find.text(slug), findsNothing);
    expect(find.byType(SkyMap), findsOneWidget);
  });
}
