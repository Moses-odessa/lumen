import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/audio/audio_service.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/game/application/run_controller.dart';

/// Забег — это состояние, а не экран, поэтому проверяется без виджетов.
void main() {
  late ProviderContainer container;
  late SilentAudioService audio;
  late AppDatabase db;

  setUp(() {
    audio = SilentAudioService();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      audioServiceProvider.overrideWithValue(audio),
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  CircleQuestion question(String id, {int answerIndex = 0}) => CircleQuestion(
        itemId: id,
        tier: Tier.a0,
        mode: GameMode.circle,
        prompt: id,
        options: const ['a', 'b', 'c'],
        answerIndex: answerIndex,
        lumens: 50,
        answerAudioId: 'de/$id',
      );

  RunController controller() =>
      container.read(runControllerProvider.notifier);
  RunState state() => container.read(runControllerProvider);

  group('старт', () {
    test('забег начинается с первого круга', () {
      controller().start([question('a'), question('b')]);

      expect(state().phase, RunPhase.asking);
      expect(state().current?.itemId, 'a');
      expect(state().total, 2);
      expect(state().progress, 0);
    });

    test('пустой список кругов не начинает забег', () {
      controller().start([]);
      expect(state().isFinished, isTrue);
      expect(state().current, isNull);
    });
  });

  group('ответ', () {
    test('верный ответ даёт очки и растит комбо', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(0, const Duration(milliseconds: 900));

      expect(state().score, greaterThan(0));
      expect(state().combo.streak, 1);
      expect(state().correct, 1);
      expect(state().lastCorrect, isTrue);
      expect(state().phase, RunPhase.revealing);
    });

    test('верное соединение озвучивается', () {
      controller().start([question('a')]);
      controller().answerOption(0, const Duration(milliseconds: 900));

      // Инвариант README: каждое верное соединение озвучивается.
      expect(audio.played, ['de/a']);
    });

    test('неверный ответ не озвучивается и не даёт очков', () {
      controller().start([question('a')]);
      controller().answerOption(2, const Duration(seconds: 2));

      expect(audio.played, isEmpty);
      expect(state().score, 0);
      expect(state().lastCorrect, isFalse);
    });

    test('ошибка возвращает слово в конец забега', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(2, const Duration(seconds: 2));

      // Жизней нет: слово вернётся, но забег не остановится.
      expect(state().queue.map((q) => q.itemId), ['a', 'b', 'a']);
      expect(state().phase, RunPhase.revealing);
    });

    test('прогресс считается по плану, а не по очереди', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(2, const Duration(seconds: 2));

      // Ошибка удлиняет очередь — полоса прогресса не должна ползти назад.
      expect(state().progress, 0);
      expect(state().total, 2);
    });

    test('повторный ответ на тот же круг игнорируется', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(0, const Duration(milliseconds: 900));
      final score = state().score;

      controller().answerOption(0, const Duration(milliseconds: 900));
      expect(state().score, score);
    });
  });

  group('переход к следующему кругу', () {
    test('после паузы открывается следующий круг', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(0, const Duration(milliseconds: 900));

        expect(state().current?.itemId, 'a');
        async.elapse(const Duration(seconds: 2));

        expect(state().current?.itemId, 'b');
        expect(state().phase, RunPhase.asking);
        expect(state().lastCorrect, isNull);
      });
    });

    test('на ошибке пауза длиннее — верный вариант надо успеть увидеть', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(2, const Duration(seconds: 2));

        async.elapse(const Duration(milliseconds: 500));
        expect(state().phase, RunPhase.revealing,
            reason: 'на ошибке пауза не может быть такой же короткой');

        async.elapse(const Duration(seconds: 1));
        expect(state().phase, RunPhase.asking);
      });
    });

    test('забег заканчивается итогом', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);

        controller().answerOption(0, const Duration(milliseconds: 900));
        async.elapse(const Duration(seconds: 2));
        controller().answerOption(0, const Duration(milliseconds: 900));
        async.elapse(const Duration(seconds: 2));

        expect(state().isFinished, isTrue);
        expect(state().summary, isNotNull);
        expect(state().summary!.isPerfect, isTrue);
        expect(state().summary!.circles, 2);
      });
    });

    test('ошибочное слово доигрывается до конца очереди', () {
      fakeAsync((async) {
        controller().start([question('a')]);

        controller().answerOption(2, const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));

        // Слово вернулось — забег ещё идёт.
        expect(state().isFinished, isFalse);
        expect(state().current?.itemId, 'a');

        controller().answerOption(0, const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));

        expect(state().isFinished, isTrue);
        expect(state().summary!.circles, 2);
        expect(state().summary!.correct, 1);
      });
    });
  });

  group('ввод текста', () {
    test('ответ вводом проверяется по тексту, а не по индексу', () {
      const typed = CircleQuestion(
        itemId: 'bill',
        tier: Tier.a1,
        mode: GameMode.typing,
        prompt: 'счёт',
        options: ['Rechnung'],
        answerIndex: 0,
        lumens: 70,
        answerAudioId: 'de/rechnung',
      );

      controller().start([typed]);
      controller().answerInput('rechnung', const Duration(seconds: 2));

      expect(state().correct, 1);
      expect(audio.played, ['de/rechnung']);
    });
  });

  group('память', () {
    test('ответ доходит до базы и переживает забег', () async {
      controller().start([question('a')]);
      controller().answerOption(0, const Duration(milliseconds: 900));

      // Запись идёт в фоне, чтобы не тормозить забег, — ждём её отдельно.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final row = await db.loadWordState('a');
      expect(row, isNotNull);
      expect(row!.reps, 1);
      expect(row.stability, greaterThan(0));

      final reviews = await db.select(db.reviews).get();
      expect(reviews, hasLength(1));
      expect(reviews.single.correct, isTrue);
      expect(reviews.single.mode, GameMode.circle.code);
    });

    test('быстрые верные ответы зажигают слово', () async {
      controller().start([
        question('a'),
        question('a'),
        question('a'),
      ]);

      for (var i = 0; i < 3; i++) {
        controller().answerOption(0, const Duration(milliseconds: 600));
        await Future<void>.delayed(const Duration(milliseconds: 120));
        // Ручной переход: fakeAsync и настоящая база вместе не дружат.
        controller().state = controller().state.copyWith(
              index: i + 1,
              phase: RunPhase.asking,
            );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final row = await db.loadWordState('a');
      expect(row!.fastStreak, 3);
      expect(row.burning, isTrue);
      expect(await db.countBurning(), 1);
    });
  });
}
