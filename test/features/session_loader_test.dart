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

    test('у каждого круга есть центр, варианты и верный ответ', () async {
      final session = await loader.level(now);

      for (final q in session.questions) {
        expect(q.conceptId, isNotEmpty);
        if (!q.isTyped) {
          expect(q.options.length, greaterThanOrEqualTo(3),
              reason: '${q.conceptId}: слишком мало вариантов');
          expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1));
          expect(q.answer, isNotEmpty);
        }
        // Инвариант README: концепт без озвучки не проходит валидацию,
        // значит и в игре у ответа всегда есть audioId.
        expect(q.answerAudioId, isNotNull, reason: q.conceptId);
      }
    });

    test('варианты в круге не повторяются', () async {
      final session = await loader.level(now);

      for (final q in session.questions.where((q) => !q.isTyped)) {
        final lowered = q.options.map((o) => o.toLowerCase()).toList();
        expect(lowered.toSet().length, lowered.length,
            reason: '${q.conceptId}: дубли среди вариантов');
      }
    });

    test('первый показ нового слова — узнавание, центр на изучаемом', () async {
      final session = await loader.level(now);
      final first = session.questions.firstWhere((q) => q.isNew);

      expect(first.mode, GameMode.recognition);
      // Узнавание: в центре немецкий, вокруг русский.
      expect(first.prompt, isNotEmpty);
      final lexeme = await content.lexeme(first.conceptId, 'de');
      expect(first.prompt, contains(lexeme!.form));
    });

    test('в конце уровня стоит босс-фраза с пропуском', () async {
      final session = await loader.level(now);
      final last = session.questions.last;

      expect(last.mode, GameMode.phrase);
      expect(last.prompt, contains('_____'));
      expect(last.options, contains(last.answer));
    });

    test('одно слово не идёт двумя кругами подряд', () async {
      final session = await loader.level(now);
      final ids = session.questions.map((q) => q.conceptId).toList();

      for (var i = 1; i < ids.length - 1; i++) {
        expect(ids[i], isNot(ids[i - 1]), reason: 'позиция $i');
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
          conceptId: q.conceptId,
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
      final playedIds = session.questions.take(5).map((q) => q.conceptId);
      final reviewedIds =
          second.questions.where((q) => !q.isNew).map((q) => q.conceptId);
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
          conceptId: id,
          tier: Tier.a0,
          mode: GameMode.circle,
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
          conceptId: concept.id,
          tier: Tier.a0,
          mode: GameMode.circle,
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
}
