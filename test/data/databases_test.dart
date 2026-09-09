import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/sky/progression.dart';

import '../../tool/content_sources.dart';

/// Критерий приёмки M0: обе базы открываются. Проверяется на настоящем
/// ассете `assets/content/de.db` и на настоящей Drift-схеме `user.db`, а не
/// на моках — иначе проверка ничего не значит.
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
        await seed('bread_food');
        await seed('gone_forever');

        final removed = await db.sweepUnknownItems({'bread_food'});

        expect(removed, 1);
        expect(await db.loadWordState('bread_food'), isNotNull);
        expect(await db.loadWordState('gone_forever'), isNull);
        // Журнал ответов чистится вместе с памятью: строки о слове, которого
        // нет, не годятся ни для дообучения FSRS, ни для статистики.
        final reviews = await db.recentReviews();
        expect(reviews.map((r) => r.itemId), isNot(contains('gone_forever')));
      });

      test('фраза — такая же единица памяти, как слово', () async {
        // `word_states.kind` никто не пишет: все строки лежат со значением по
        // умолчанию `word`, включая те, чей itemId — идентификатор фразы.
        // Поэтому принадлежность определяется членством в объединении
        // «концепты ∪ фразы», а не типом.
        await seed('food_a0_bread');
        expect(await db.sweepUnknownItems({'food_a0_bread'}), 0);
        expect(await db.loadWordState('food_a0_bread'), isNotNull);
      });

      test('пустой список известных не сносит прогресс', () async {
        // Пустой список означает, что контентная база не открылась, а не что
        // контент опустел. Снести всю память игрока из-за неудачного чтения
        // ассета — цена, несопоставимая с задачей.
        await seed('bread_food');
        expect(await db.sweepUnknownItems(const {}), 0);
        expect(await db.loadWordState('bread_food'), isNotNull);
      });

      test('метка обслуживания снимается после чистки', () async {
        await db.into(db.maintenance).insertOnConflictUpdate(
              MaintenanceCompanion.insert(key: pendingItemSweep, value: 'v6'),
            );
        expect(await db.needsItemSweep(), isTrue);

        await db.sweepUnknownItems({'bread_food'});
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
      // размеров тест больше не требует: правило «ровно 12/24/48/72/96»
      // удалено, потому что на словнике из 6000 лемм его провалили бы десять
      // тем из двадцати четырёх (PLAN.md, решение 3).
      //
      // Проверяется то, что осталось правдой и после смены правила: размер
      // накопительный — ярус добавляет звёзды, а не заменяет их, — и на
      // каждом ярусе созвездие набрало порог появления.
      expect(await db.countConcepts(), greaterThan(0));

      var previous = 0;
      for (final tier in Tier.values) {
        final count = (await db.conceptsFor('health', tier)).length;
        expect(count, greaterThanOrEqualTo(previous),
            reason: 'ярус ${tier.label}: созвездие сжалось');
        expect(Progression.appears(count), isTrue,
            reason: 'ярус ${tier.label}: $count звёзд, порог '
                '${ProgressionBalance.minStarsForConstellation}');
        previous = count;
      }

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

    test('черновых концептов в отгруженной базе нет', () async {
      // Пометка `draft: true` обещает «в игру не идёт», и до импорта словника
      // это обещание держал один валидатор: сборка отгружала черновик
      // наравне с вычитанным. Пока черновиков было ноль, проверить это было
      // нечем — и незаметно, что проверять нечего.
      //
      // Тест смотрит в исходники и в базу: id, помеченный черновым, не должен
      // существовать в отгруженном ассете ни как концепт, ни как лексема.
      final drafted = <String>{};
      for (final file in Directory('content/concepts')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))) {
        for (final line in file.readAsLinesSync()) {
          if (!line.contains('draft: true')) continue;
          final match = RegExp(r'id:\s*([A-Za-z0-9_]+)').firstMatch(line);
          if (match != null) drafted.add(match.group(1)!);
        }
      }

      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final meta = await db.loadMeta();
      expect(meta['drafted_concepts'], '${drafted.length}',
          reason: 'сборка не заметила часть черновиков');

      for (final id in drafted) {
        expect(await db.lexeme(id, 'de'), isNull,
            reason: 'черновой концепт $id уехал в базу');
      }
    });

    test('лексемы и дистракторы читаются на всех языках проекта', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final de = await db.lexeme('doctor_person', 'de');
      expect(de?.form, 'Arzt');
      expect(de?.article, 'der');

      for (final lang in ['ru', 'uk', 'en']) {
        final lexeme = await db.lexeme('doctor_person', lang);
        expect(lexeme, isNotNull, reason: 'нет лексемы на $lang');
      }

      // Круг собирается из дистракторов контента, а не случайных слов.
      final far = await db.distractorsFor('doctor_person', 'de', 'far');
      final near = await db.distractorsFor('doctor_person', 'de', 'near');
      expect(far.length, greaterThanOrEqualTo(2));
      expect(near.length, greaterThanOrEqualTo(3));
    });

    test('языки читаются из базы, а не из списка в коде', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final all = await db.allLanguages();
      expect(all.map((l) => l.code), containsAll(['de', 'uk', 'ru', 'en']));

      final de = all.firstWhere((l) => l.code == 'de');
      expect(de.role, 'target');
      expect(de.name, 'Deutsch');
      // Покрытие считается при сборке, а не объявляется в файле.
      expect(de.concepts, await db.countConcepts());

      // Русский и английский лежат как draft: проект несёт немецкий и
      // украинский. Значит, подсказывать предлагается только украинским.
      final natives = await db.nativeLanguages();
      expect(natives.map((l) => l.code), ['uk']);
      expect((await db.targetLanguages()).map((l) => l.code), ['de']);
    });

    test('концепт играбелен только при форме в обоих языках пары', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final pair = await db.playableConcepts(
        targetLang: 'de',
        nativeLang: 'uk',
        upTo: Tier.b2,
      );
      expect(pair.length, await db.countConcepts());

      // Языка, которого в базе нет, играбельных концептов не даёт — и это
      // не падение, а пустой список: неполнота означает меньше слов.
      final missing = await db.playableConcepts(
        targetLang: 'de',
        nativeLang: 'ja',
        upTo: Tier.b2,
      );
      expect(missing, isEmpty);
    });

    test('у фразы есть ответы по слотам и перевод на родной', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final phrases = await db.phrasesFor('food', Tier.a0, lang: 'de');
      expect(phrases, isNotEmpty);

      final phrase = phrases.first;
      final answers = await db.phraseAnswers(phrase.id);
      expect(answers, isNotEmpty);
      // Ответы приехали в отдельную таблицу: пропусков может быть несколько,
      // и порядок — это порядок слотов слева направо.
      expect(answers.length, RegExp(r'\{[^}]*\}')
          .allMatches(phrase.template)
          .length);

      // Перевод фразы целиком: он проявляется после заполнения пропусков.
      expect(await db.phraseTranslation(phrase.id, 'uk'), isNotNull);
    });

    test('повторное открытие не перезаписывает файл', () async {
      final first = ContentDatabase.forLanguage('de');
      await first.countConcepts();
      await first.close();

      final file = File('${support.path}/content/de.db');
      final stamp = file.lastModifiedSync();

      final second = ContentDatabase.forLanguage('de');
      addTearDown(second.close);
      expect(await second.countConcepts(), greaterThan(0));
      expect(file.lastModifiedSync(), stamp);
    });
  });
}
