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
import 'package:lumen/features/profile/application/stats_controller.dart';
import 'package:lumen/features/profile/presentation/profile_screen.dart';

/// Имя созвездия в строке яркости профиля.
///
/// Профиль — второе из трёх мест, где созвездие называется игроку, и проверять
/// здесь нужно не правило показа (оно проверено на голых картах в
/// `test/data/constellation_naming_test.dart` и на пути до неба в
/// `sky_naming_test.dart`), а две вещи, которые именно на этом экране могли
/// сломаться по-своему:
///
/// * имя доходит до строки — раньше стоял `place_time_price`, хотя все 250 имён
///   лежали в базе;
/// * доходит **тем же** откатом, а не своим. Подстановка сделана на экране, и
///   соблазн написать `names[uiLang] ?? slug` на месте был ровно здесь, поэтому
///   ветка «интерфейса без имён» проверяется и в профиле: она отличит вызов
///   `ConstellationNaming.nameOf` от выражения, похожего на него.
///
/// Локаль `MaterialApp` этот файл, как и `sky_naming_test.dart`, подаёт себе
/// сам — то есть заменяет `main.dart`, а не проверяет его; связку в самом
/// `main.dart` охраняет `interface_locale_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase db;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_profile_naming');
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
  /// База игрока пустая, то есть все яркости нулевые. Для подписи это неважно:
  /// состав строк профиль берёт из контента (`phrasesUpTo`), а не из журнала
  /// ответов, поэтому строки есть и у игрока, который ещё не играл.
  ///
  /// `names` подменяет собранное именование своим future — тем, ответа
  /// которого экран ждёт вместе со статистикой. Отдаётся future, а не готовое
  /// значение: завершить его должен тест, иначе «ждёт имена» не отличить от
  /// «ждёт вечно».
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

  /// Профиль на экране; возвращает ту же статистику, которую он показывает.
  ///
  /// Слаги берутся из неё, а не выписываются в тест: состав яруса меняется
  /// файлами контента, и вписанный здесь список тем устарел бы молча.
  Future<PlayerStats> pumpProfile(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    // Список яркости лежит в конце длинного `ListView`, а `ListView` строит
    // только видимое: на обычном тестовом окне 800×600 строк тем просто не
    // существует, и `findsNothing` означал бы «не дошли до них», а не
    // «подписаны неправильно». Высокое окно вместо прокрутки — потому что
    // прокрутка добавила бы в тест собственные кадры и таймеры, а проверяется
    // здесь подпись, а не раскладка. Пять тем яруса A0 в 2000dp влезают
    // целиком — а если однажды не влезут, тест не соврёт, а упадёт.
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Настоящий ввод-вывод в виджет-тесте живёт только внутри `runAsync`:
    // обычный `await` в `testWidgets` идёт по фальшивым таймерам и не
    // заканчивается никогда, а контентная база — это копирование ассета в файл
    // и чтение с диска (то же записано в `sky_naming_test.dart`).
    final stats = await tester.runAsync(() async {
      final value = await container.read(playerStatsProvider.future);
      await container.read(launchedTiersProvider.future);
      return value;
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // Локаль интерфейса — из того же провайдера, что и имена: иначе
          // тест проверял бы подпись в отрыве от языка, на котором игрок
          // читает всё остальное на этом экране. Своей рукой поданная, она
          // заменяет `main.dart`, а не проверяет его (см. докстроку файла).
          locale: Locale(container.read(interfaceLangProvider)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileScreen(),
        ),
      ),
    );
    // Одного кадра хватает: статистика прочитана выше, а имена — запрос к уже
    // открытой базе, то есть цепочка микрозадач, которую этот `pump` и
    // разворачивает. `pumpAndSettle` нельзя: на экране с индикатором загрузки
    // он не заканчивается никогда, а именно им держится последний тест файла.
    await tester.pump();

    return stats!;
  }

  /// Имена тем на одном языке — из ассета, а не из констант в тесте.
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

  testWidgets('строка яркости подписана именем темы, а не слагом',
      (tester) async {
    final container = containerFor(uiLang: 'de');

    final stats = await pumpProfile(tester, container);
    final german = await namesIn(tester, container, 'de');

    expect(stats.constellations, isNotEmpty,
        reason: 'на ярусе A0 есть темы — иначе проверять нечего');

    // Проверяются все строки, а не первая: подпись собирается в одном месте,
    // но «в одном месте» — это утверждение о коде, а не о данных. Тема без
    // имени показалась бы слагом только в своей строке.
    for (final row in stats.constellations) {
      final name = german[row.constellation];
      expect(name, isNotNull,
          reason: 'у темы ${row.constellation} нет немецкого имени');
      expect(find.text(name!), findsOneWidget);
      expect(find.text(row.constellation), findsNothing,
          reason: 'slug — идентичность темы, а не подпись');
    }
  });

  testWidgets('интерфейс без имён откатывается на язык подсказок',
      (tester) async {
    // Так живёт француз: интерфейсов шесть, а имён пять языков — французского
    // контента нет вовсе. Профиль обязан откатиться туда же, куда небо, и
    // проверка стоит здесь второй раз именно потому, что подстановка на экране:
    // выражение `names[uiLang] ?? slug`, написанное на месте, прошло бы тест
    // выше и упало бы на этом.
    final container = containerFor(uiLang: 'fr');

    final stats = await pumpProfile(tester, container);
    final ukrainian = await namesIn(tester, container, 'uk');
    final german = await namesIn(tester, container, 'de');
    final row = stats.constellations.first;

    expect(find.text(ukrainian[row.constellation]!), findsOneWidget);
    expect(find.text(row.constellation), findsNothing);
    expect(find.text(german[row.constellation]!), findsNothing,
        reason: 'язык изучения — не язык подсказок и не язык интерфейса');

    final naming = await tester
        .runAsync(() => container.read(constellationNamingProvider.future));
    expect(naming?.interfaceNames, isEmpty,
        reason: 'французских имён в базе нет — иначе тест проверяет не откат');
  });

  testWidgets('список яркости дожидается имён и ни в одном кадре не в слагах',
      (tester) async {
    // Статистика могла бы показаться раньше имён: это два разных запроса.
    // Тогда игрок увидел бы, как подписи меняются со `place_time_price` на
    // «Ort, Zeit und Preis», — а это читается как поломка отрисовки, тогда как
    // слаг читается всего лишь как непереведённая тема. Поэтому экран ждёт
    // оба ответа одним ожиданием.
    //
    // Ожидание проверяется с двух сторон. Пока имён нет, списка нет вовсе —
    // иначе `findsNothing` на слагах прошёл бы и у экрана, который список не
    // показывает никогда. А потом имена приходят, и подписи появляются: без
    // этой половины тест согласился бы с экраном, который ждёт вечно, — и
    // соглашался, потому что подменённый future не завершался никогда.
    final gate = Completer<ConstellationNaming>();
    final container = containerFor(uiLang: 'de', names: gate.future);

    final stats = await pumpProfile(tester, container);
    final slugs = [for (final row in stats.constellations) row.constellation];
    expect(slugs, isNotEmpty, reason: 'на ярусе A0 есть темы — иначе нечего');

    expect(find.byType(ListView), findsNothing,
        reason: 'список показан до имён — значит, подписан слагами');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final german = await namesIn(tester, container, 'de');
    // База ответила — тем же, чем ответила бы настоящему провайдеру.
    gate.complete(ConstellationNaming(
      interfaceNames: german,
      nativeNames: await namesIn(tester, container, 'uk'),
    ));

    // Кадры до подписи считаются по одному: слаг, мигнувший в любом из них, и
    // есть та поломка отрисовки, из-за которой экран ждёт. Кадров с запасом —
    // ответ провайдера доезжает за один-два.
    final first = german[slugs.first]!;
    for (var frame = 0; frame < 10 && !tester.any(find.text(first)); frame++) {
      for (final slug in slugs) {
        expect(find.text(slug), findsNothing,
            reason: 'кадр $frame подписан слагом $slug');
      }
      await tester.pump(const Duration(milliseconds: 16));
    }

    for (final slug in slugs) {
      expect(find.text(german[slug]!), findsOneWidget,
          reason: 'экран не дождался имени темы $slug');
      expect(find.text(slug), findsNothing);
    }
  });
}
