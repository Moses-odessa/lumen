import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_provider.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/data/repositories/player_repository.dart';
import 'package:lumen/data/repositories/word_state_repository.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/sky/application/sky_controller.dart';

/// Небо на настоящем ассете `content.db` и настоящей схеме `user.db`.
///
/// Два числа в подвале карты соврали одновременно и по разным причинам.
/// Поймать это можно было только здесь, где сходятся обе базы и запись
/// игрока: по отдельности каждый слой работал как написан.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase db;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_sky');
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

  /// Контейнер с игроком на заданном ярусе.
  ProviderContainer containerFor(Tier tier) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    container.read(playerControllerProvider.notifier).replace(
          Player(
            targetLang: 'de',
            nativeLang: 'uk',
            tier: tier,
            calibrated: true,
          ),
        );
    return container;
  }

  test('пока потолок не прочитан, разрешён только нижний ярус', () async {
    // Провайдер потолка раньше отвечал «ничего не запрещаю», пока
    // метаданные контента не прочитаны. Для интерфейса это верно — мигающий
    // запрет хуже запоздавшего, — а для решения, которое записывается в базу
    // игрока, нет: калибровка читала потолок ровно один раз, в конце теста, и
    // этим первым чтением сама же инициализировала futures. То есть на первом
    // запуске ограничение не срабатывало никогда, и измеренный B2 доставался
    // игроку насовсем на сборке с одним запущенным A0.
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // Метаданные, которые не отвечают никогда: ровно то состояние, в
      // котором провайдер и читался.
      launchedTiersProvider.overrideWith((ref) => Completer<Set<Tier>>().future),
    ]);
    addTearDown(container.dispose);

    expect(container.read(maxTierProvider), Tier.a0);
    expect(Tier.b2.atMost(container.read(maxTierProvider)), Tier.a0);
  });

  test('прочитанный потолок берётся из метаданных ассета', () async {
    final container = containerFor(Tier.a0);
    await container.read(launchedTiersProvider.future);

    expect(container.read(maxTierProvider), Tier.a0);
  });

  test('ярус урезается до запущенного, даже если в записи он выше', () async {
    // В ассете `launched_tiers` = a0, и это единственный ярус, который даёт
    // играть загрузчик сессии. Небо же брало ярус из записи игрока как есть:
    // бейдж показывал «B2», `conceptsUpTo` отдавал концепты всех пяти ярусов,
    // а состав созвездия раздувался с 12 слов до 96 — и по этим 96 считались
    // `isLit` (80 % ярче 70 lm) и открытие соседей, то есть небо зажигалось
    // примерно в восемь раз труднее, чем задумано.
    final wide = await containerFor(Tier.b2).read(skySnapshotProvider.future);
    final narrow = await containerFor(Tier.a0).read(skySnapshotProvider.future);

    expect(wide.tier, Tier.a0, reason: 'незапущенный ярус дошёл до неба');
    expect(wide.totalStars, narrow.totalStars);
    expect(wide.totalStars, lessThan(864),
        reason: 'на небе весь курс, а не запущенный ярус');
  });

  test('засеянные калибровкой звёзды считаются светящими', () async {
    // Жалоба с устройства: «на экране горят 3 звезды, но количество написано
    // 0». Картинку рисовала живая яркость из тройки FSRS, а цифру брал
    // запрос по флагу `burning` — достижению за три быстрых верных ответа
    // подряд в продуктивной механике. Засев калибровки его не ставит вовсе,
    // так что сразу после онбординга ноль был неизбежен, что бы игрок ни
    // ответил.
    final container = containerFor(Tier.a0);
    final content = container.read(currentContentDatabaseProvider);
    final ids = (await content.conceptsUpTo(Tier.a0))
        .take(3)
        .map((c) => c.id)
        .toList();
    expect(ids, hasLength(3));

    await WordStateRepository(db).seed(
      confirmed: {for (final id in ids) id: Tier.a0},
      lumens: 55,
      now: DateTime.now(),
    );

    final snapshot = await container.read(skySnapshotProvider.future);

    expect(snapshot.litStars, 3);
    expect(await db.countBurning(), 0,
        reason: 'флаг «горящего слова» засев не ставит — на нём и держался ноль');
  });

  test('забытая звезда светящей не считается', () async {
    // Порог — выход из полосы «практически забыто, вернётся как новое». Ниже
    // него звезда на карте самая тусклая, и назвать её светящей было бы
    // ложью в другую сторону.
    final container = containerFor(Tier.a0);
    final content = container.read(currentContentDatabaseProvider);
    final ids = (await content.conceptsUpTo(Tier.a0))
        .take(2)
        .map((c) => c.id)
        .toList();

    final words = WordStateRepository(db);
    final now = DateTime.now();
    await words.seed(confirmed: {ids.first: Tier.a0}, lumens: 55, now: now);
    // Второе слово подтверждено два месяца назад и с тех пор не повторялось:
    // яркость считается живой, из тройки FSRS, а не берётся из кеша — карту
    // могут открыть и через неделю простоя.
    await words.seed(
      confirmed: {ids[1]: Tier.a0},
      lumens: 55,
      now: now.subtract(const Duration(days: 60)),
    );

    final snapshot = await container.read(skySnapshotProvider.future);

    expect(snapshot.litStars, 1);
  });
}
