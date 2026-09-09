import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/repositories/word_state_repository.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/features/game/application/question_builder.dart';
import 'package:lumen/features/game/application/session_loader.dart';

/// Сквозная проверка ядра: настоящий ассет `content.db`, настоящая
/// Drift-схема и настоящий планировщик. Именно здесь ловятся расхождения,
/// которых не видно ни в одном юнит-тесте по отдельности.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase userDb;
  late ContentDatabase content;
  late SessionLoader loader;

  final now = DateTime.utc(2026, 5, 1, 9);

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? support.path
          : null,
    );

    userDb = AppDatabase(NativeDatabase.memory());
    content = ContentDatabase.forLanguage('de');
    loader = SessionLoader(
      words: WordStateRepository(userDb),
      builder: QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'ru',
        random: Random(1),
      ),
      tier: Tier.a0,
      freePace: false,
      capabilities: const SessionCapabilities(),
      random: Random(1),
    );
  });

  tearDown(() async {
    await content.close();
    await userDb.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    support.deleteSync(recursive: true);
  });

  group('первый уровень', () {
    test('собирается из настоящего контента', () async {
      final session = await loader.level(now);

      expect(session.isEmpty, isFalse);
      // У нового игрока повторять нечего — только новые слова.
      expect(session.reviews, 0);
      expect(session.newWords, 6);
    });

    test('у каждого круга есть центр, варианты и верный ответ на каждый слот',
        () async {
      final session = await loader.level(now);

      // Раньше здесь стояла оговорка «кроме кругов набора»: у поля ввода
      // вариантов не было вовсе, и на таких кругах проверку приходилось
      // пропускать. Набора больше нет, и оговорка ушла вместе с ним —
      // вариант выбирается во всех шести механиках без исключений.
      for (final q in session.questions) {
        expect(q.itemId, isNotEmpty);
        expect(q.options, isNotEmpty, reason: '${q.itemId}: круг без вариантов');
        expect(q.slotCount, greaterThanOrEqualTo(1), reason: q.itemId);

        // Верный ответ нужен каждому слоту, а не кругу целиком: круг — это
        // фраза с одним слотом, и одного индекса хватало бы лишь на четыре
        // механики из шести.
        for (var slot = 0; slot < q.slotCount; slot++) {
          expect(q.answers[slot], inInclusiveRange(0, q.options.length - 1),
              reason: '${q.itemId}: слот $slot указывает вне пула');
          expect(q.answerFor(slot), isNotEmpty,
              reason: '${q.itemId}: слот $slot без текста');
          expect(q.isCorrectFor(slot, q.answers[slot]), isTrue,
              reason: '${q.itemId}: слот $slot не признаёт свой же ответ');
        }

        // Центр круга — текст, звук или пустые места. Пустой центр без звука
        // и без слотов означал бы круг без задания.
        if (q.prompt.isEmpty) {
          expect(q.mode.needsAudio || q.mode == GameMode.buildPhrase, isTrue,
              reason: '${q.itemId}: пустой центр в механике ${q.mode.name}');
          if (q.mode.needsAudio) {
            expect(q.promptSpeech, isNotNull, reason: q.itemId);
          }
        }

        // Инвариант README: концепт без озвучки не проходит валидацию,
        // значит и в игре у ответа всегда есть, что произнести.
        expect(q.answerSpeech, isNotNull, reason: q.itemId);
      }
    });

    test('вариантов ровно столько, сколько круг обещает игроку', () async {
      final session = await loader.level(now);

      for (final q in session.questions) {
        if (q.isNew) {
          // Знакомство — не проверка, а показ: выбирать не из чего.
          expect(q.options.length, SessionBalance.introductionOptions,
              reason: '${q.itemId}: знакомство с выбором');
          continue;
        }
        expect(q.options.length, greaterThanOrEqualTo(3),
            reason: '${q.itemId}: слишком мало вариантов');
        // Потолок держится только на круге со словом: в пуле фразы лежат
        // ответы всех пропусков сверх неверных слов, и шесть их не
        // ограничивают.
        if (q.mode.isWordMode) {
          expect(q.options.length, lessThanOrEqualTo(ScoreBalance.optionsMax),
              reason: '${q.itemId}: круг шире экрана');
        }
      }
    });

    test('варианты в круге не повторяются', () async {
      final session = await loader.level(now);

      // «Собери предложение» исключён намеренно: слово может повторяться в
      // самом предложении («Ich habe ... und ich ...»), и два одинаковых
      // слова в пуле там не поломка, а текст. Различает их номер слота —
      // ровно поэтому ответы хранятся индексами, а не формами.
      final choices =
          session.questions.where((q) => q.mode != GameMode.buildPhrase);
      for (final q in choices) {
        final lowered = q.options.map((o) => o.toLowerCase()).toList();
        expect(lowered.toSet().length, lowered.length,
            reason: '${q.itemId}: дубли среди вариантов');
      }
    });

    test('первый показ нового слова — понимание, центр на изучаемом', () async {
      final session = await loader.level(now);
      final first = session.questions.firstWhere((q) => q.isNew);

      expect(first.mode, GameMode.pickNative);
      // Понимание: в центре немецкий, вокруг русский.
      expect(first.prompt, isNotEmpty);
      final lexeme = await content.lexeme(first.itemId, 'de');
      expect(first.prompt, contains(lexeme!.form));
    });

    test('знакомство доходит до игрока даже без дистракторов', () async {
      final session = await loader.level(now);

      // Круг с одним вариантом стал законным, и это не мелочь: прежде
      // сборщик возвращал `null`, не набрав двух дистракторов, и знакомство
      // с редким словом молча исчезало из уровня. Проверяется поэтому не
      // форма круга, а доставка: все обещанные новые слова на месте.
      final introduced =
          session.questions.where((q) => q.isNew).map((q) => q.itemId).toSet();
      expect(introduced.length, session.newWords);

      for (final q in session.questions.where((q) => q.isNew)) {
        expect(q.options.length, 1, reason: q.itemId);
        expect(q.answerIndex, 0, reason: q.itemId);
        expect(q.isCorrectFor(0, 0), isTrue, reason: q.itemId);
        expect(q.isCorrectFor(0, 1), isFalse, reason: q.itemId);
      }
    });

    test('уровень закрывается фразовым забегом', () async {
      final session = await loader.level(now);
      final phrases = session.runs.last.questions;

      // Фраза — другой масштаб задачи, и мешать её со словами не стоит:
      // отдельный короткий забег в конце.
      expect(phrases, isNotEmpty);
      expect(phrases.every((q) => q.mode.isPhrase), isTrue,
          reason: 'в фразовом забеге оказалось слово');
      expect(
        session.runs
            .take(session.runs.length - 1)
            .expand((run) => run.questions)
            .every((q) => q.mode.isWordMode),
        isTrue,
        reason: 'фраза попала в забег со словами',
      );

      final modes = phrases.map((q) => q.mode).toList();
      expect(modes, contains(GameMode.fillGaps));
      // Порядок не случаен: сначала пропуски, потом сборка предложения из
      // слов. Сборка по памяти труднее, и ставить её первой значило бы
      // спрашивать то, чего игрок в этом уровне ещё не видел.
      if (modes.contains(GameMode.buildPhrase)) {
        expect(modes.indexOf(GameMode.fillGaps),
            lessThan(modes.indexOf(GameMode.buildPhrase)));
      }

      for (final q in phrases.where((q) => q.mode == GameMode.fillGaps)) {
        expect(q.prompt, contains('_____'));
        // В пуле обязаны быть ответы всех пропусков: игрок тянет каждое
        // слово к своему месту из одного набора сверху и снизу.
        for (var slot = 0; slot < q.slotCount; slot++) {
          expect(q.options, contains(q.answerFor(slot)));
        }
      }
    });

    test('собранная фраза совпадает с тем, что будет произнесено', () async {
      final session = await loader.level(now);

      for (final q in session.runs.last.questions) {
        // `assembled` — это то, что игрок услышит, закрыв последний слот.
        // Расхождение с озвучкой значит, что он услышит не ту фразу, которую
        // собрал.
        expect(q.assembled, q.answerSpeech, reason: q.itemId);
        expect(q.assembled, isNot(contains('_____')), reason: q.itemId);
      }
    });

    test('одно слово не идёт двумя кругами подряд', () async {
      final session = await loader.level(now);
      // Фразовый забег исключён: обе его механики стоят на одном материале,
      // и повтор опорного концепта там задуман, а не проспан планировщиком.
      // Прежний тест добивался того же, отбрасывая последний круг, — тогда
      // фраза была одна.
      final ids = session.questions
          .where((q) => q.mode.isWordMode)
          .map((q) => q.itemId)
          .toList();

      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]), reason: 'позиция $i');
      }
    });
  });

  group('многослотовая фраза', () {
    test('каждый слот знает только свой вариант', () async {
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'ru',
        random: Random(3),
      );
      // «Город» взят не наугад: все его фразы A0 длиннее порога
      // `buildPhraseMinWords`, поэтому слотов гарантированно несколько — на
      // одном слоте проверять различимость слотов было бы нечем.
      final question = await builder.buildPhrase(
        constellation: 'city',
        tier: Tier.a0,
        mode: GameMode.buildPhrase,
        lumens: 0,
      );

      expect(question, isNotNull);
      expect(question!.slotCount,
          greaterThanOrEqualTo(SessionBalance.buildPhraseMinWords));
      expect(question.isSingleSlot, isFalse);

      for (var slot = 0; slot < question.slotCount; slot++) {
        for (var option = 0; option < question.options.length; option++) {
          expect(question.isCorrectFor(slot, option),
              option == question.answers[slot],
              reason: 'слот $slot, вариант $option');
        }
      }

      // Слот вне шаблона не признаёт ничего: лишнее место на экране не
      // должно засчитываться верным.
      expect(question.isCorrectFor(question.slotCount, 0), isFalse);
      expect(question.isCorrectFor(-1, 0), isFalse);

      // Порядок слов — это и есть задание: собранное из слотов предложение
      // обязано совпасть с озвучкой целиком.
      expect(question.assembled, question.answerSpeech);
      expect(question.assembled.split(' ').length, question.slotCount);
    });
  });

  group('вид дистракторов', () {
    test('приходит с кругом, а не выводится из механики', () async {
      final concepts = await content.conceptsUpTo(Tier.a0);
      String? itemId;
      var far = const <String>[];
      var near = const <String>[];
      for (final concept in concepts) {
        final thematic = await content.distractorsFor(
            concept.id, 'de', DistractorKind.far.code);
        final phonetic = await content.distractorsFor(
            concept.id, 'de', DistractorKind.near.code);
        if (thematic.isNotEmpty && phonetic.isNotEmpty) {
          itemId = concept.id;
          far = thematic.map((d) => d.form).toList();
          near = phonetic.map((d) => d.form).toList();
          break;
        }
      }
      expect(itemId, isNotNull,
          reason: 'в de.db нет концепта с обоими видами дистракторов');

      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'ru',
        random: Random(7),
      );
      // Механика у обоих кругов одна и та же. Раньше «созвучные» означали
      // другой режим — «Тесный круг», — и попросить их, не меняя режима, было
      // нечем. Теперь это параметр круга, и разница видна на одной механике.
      final base = PlannedCircle(
        itemId: itemId!,
        mode: GameMode.pickTarget,
        isNew: false,
        lumens: 60,
      );
      final thematic =
          await builder.build(base.copyWith(distractorKind: DistractorKind.far));
      final phonetic = await builder
          .build(base.copyWith(distractorKind: DistractorKind.near));

      expect(thematic, isNotNull);
      expect(phonetic, isNotNull);
      expect(thematic!.mode, phonetic!.mode);

      // Заданные руками имеют приоритет над добором по созвездию, поэтому
      // весь ручной набор нужного вида обязан оказаться в круге.
      expect(phonetic.options, containsAll(near));
      expect(thematic.options, containsAll(far));
      // Созвучные подобраны по фонетике и соседями по теме не бывают —
      // значит в тематическом круге им взяться неоткуда.
      for (final form in near) {
        expect(thematic.options, isNot(contains(form)), reason: form);
      }
    });
  });

  group('после игры', () {
    test('сыгранные слова возвращаются как повторы, а не как новые', () async {
      final repository = WordStateRepository(userDb);
      final session = await loader.level(now);

      // Играем первые пять кругов верно.
      for (final q in session.questions.take(5)) {
        await repository.applyAnswer(
          itemId: q.itemId,
          tier: q.tier,
          mode: q.mode,
          correct: true,
          latency: const Duration(milliseconds: 1400),
          now: now,
        );
      }

      // Через неделю звёзды потускнели и просятся на повтор.
      final later = now.add(const Duration(days: 7));
      final second = await loader.level(later);

      expect(second.reviews, greaterThan(0));
      final playedIds = session.questions.take(5).map((q) => q.itemId);
      final reviewedIds =
          second.questions.where((q) => !q.isNew).map((q) => q.itemId);
      expect(reviewedIds, containsAll(playedIds.toSet().take(1)));
    });

    test('режим повтора растёт вместе с яркостью слова', () async {
      final repository = WordStateRepository(userDb);
      final concepts = await content.conceptsUpTo(Tier.a0);
      final id = concepts.first.id;

      // Доводим слово до высокой яркости серией верных быстрых ответов.
      var at = now;
      for (var i = 0; i < 6; i++) {
        await repository.applyAnswer(
          itemId: id,
          tier: Tier.a0,
          mode: GameMode.pickTarget,
          correct: true,
          latency: const Duration(milliseconds: 700),
          now: at,
        );
        final state = await repository.load(id);
        at = state.dueAt() ?? at.add(const Duration(days: 1));
      }

      final state = await repository.load(id);
      // Слово повторяли шесть раз подряд верно — оно должно уйти далеко.
      expect(state.stability, greaterThan(10));
      expect(state.reps, 6);
    });
  });

  group('Восход', () {
    test('у нового игрока повторять нечего', () async {
      final session = await loader.sunrise(now);
      expect(session.isEmpty, isTrue);
    });

    test('после игры Восход показывает самые тусклые звёзды', () async {
      final repository = WordStateRepository(userDb);
      final concepts = await content.conceptsUpTo(Tier.a0);

      for (final concept in concepts.take(4)) {
        await repository.applyAnswer(
          itemId: concept.id,
          tier: Tier.a0,
          mode: GameMode.pickTarget,
          correct: true,
          latency: const Duration(milliseconds: 1400),
          now: now,
        );
      }

      final later = now.add(const Duration(days: 30));
      final session = await loader.sunrise(later);

      expect(session.isEmpty, isFalse);
      expect(session.newWords, 0);
      expect(session.questions.every((q) => !q.isNew), isTrue);

      // Порядок — от самых тусклых.
      final lumens = session.questions.map((q) => q.lumens).toList();
      final sorted = [...lumens]..sort();
      expect(lumens, sorted);
    });
  });

  group('починенное вехой M10', () {
    // Каждый тест здесь закрывает дефект, найденный при переносе тестов на
    // новый набор механик. Все шесть были в моём собственном коде, и ни один
    // не падал: они делали игру тише — хуже, но работающей.

    test('обе фразовые механики стоят на одном предложении', () async {
      // Комментарий в загрузчике обещал «обе на одном материале», а код звал
      // сборку дважды, и та каждый раз тянула случайную фразу заново. На
      // четырёх фразах A0 они совпадали примерно в четверти случаев —
      // обещание выполнялось иногда. Выполняющееся иногда обещание хуже
      // отсутствующего: игрок не может опереться на то, чего не понимает.
      final session = await loader.level(now);
      final phrases =
          session.questions.where((q) => q.mode.isPhrase).toList();

      // «Собери предложение» может не собраться из короткой фразы — это
      // отказ по длине, а не поломка. Проверяем, когда собрались обе.
      if (phrases.length < 2) return;

      expect(phrases.map((q) => q.mode).toSet(),
          {GameMode.fillGaps, GameMode.buildPhrase});
      expect(
        phrases.map((q) => q.answerSpeech).toSet(),
        hasLength(1),
        reason: 'механики встали на разные предложения: '
            '${phrases.map((q) => q.answerSpeech).toList()}',
      );
    });

    test('знакомство остаётся показом на любом уровне захода', () async {
      // Надбавка вариантов от захода жила в сборщике и прибавлялась к
      // каждому кругу — включая тот, которому планировщик намеренно оставил
      // один вариант. С четвёртого уровня захода первый в жизни показ слова
      // становился выбором из двух, с седьмого — из трёх: показ превращался
      // в проверку слова, которого игрок ещё не видел.
      for (final level in [1, 4, 7, 12, 40]) {
        final session = await loader.level(
          now,
          difficulty: ClimbRules.difficultyFor(level),
        );
        final introductions =
            session.questions.where((q) => q.isNew).toList();
        expect(introductions, isNotEmpty, reason: 'уровень $level');

        for (final question in introductions) {
          expect(
            question.options.length,
            SessionBalance.introductionOptions,
            reason: 'уровень $level: у знакомства '
                '${question.options.length} вариантов',
          );
        }
      }
    });

    test('заход расширяет круг и на словах, и на фразе', () async {
      // Обратная сторона той же ошибки: `_phraseRuns` не получал сложность
      // вовсе, и пул фразы оставался шириной в шесть при любом уровне.
      // Словесные круги дорожали, а закрывающая уровень фраза — нет.
      final easy = await loader.level(now);
      final hard = await loader.level(
        now,
        difficulty: ClimbRules.difficultyFor(40),
      );

      int widest(LoadedSession s, bool phrase) {
        final matching = s.questions
            .where((q) => q.mode.isPhrase == phrase && !q.isNew)
            .map((q) => q.options.length);
        return matching.isEmpty ? 0 : matching.reduce(max);
      }

      expect(widest(hard, false), greaterThan(widest(easy, false)),
          reason: 'словесные круги не расширились');
      if (widest(easy, true) > 0) {
        expect(widest(hard, true), greaterThan(widest(easy, true)),
            reason: 'фраза не расширилась вместе с заходом');
      }
    });

    test('повторённое слово во фразе получает свой вариант пула', () async {
      // `_fillGaps` искал индекс через `indexOf`: два пропуска с одним и тем
      // же словом получали один индекс, спорили за один вариант, а второе
      // такое же слово в пуле оставалось недостижимым. Рядом, в сборке
      // предложения из слов, от этого стояла защита — два сборщика фраз
      // расходились друг с другом.
      //
      // В контенте фраз с повторённым ответом пока нет, поэтому проверяется
      // общее свойство: у каждого слота свой индекс.
      final session = await loader.level(now);
      for (final question in session.questions.where((q) => q.mode.isPhrase)) {
        expect(
          question.answers.toSet(),
          hasLength(question.answers.length),
          reason: '${question.itemId}: слоты делят один вариант '
              '(${question.answers})',
        );
      }
    });
  });
}
