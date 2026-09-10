import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/prompt_tag.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/sky/progression.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../../tool/content_sources.dart';

/// Критерий приёмки M0: обе базы открываются. Проверяется на настоящем
/// ассете `assets/content/de.db` и на настоящей Drift-схеме `user.db`, а не
/// на моках — иначе проверка ничего не значит.
///
/// ── Что удалено вместе со словарным слоем ─────────────────────────────────
///
/// Контентная база v5 несёт пять таблиц, и слова среди них нет. Две проверки
/// удалены, а не переписаны на фразы:
///
/// * «черновых концептов в отгруженной базе нет» — охраняла пометку
///   `draft: true` и метаданное `drafted_concepts`: сборка обязана была
///   уважать её так же, как валидатор, иначе черновик из импортированного
///   словника уезжал игроку. У фразы такой пометки нет ни одной — фразы
///   пишутся руками, по одной, и их готовность объявляется ярусом в
///   `content/launch.yaml`, а не полем у каждой строки. Ни фильтра, ни
///   метаданного в сборке больше нет, охранять нечего.
/// * «лексемы и дистракторы читаются на всех языках проекта» — охраняла то,
///   что круг собирается из написанных руками неверных вариантов, а не из
///   случайных слов. Вариантов больше не пишут: вокруг новой фразы лежат пять
///   уже известных игроку. Половина проверки — «у единицы изучения есть форма
///   на языке подсказок» — перенесена на переводы фраз, см. «перевод есть у
///   каждой фразы»; туда же перенесена и проверка «концепт играбелен только
///   при форме в обоих языках пары»: `playableConcepts` удалён, а её вторая
///   половина — «неполнота означает меньше слов, а не падение» — жива.
///
/// Проверка «у фразы есть ответы по слотам и перевод на родной» не удалена, а
/// перенесена: таблицы `phrase_slots` больше нет, потому что пропуск перестал
/// быть механикой и стал формой записи в файле. Сборка подставляет ответ один
/// раз, и в базу уезжает готовое предложение — это и проверяет «фраза приходит
/// готовой к показу».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('user.db', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('схема создаётся и игрок переживает запись-чтение', () async {
      // Версия растёт вместе с миграциями: v2 добавила затмения и
      // напоминания (M5), v3 убрала таблицу ночного вызова вместе с самой
      // фичей, v4 сделала фразы такой же единицей памяти, как слова,
      // v5 добавила аркадные заходы к сессиям, v6 — таблицу отложенного
      // обслуживания, потому что чистку памяти о пропавшем контенте нельзя
      // сделать внутри миграции: она не видит content.db, v7 унесла
      // `custom_concepts` вместе с экраном «Свои слова».
      expect(db.schemaVersion, 7);
      expect(await db.loadPlayer(), isNull);

      await db.savePlayer(Player(
        targetLang: 'de',
        nativeLang: 'uk',
        uiLang: 'en',
        tier: Tier.b1,
        calibrated: true,
        orbit: 4,
        sparks: 120,
        soundEnabled: false,
        notificationsEnabled: true,
        preferredHour: 21,
        eclipseUntil: DateTime.utc(2026, 6, 1),
      ));

      final loaded = await db.loadPlayer();
      expect(loaded, isNotNull);
      expect(loaded!.targetLang, 'de');
      expect(loaded.nativeLang, 'uk');
      // Язык интерфейса — отдельная настройка от родного языка.
      expect(loaded.uiLang, 'en');
      expect(loaded.tier, Tier.b1);
      expect(loaded.calibrated, isTrue);
      expect(loaded.orbit, 4);
      expect(loaded.sparks, 120);
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.notificationsEnabled, isTrue);
      expect(loaded.preferredHour, 21);
      // Drift хранит дату как unix-секунды и отдаёт её в локальной зоне:
      // момент тот же, флаг UTC — нет. Сравнивать надо моменты.
      expect(
        loaded.eclipseUntil!.isAtSameMomentAs(DateTime.utc(2026, 6, 1)),
        isTrue,
      );
    });

    test('игрок — всегда одна строка', () async {
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'ru', tier: Tier.a0),
      );
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'en', tier: Tier.a2),
      );

      final rows = await db.select(db.players).get();
      expect(rows.length, 1);
      expect(rows.single.nativeLang, 'en');
    });

    test('wipe удаляет данные полностью', () async {
      // «Полностью» — это пять таблиц: `custom_concepts` из списка ушла не
      // потому, что её забыли, а потому, что её больше нет (миграция v7).
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'ru', tier: Tier.a0),
      );
      await db.recordReview(
        state: WordStatesCompanion.insert(
          itemId: 'food_a0_bread',
          tier: 'a0',
          difficulty: 5,
          stability: 1,
        ),
        review: ReviewsCompanion.insert(
          itemId: 'food_a0_bread',
          at: DateTime(2026, 9, 9),
          latencyMs: 900,
          mode: 'pickTarget',
          correct: true,
          grade: 3,
        ),
      );
      await db.saveSession(SessionsCompanion.insert(
        startedAt: DateTime(2026, 9, 9),
        durationMs: 60000,
        lmGained: 5,
        score: 50,
        newWords: 0,
      ));
      await db.into(db.constellationProgress).insertOnConflictUpdate(
            ConstellationProgressCompanion.insert(
              constellation: 'food',
              tier: 'a0',
            ),
          );

      await db.wipe();

      expect(await db.loadPlayer(), isNull);
      expect(await db.loadWordStates(), isEmpty);
      expect(await db.recentReviews(), isEmpty);
      expect(await db.loadSessions(), isEmpty);
      expect(await db.select(db.constellationProgress).get(), isEmpty);
    });

    group('чистка памяти без контента', () {
      // Работа, которую попросила миграция v6, но выполняет уже приложение:
      // `user.db` не видно `content.db`. Саму ветку `from < 6` этот тест не
      // прогоняет — он создаёт свежую базу; по настоящей старой базе
      // проходит только «миграция user.db v6 → v7» ниже.

      Future<void> seed(String itemId) => db.recordReview(
            state: WordStatesCompanion.insert(
              itemId: itemId,
              tier: 'a0',
              difficulty: 5,
              stability: 1,
            ),
            review: ReviewsCompanion.insert(
              itemId: itemId,
              at: DateTime(2026, 9, 9),
              latencyMs: 900,
              mode: 'pickTarget',
              correct: true,
              grade: 3,
            ),
          );

      test('убирает только то, чего в контенте нет', () async {
        // Идентификаторы разговорника и словарной эпохи рядом — ровно то, что
        // лежит в базе игрока, который начал играть до переезда контента:
        // `bread_food` был концептом, и в контенте его больше нет ни в каком
        // виде.
        await seed('food_a0_bread');
        await seed('bread_food');

        final removed = await db.sweepUnknownItems({'food_a0_bread'});

        expect(removed, 1);
        expect(await db.loadWordState('food_a0_bread'), isNotNull);
        expect(await db.loadWordState('bread_food'), isNull);
        // Журнал ответов чистится вместе с памятью: строки о единице, которой
        // нет, не годятся ни для дообучения FSRS, ни для статистики.
        final reviews = await db.recentReviews();
        expect(reviews.map((r) => r.itemId), isNot(contains('bread_food')));
      });

      test('принадлежность решает контент, а не колонка kind', () async {
        // `word_states.kind` никто не пишет: все строки лежат со значением по
        // умолчанию `word`, включая те, чей itemId — идентификатор фразы. А
        // фраза сегодня единственная единица памяти, какая бывает. Значит,
        // судить по типу нельзя вдвойне: фильтр `kind = 'phrase'` не оставил
        // бы от памяти игрока ни строки.
        await seed('food_a0_bread');
        expect((await db.loadWordState('food_a0_bread'))!.kind, 'word');

        expect(await db.sweepUnknownItems({'food_a0_bread'}), 0);
        expect(await db.loadWordState('food_a0_bread'), isNotNull);
      });

      test('пустой список известных не сносит прогресс', () async {
        // Пустой список означает, что контентная база не открылась, а не что
        // контент опустел. Снести всю память игрока из-за неудачного чтения
        // ассета — цена, несопоставимая с задачей.
        await seed('food_a0_bread');
        expect(await db.sweepUnknownItems(const {}), 0);
        expect(await db.loadWordState('food_a0_bread'), isNotNull);
      });

      test('метка обслуживания снимается после чистки', () async {
        await db.into(db.maintenance).insertOnConflictUpdate(
              MaintenanceCompanion.insert(key: pendingItemSweep, value: 'v6'),
            );
        expect(await db.needsItemSweep(), isTrue);

        await db.sweepUnknownItems({'food_a0_bread'});
        expect(await db.needsItemSweep(), isFalse);
      });

      test('свежая база чистки не ждёт', () async {
        // Метку кладёт только миграция с версии ниже шестой. У игрока,
        // который начал играть после переезда контента, чистить нечего.
        expect(await db.needsItemSweep(), isFalse);
      });
    });

    group('время и дни', () {
      test('дни подряд считаются от сегодня или от вчера', () async {
        // Вчера тоже считается началом: серия не должна обрываться в
        // полночь у человека, который просто ещё не садился за игру.
        final now = DateTime(2026, 9, 9, 14);

        Future<void> played(DateTime at) => db.saveSession(
              SessionsCompanion.insert(
                startedAt: at,
                durationMs: 300000,
                lmGained: 10,
                score: 100,
                newWords: 0,
              ),
            );

        // Три дня подряд, кончая вчерашним, плюс разрыв и старый день.
        await played(DateTime(2026, 9, 8, 10));
        await played(DateTime(2026, 9, 7, 10));
        await played(DateTime(2026, 9, 6, 10));
        await played(DateTime(2026, 9, 3, 10));

        final time = await db.loadPlayTime(now);
        expect(time.streak, 3, reason: 'разрыв не оборвал серию');
        expect(time.days, 4);
        expect(time.sessions, 4);
        expect(time.total, const Duration(minutes: 20));
      });

      test('две сессии в один день — это один день', () async {
        final now = DateTime(2026, 9, 9, 20);
        for (final hour in [9, 14]) {
          await db.saveSession(SessionsCompanion.insert(
            startedAt: DateTime(2026, 9, 9, hour),
            durationMs: 60000,
            lmGained: 5,
            score: 50,
            newWords: 0,
          ));
        }

        final time = await db.loadPlayTime(now);
        expect(time.days, 1);
        expect(time.sessions, 2);
        expect(time.streak, 1);
        expect(time.perDay, const Duration(minutes: 2));
      });

      test('давняя игра серии не даёт', () async {
        await db.saveSession(SessionsCompanion.insert(
          startedAt: DateTime(2026, 8, 1),
          durationMs: 60000,
          lmGained: 5,
          score: 50,
          newWords: 0,
        ));

        final time = await db.loadPlayTime(DateTime(2026, 9, 9));
        expect(time.streak, 0);
        expect(time.days, 1);
      });

      test('пустая история — пустые итоги', () async {
        final time = await db.loadPlayTime(DateTime(2026, 9, 9));
        expect(time.isEmpty, isTrue);
        expect(time.streak, 0);
        expect(time.total, Duration.zero);
      });

    });
  });

  group('миграция user.db v6 → v7', () {
    // Проверяется то, что делает игрок: ставит обновление на базу, которая у
    // него уже лежит. Свежая база этой ветки миграции не касается вовсе —
    // `onCreate` создаёт схему v7 сразу, и `custom_concepts` в ней нет,
    // поэтому «удаление таблицы» на пустой базе выглядит зелёным, ничего не
    // удалив.
    late raw.Database source;
    late AppDatabase db;

    /// База по схеме v6 с данными игрока, открытая приложением, — то есть
    /// первый запуск после обновления.
    ///
    /// DDL списан с `sqlite_master` базы, созданной прежним `onCreate`, а не
    /// написан по памяти: расхождение здесь превратило бы проверку миграции в
    /// проверку выдуманной схемы. `sqlite_sequence` в списке нет намеренно —
    /// SQLite создаёт её сам под `AUTOINCREMENT`.
    void openV6() {
      source = raw.sqlite3.openInMemory();
      for (final ddl in const [
        'CREATE TABLE "players" ("id" INTEGER NOT NULL DEFAULT 1, '
            '"target_lang" TEXT NOT NULL, "native_lang" TEXT NOT NULL, '
            '"ui_lang" TEXT NULL, "tier" TEXT NOT NULL, '
            '"calibrated" INTEGER NOT NULL DEFAULT 0 '
            'CHECK ("calibrated" IN (0, 1)), '
            '"orbit" INTEGER NOT NULL DEFAULT 0, '
            '"sparks" INTEGER NOT NULL DEFAULT 0, '
            '"last_played_at" INTEGER NULL, '
            '"missed_in_row" INTEGER NOT NULL DEFAULT 0, '
            '"free_pace" INTEGER NOT NULL DEFAULT 0 '
            'CHECK ("free_pace" IN (0, 1)), '
            '"sound_enabled" INTEGER NOT NULL DEFAULT 1 '
            'CHECK ("sound_enabled" IN (0, 1)), '
            '"eclipse_until" INTEGER NULL, "preferred_hour" INTEGER NULL, '
            '"notifications_enabled" INTEGER NOT NULL DEFAULT 0 '
            'CHECK ("notifications_enabled" IN (0, 1)), PRIMARY KEY ("id"))',
        'CREATE TABLE "word_states" ("item_id" TEXT NOT NULL, '
            '"kind" TEXT NOT NULL DEFAULT \'word\', "tier" TEXT NOT NULL, '
            '"difficulty" REAL NOT NULL, "stability" REAL NOT NULL, '
            '"last_review" INTEGER NULL, "due" INTEGER NULL, '
            '"lm_cached" INTEGER NOT NULL DEFAULT 0, '
            '"fast_streak" INTEGER NOT NULL DEFAULT 0, '
            '"burning" INTEGER NOT NULL DEFAULT 0 '
            'CHECK ("burning" IN (0, 1)), '
            '"reps" INTEGER NOT NULL DEFAULT 0, '
            '"lapses" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("item_id"))',
        'CREATE TABLE "reviews" ('
            '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            '"item_id" TEXT NOT NULL, "at" INTEGER NOT NULL, '
            '"latency_ms" INTEGER NOT NULL, "mode" TEXT NOT NULL, '
            '"correct" INTEGER NOT NULL CHECK ("correct" IN (0, 1)), '
            '"grade" INTEGER NOT NULL)',
        'CREATE TABLE "constellation_progress" ('
            '"constellation" TEXT NOT NULL, "tier" TEXT NOT NULL, '
            '"unlocked" INTEGER NOT NULL DEFAULT 0 '
            'CHECK ("unlocked" IN (0, 1)), '
            '"lit" INTEGER NOT NULL DEFAULT 0 CHECK ("lit" IN (0, 1)), '
            '"levels_done" INTEGER NOT NULL DEFAULT 0, '
            'PRIMARY KEY ("constellation", "tier"))',
        'CREATE TABLE "sessions" ('
            '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            '"started_at" INTEGER NOT NULL, "duration_ms" INTEGER NOT NULL, '
            '"lm_gained" INTEGER NOT NULL, "score" INTEGER NOT NULL, '
            '"new_words" INTEGER NOT NULL, "climb_id" TEXT NULL, '
            '"climb_level" INTEGER NULL)',
        'CREATE TABLE "custom_concepts" ("id" TEXT NOT NULL, '
            '"target" TEXT NOT NULL, "native" TEXT NOT NULL, '
            '"deck" TEXT NOT NULL, PRIMARY KEY ("id"))',
        'CREATE TABLE "maintenance" ("key" TEXT NOT NULL, '
            '"value" TEXT NOT NULL, PRIMARY KEY ("key"))',
        'CREATE INDEX word_states_due_lm ON word_states (due, lm_cached)',
        'CREATE INDEX reviews_at ON reviews (at)',
      ]) {
        source.execute(ddl);
      }

      // Прогресс игрока, который обязан миграцию пережить, и две личные пары
      // в уносимой таблице: ровно то, что лежит на устройстве у автора.
      for (final statement in const [
        "INSERT INTO players (id, target_lang, native_lang, ui_lang, tier, "
            "calibrated, orbit, sparks) "
            "VALUES (1, 'de', 'uk', 'en', 'b1', 1, 4, 120)",
        "INSERT INTO word_states (item_id, tier, difficulty, stability, "
            "lm_cached, reps) VALUES ('food_a0_bread', 'a0', 5.0, 1.0, 42, 3)",
        "INSERT INTO reviews (item_id, at, latency_ms, mode, correct, grade) "
            "VALUES ('food_a0_bread', 1789171200, 900, 'pickTarget', 1, 3)",
        "INSERT INTO constellation_progress (constellation, tier, unlocked, "
            "levels_done) VALUES ('food', 'a0', 1, 2)",
        "INSERT INTO sessions (started_at, duration_ms, lm_gained, score, "
            "new_words) VALUES (1789171200, 300000, 10, 100, 0)",
        "INSERT INTO custom_concepts (id, target, native, deck) "
            "VALUES ('custom_arzt', 'Arzt', 'лікар', 'custom')",
        "INSERT INTO custom_concepts (id, target, native, deck) "
            "VALUES ('custom_rechnung', 'Rechnung', 'рахунок', 'custom')",
        "INSERT INTO maintenance (key, value) "
            "VALUES ('$pendingItemSweep', 'v6')",
      ]) {
        source.execute(statement);
      }

      // Без этого Drift решит, что база пустая, и вызовет `onCreate` вместо
      // `onUpgrade`.
      source.execute('PRAGMA user_version = 6');
      db = AppDatabase(NativeDatabase.opened(source));
    }

    setUp(openV6);
    tearDown(() async => db.close());

    test('таблица своих слов уносится вместе с фичей', () async {
      // Соединение Drift открывается лениво, и миграцию запускает первый
      // запрос, а не конструктор.
      expect(await db.loadPlayer(), isNotNull);

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(tables.map((r) => r.data['name']), isNot(contains('custom_concepts')),
          reason: 'таблица, которую никто не пишет и не читает, — это '
              'приглашение дописать фичу обратно');

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], 7);
    });

    test('прогресс игрока миграцию переживает', () async {
      // Резервной копии у игрока нет, и `user.db` — единственный экземпляр
      // данных: миграция обязана унести ровно одну таблицу, а не задеть
      // соседние.
      final player = await db.loadPlayer();
      expect(player!.targetLang, 'de');
      expect(player.tier, Tier.b1);
      expect(player.orbit, 4);
      expect(player.sparks, 120);

      final state = await db.loadWordState('food_a0_bread');
      expect(state, isNotNull);
      expect(state!.reps, 3);
      expect(state.lmCached, 42);

      expect((await db.recentReviews()).single.itemId, 'food_a0_bread');
      expect((await db.loadSessions()).single.score, 100);
      expect(
        (await db.select(db.constellationProgress).get()).single.levelsDone,
        2,
      );

      // Метка отложенного обслуживания не снимается: чистку памяти о
      // пропавшем контенте делает `sweepUnknownItems`, когда открыта
      // content.db, и удаление чужой таблицы к ней отношения не имеет.
      expect(await db.needsItemSweep(), isTrue);
    });
  });

  group('content.db', () {
    late Directory support;

    setUp(() {
      support = Directory.systemTemp.createTempSync('lumen_support');
      // path_provider — плагин, в тестах его канал надо подменить.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async =>
            call.method == 'getApplicationSupportDirectory'
                ? support.path
                : null,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      support.deleteSync(recursive: true);
    });

    test('ассет копируется в support-директорию и открывается', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final meta = await db.loadMeta();
      expect(meta['lang'], 'de');
      // Версия названа числом, а не только сверена с приложением: v7 — это
      // колонка `phrases.kind`, и сверка «ассет той же версии, что код»
      // прошла бы и на двух одинаково устаревших шестёрках.
      expect(db.schemaVersion, 7);
      expect(meta['schema_version'], '${db.schemaVersion}');
      // Метки времени в метаданных нет намеренно: сборка воспроизводима.
      expect(meta.containsKey('built_at'), isFalse);
      expect(meta['source_hash'], isNotEmpty);
      // Запущен только вычитанный ярус: играть по черновому контенту нельзя.
      expect(await db.launchedTiers(), {Tier.a0});

      // ── Размер корпуса назван числами, а не «больше нуля» ────────────────
      //
      // Раньше здесь стояло `greaterThan(0)`, и это была не лень, а сдача:
      // правило «ровно 12/24/48/72/96 звёзд» удалили, потому что на словнике
      // из 6000 лемм его провалили бы десять тем из двадцати четырёх (PLAN.md,
      // решение 3). Размер темы зависел от того, сколько слов нашлось, —
      // проверять было нечего.
      //
      // Разговорник вернул числу смысл: корпус не набирается, а приходит
      // готовым — один лист, 1500 строк, 50 тем ровно по 30 фраз (провенанс в
      // `content/_import/phrasebook_1500/source.json`). У правильности есть
      // цена: потерянная при импорте тема или строка выглядит как работающая
      // игра, и `greaterThan(0)` не заметит этого никогда.
      //
      // Числа сверены с базой, собранной из нынешних исходников, а не
      // выписаны из письма: 1500 строк, 50 файлов по 30 фраз. Если корпус
      // однажды потеряет строку законно — автор выбросит фразу, которую
      // отверг валидатор, — правду правят здесь, а не подгоняют сборку под
      // число.
      expect(await db.countPhrases(), 1500);
      expect(await db.countPhrasesUpTo(Tier.b2), 1500,
          reason: 'верхний ярус накопительно — это весь корпус');

      // По ярусам: 150/270/330/360/390 — то есть 5/9/11/12/13 тем по тридцать.
      // Числа неравные намеренно: наверху тем больше, потому что речь там
      // разнообразнее, а не потому что ярус длиннее.
      const perTier = {
        Tier.a0: 150,
        Tier.a1: 270,
        Tier.a2: 330,
        Tier.b1: 360,
        Tier.b2: 390,
      };
      for (final tier in Tier.values) {
        expect((await db.phrasesOn(tier)).length, perTier[tier],
            reason: 'ярус ${tier.label}');
      }

      // Пятьдесят тем, и каждая — блок ровно из тридцати фраз одного яруса.
      // Тема на одном ярусе — это устройство источника, а не совпадение:
      // «Построение аргумента» не бывает на A0, и слаг темы приходит из
      // одной строки `constellationSlugs`.
      final byConstellation = <String, List<PhraseRow>>{};
      for (final row in await db.phrasesUpTo(Tier.b2)) {
        byConstellation.putIfAbsent(row.constellation, () => []).add(row);
      }
      expect(byConstellation, hasLength(50));
      for (final entry in byConstellation.entries) {
        expect(entry.value, hasLength(30), reason: 'тема ${entry.key}');
        expect(entry.value.map((p) => p.tier).toSet(), hasLength(1),
            reason: 'тема ${entry.key} размазана по ярусам');
      }

      // Выборка накопительная: `phrasesFor` берёт ярус и всё, что ниже. На
      // настоящем ассете проверка мягкая — тема сидит на одном ярусе, и
      // «Первый контакт» отдаёт одни и те же тридцать фраз на всех пяти
      // запросах. Мягкая, но не пустая: она ловит `tier = upTo` вместо
      // `tier IN (...)`, то есть подъём, потерявший нижние ярусы. Накопление
      // по нескольким ярусам разом проверяет `content_schema_test` — на
      // синтетической базе, где тема нарочно написана на трёх ярусах.
      var previous = <String>{};
      for (final tier in Tier.values) {
        final ids =
            (await db.phrasesFor('first_contact', tier)).map((p) => p.id);
        expect(ids, containsAll(previous),
            reason: 'ярус ${tier.label}: фразы нижнего яруса выпали из выборки');
        expect(ids.length, greaterThanOrEqualTo(previous.length),
            reason: 'ярус ${tier.label}: созвездие сжалось');
        previous = ids.toSet();
      }

      // Порог появления тема берёт **сразу**: в разговорнике тема это блок из
      // тридцати фраз, и на своём ярусе она видна с первого дня. Прежний
      // контент этого не давал — у «У врача» на A0 было четыре фразы против
      // восьми нужных, то есть запущенный ярус оставался без созвездий вовсе.
      // Проверяется всё равно верхний ярус, а не A0: тема живёт на своём
      // ярусе, и требовать её присутствия на всех значило бы требовать, чтобы
      // «Построение аргумента» существовало на A0.
      expect(Progression.appears(previous.length), isTrue,
          reason: 'на B2 у созвездия ${previous.length} звёзд, порог '
              '${ProgressionBalance.minStarsForConstellation}');

      // Файл действительно лёг в support-директорию.
      expect(File('${support.path}/content/de.db').existsSync(), isTrue);
    });

    test('отгруженный ассет собран из нынешних исходников', () async {
      // Пересборка базы — ручной шаг в AGENT.md, а ручные шаги забывают.
      // Забытый выглядит как работающая игра со старым контентом: правка YAML
      // есть в git, а в установке её нет. Хуже того, вычитка читает
      // исходники — то есть проверяет текст, которого игрок не видит. Это
      // назвала слепым пятном сама вычитка: «я читал YAML, а не собранную
      // базу, и git показывает её изменённой».
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final meta = await db.loadMeta();
      final sources = ContentSources.load(Directory('content'));
      expect(meta['source_hash'], sources.hash,
          reason: 'assets/content/de.db собран не из этих исходников: '
              'dart run tool/build_content.dart --lang de');
    });

    test('перевод есть у каждой фразы, которую отгрузили', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      // Фраза без перевода — вопрос, который нельзя задать: `QuestionBuilder`
      // отдаёт на такой null, и круг не собирается ни как задание, ни как
      // вариант вокруг чужого задания. Раньше эту дыру закрывала проверка
      // «у концепта есть форма в обоих языках пары»; у фразы её место занял
      // перевод, и он обязан быть у всех отгруженных фраз, а не у большинства.
      final ids = await db.allPhraseIds();
      expect(ids, isNotEmpty);

      final uk = await db.translationsFor(ids, 'uk');
      expect(uk.keys, unorderedEquals(ids),
          reason: 'без перевода остались: ${ids.difference(uk.keys.toSet())}');
      expect(uk.values.where((t) => t.trim().isEmpty), isEmpty,
          reason: 'пустая строка перевода — та же фраза без перевода, только '
              'молча: круг соберётся с пустым вариантом');

      // Языка, которого в базе нет, переводов не даёт — и это не падение, а
      // пустая карта: неполнота означает меньше фраз в игре, а не сломанный
      // запуск.
      expect(await db.translationsFor(ids, 'ja'), isEmpty);
      expect(await db.translation(ids.first, 'ja'), isNull);
    });

    test('языки читаются из базы, а не из списка в коде', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final all = await db.allLanguages();
      expect(all.map((l) => l.code), containsAll(['de', 'uk', 'ru', 'en']));

      final de = all.firstWhere((l) => l.code == 'de');
      expect(de.role, 'target');
      expect(de.name, 'Deutsch');
      // Покрытие считается при сборке, а не объявляется в файле, и считается
      // оно по переводам: у языка изучения их нет — переводить фразу на её же
      // язык незачем, — а у языка подсказок их столько же, сколько фраз.
      expect(de.phrases, 0);
      expect(all.firstWhere((l) => l.code == 'uk').phrases,
          await db.countPhrases());

      // Языков подсказок четыре, и все запущены: разговорник пришёл одним
      // источником сразу на пять языков — украинский, немецкий, английский,
      // русский, итальянский, — и объявлять один из них черновым, а другой
      // готовым было бы неправдой. Немецкий среди них не значится: он язык
      // изучения.
      final natives = await db.nativeLanguages();
      expect(natives.map((l) => l.code), ['en', 'it', 'ru', 'uk']);
      expect((await db.targetLanguages()).map((l) => l.code), ['de']);
    });

    test('фраза приходит готовой к показу', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      // Смотрим на все отгруженные фразы, а не на выборку одной темы: текст
      // читает игрок, и одна недособранная строка из 1500 — это один экран, на
      // котором видно внутренности сборки.
      final phrases = await db.phrasesUpTo(Tier.b2);
      expect(phrases, hasLength(await db.countPhrases()));
      expect(phrases.map((p) => p.lang).toSet(), {'de'},
          reason: 'база собирается под один язык изучения');

      // У фразы нет ни пропусков, ни скрытых частей, и в одном фильтре здесь
      // сошлись две разные причины. `{bread}` — след подстановки в шаблон:
      // сборка делает её один раз, и незакрытая скобка уехала бы игроку прямо
      // на экран. «…» был следом того, что ответов оказалось меньше, чем
      // пропусков, а теперь это ещё и решение автора: 239 многоточий прежнего
      // корпуса убраны из источника руками, потому что «с ним не понятно как
      // читать» — фразу с многоточием нельзя ни прочитать, ни произнести
      // синтезом, а на месте шаблонов встали законченные примеры («Ich heiße
      // Alex.» вместо «Ich heiße ...»). В нынешнем источнике ноль и скобок, и
      // многоточий; фильтр остаётся, потому что смотрит он на отгруженное, а
      // не на источник.
      final unfinished = phrases.where(
          (p) => p.sentence.contains('{') || p.sentence.contains('…'));
      expect(unfinished.map((p) => p.id), isEmpty,
          reason: 'в базу уехал шаблон, а не готовая фраза');

      // Регистр — код из закрытого набора, а не строка на языке файла: текст
      // под центром круга даёт локализация на языке интерфейса. Свободный
      // текст показался бы игроку как есть — именно это и было под каждой из
      // 432 фраз, английским служебным словом.
      final registers = phrases.map((p) => p.register).whereType<String>();
      expect(registers, isNotEmpty);
      expect(registers.where((r) => !isPromptTag(r)).toSet(), isEmpty,
          reason: 'у приложения нет перевода для такой пометки');
    });

    test('вид фразы доезжает из базы, а не угадывается по тексту', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      // Колонка `kind` из v7. В игре у неё нет ни одного читателя, и это
      // записанное решение, а не недоделка (`content_database.dart`,
      // «Чтение фразы»): все три механики показывают фразу как есть. Читатель
      // один — проверка текста, и спрашивает она у **отгруженной** базы, а не
      // у YAML: прежняя вычитка читала исходники, то есть текст, которого
      // игрок не видит.
      //
      // Что охраняет проверка. Идиома по тексту не отличается от фразы ничем,
      // а перевод у неё смысловой: «Ich habe gerade viel um die Ohren» — это
      // «у мене зараз багато справ», ни одного общего слова. Потерянная
      // пометка означает не пустой экран, а тридцать законных находок
      // буквальности, которых на самом деле нет.
      final kinds =
          (await db.phrasesUpTo(Tier.b2)).map((p) => p.kind).toSet();
      expect(kinds, {'phrase', 'example', 'idiom'},
          reason: 'вид — закрытый набор кодов, и все три вида в корпусе есть: '
              '1231 фраза, 239 примеров, 30 идиом. Лишнее значение означает, '
              'что импорт перенёс пометку источника как есть («Фраза»), а '
              'пропавшее — что вид потерялся столбцом, а не решением автора');
    });

    test('повторное открытие не перезаписывает файл', () async {
      final first = ContentDatabase.forLanguage('de');
      await first.countPhrases();
      await first.close();

      final file = File('${support.path}/content/de.db');
      final stamp = file.lastModifiedSync();

      final second = ContentDatabase.forLanguage('de');
      addTearDown(second.close);
      expect(await second.countPhrases(), greaterThan(0));
      expect(file.lastModifiedSync(), stamp);
    });
  });
}
