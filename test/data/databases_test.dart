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
      // сделать внутри миграции: она не видит content.db.
      expect(db.schemaVersion, 6);
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
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'ru', tier: Tier.a0),
      );
      await db.wipe();
      expect(await db.loadPlayer(), isNull);
    });

    group('чистка памяти без контента', () {
      // Единственная проверенная тестом миграционная работа в проекте. До
      // неё ни одна ветка `from < N` не была прогнана ни разу: тест создавал
      // свежую базу и проверял `onCreate`.

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
      expect(meta['schema_version'], '${db.schemaVersion}');
      // Метки времени в метаданных нет намеренно: сборка воспроизводима.
      expect(meta.containsKey('built_at'), isFalse);
      expect(meta['source_hash'], isNotEmpty);
      // Запущен только вычитанный ярус: играть по черновому контенту нельзя.
      expect(await db.launchedTiers(), {Tier.a0});

      // Созвездие «У врача» написано целиком на всех пяти ярусах. Точных
      // размеров тест не требует: правило «ровно 12/24/48/72/96» удалено —
      // на словнике из 6000 лемм его провалили бы десять тем из двадцати
      // четырёх (PLAN.md, решение 3).
      //
      // Проверяется то, что осталось правдой и после смены правила: выборка
      // накопительная — ярус добавляет звёзды, а не заменяет их.
      expect(await db.countPhrases(), greaterThan(0));

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
      // двадцати фраз, и на своём ярусе она видна с первого дня. Прежний
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
      // читает игрок, и одна недособранная строка из 432 — это один экран, на
      // котором видно внутренности сборки.
      final phrases = await db.phrasesUpTo(Tier.b2);
      expect(phrases, hasLength(await db.countPhrases()));
      expect(phrases.map((p) => p.lang).toSet(), {'de'},
          reason: 'база собирается под один язык изучения');

      // Подстановка ответа в шаблон сделана сборкой, один раз. У фразы нет ни
      // пропусков, ни скрытых частей: `{bread}` в отгруженном тексте игрок
      // увидел бы на экране, а «…» — след того, что ответов было меньше, чем
      // пропусков, — ещё и услышал бы в синтезе.
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
