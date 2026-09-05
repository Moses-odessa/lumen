import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/srs/fsrs.dart';
import 'package:lumen/domain/srs/memory_state.dart';
import 'package:lumen/domain/srs/review_grade.dart';

/// Тесты FSRS проверяют не «числа сошлись с эталоном до пятого знака», а
/// свойства модели: что она ведёт себя так, как обещает теория интервального
/// повторения. Такие тесты переживают дообучение весов, а сравнение с
/// захардкоженными значениями — нет.
void main() {
  const fsrs = Fsrs();
  final t0 = DateTime.utc(2026, 1, 1, 9);

  MemoryState after(
    MemoryState state,
    List<(ReviewGrade, Duration)> reviews,
  ) {
    var current = state;
    var now = t0;
    for (final (grade, gap) in reviews) {
      now = now.add(gap);
      current = fsrs.review(current, grade, now);
    }
    return current;
  }

  group('первый показ', () {
    test('новое слово получает состояние по оценке', () {
      final state = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);

      expect(state.isNew, isFalse);
      expect(state.lastReview, t0);
      expect(state.reps, 1);
      expect(state.lapses, 0);
      expect(state.stability, greaterThan(0));
      expect(state.difficulty, inInclusiveRange(1, 10));
    });

    test('чем лучше первый ответ, тем длиннее первый интервал', () {
      final stabilities = [
        for (final g in ReviewGrade.values)
          fsrs.review(MemoryState.unseen, g, t0).stability,
      ];
      for (var i = 1; i < stabilities.length; i++) {
        expect(stabilities[i], greaterThan(stabilities[i - 1]),
            reason: 'оценка ${i + 1} должна давать большую стабильность');
      }
    });

    test('чем лучше первый ответ, тем ниже сложность', () {
      final easy = fsrs.review(MemoryState.unseen, ReviewGrade.easy, t0);
      final again = fsrs.review(MemoryState.unseen, ReviewGrade.again, t0);
      expect(easy.difficulty, lessThan(again.difficulty));
    });

    test('провал на первом показе сразу считается забыванием', () {
      final state = fsrs.review(MemoryState.unseen, ReviewGrade.again, t0);
      expect(state.lapses, 1);
    });
  });

  group('кривая забывания', () {
    test('новое слово не помнят вообще', () {
      expect(MemoryState.unseen.retrievabilityAt(t0), 0);
      expect(MemoryState.unseen.lumensAt(t0), 0);
    });

    test('через интервал стабильности вероятность падает до 90 %', () {
      // Определение стабильности: S — это срок, за который R падает до 0.9.
      const state = MemoryState(difficulty: 5, stability: 10);
      final aged = state.copyWith(lastReview: t0);
      final r = aged.retrievabilityAt(t0.add(const Duration(days: 10)));
      expect(r, closeTo(0.9, 0.001));
    });

    test('яркость монотонно падает между повторениями', () {
      final state = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);
      var previous = 101;
      for (final days in [0, 1, 3, 7, 30, 180, 3650]) {
        final lm = state.lumensAt(t0.add(Duration(days: days)));
        expect(lm, lessThanOrEqualTo(previous), reason: 'через $days дней');
        expect(lm, inInclusiveRange(0, 100));
        previous = lm;
      }
    });

    test('в момент повтора слово помнят полностью', () {
      final state = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);
      expect(state.lumensAt(t0), 100);
    });

    test('яркость никогда не отрицательная и не выше 100', () {
      const state = MemoryState(difficulty: 10, stability: 0.01);
      final aged = state.copyWith(lastReview: t0);
      expect(aged.lumensAt(t0.add(const Duration(days: 100000))),
          inInclusiveRange(0, 100));
    });
  });

  group('интервалы', () {
    test('интервал растёт вместе со стабильностью', () {
      const small = MemoryState(difficulty: 5, stability: 1);
      const large = MemoryState(difficulty: 5, stability: 100);
      expect(large.intervalFor(), greaterThan(small.intervalFor()));
    });

    test('более низкая целевая удержанность даёт более длинный интервал', () {
      const state = MemoryState(difficulty: 5, stability: 10);
      expect(
        state.intervalFor(retention: 0.8),
        greaterThan(state.intervalFor(retention: 0.95)),
      );
    });

    test('интервал по определению стабильности — примерно S дней', () {
      const state = MemoryState(difficulty: 5, stability: 10);
      final days = state.intervalFor().inHours / 24;
      expect(days, closeTo(10, 0.1));
    });

    test('интервал не короче часа', () {
      const state = MemoryState(difficulty: 10, stability: 0.0001);
      expect(state.intervalFor(), greaterThanOrEqualTo(const Duration(hours: 1)));
    });

    test('due у нового слова не задан', () {
      expect(MemoryState.unseen.dueAt(), isNull);
    });

    test('due отсчитывается от последнего повтора', () {
      final state = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);
      expect(state.dueAt()!.isAfter(t0), isTrue);
    });
  });

  group('повторение', () {
    test('успешное вспоминание удлиняет интервал', () {
      var state = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);
      var previous = state.stability;

      var now = t0;
      for (var i = 0; i < 5; i++) {
        now = now.add(state.intervalFor());
        state = fsrs.review(state, ReviewGrade.good, now);
        expect(state.stability, greaterThan(previous),
            reason: 'повтор ${i + 1}');
        previous = state.stability;
      }
    });

    test('провал сокращает интервал, но не обнуляет память', () {
      var state = after(MemoryState.unseen, [
        (ReviewGrade.good, Duration.zero),
        (ReviewGrade.good, const Duration(days: 3)),
        (ReviewGrade.good, const Duration(days: 10)),
      ]);
      final before = state.stability;

      state = fsrs.review(
        state,
        ReviewGrade.again,
        state.lastReview!.add(const Duration(days: 20)),
      );

      expect(state.stability, lessThan(before));
      // Забытое слово не становится новым: восстановить его дешевле, чем
      // выучить с нуля.
      expect(state.stability, greaterThan(0));
      expect(state.lapses, 1);
    });

    test('вспомнить на грани забывания ценнее, чем сразу после повтора', () {
      final base = after(MemoryState.unseen, [
        (ReviewGrade.good, Duration.zero),
        (ReviewGrade.good, const Duration(days: 5)),
      ]);

      // Тот же ответ, но один раз почти сразу, другой — когда слово почти
      // забылось. Второй должен дать больший прирост стабильности.
      final early = fsrs.review(
        base,
        ReviewGrade.good,
        base.lastReview!.add(const Duration(days: 1)),
      );
      final late = fsrs.review(
        base,
        ReviewGrade.good,
        base.lastReview!.add(const Duration(days: 60)),
      );

      expect(late.stability, greaterThan(early.stability));
    });

    test('«легко» удлиняет интервал сильнее, чем «трудно»', () {
      final base = after(MemoryState.unseen, [
        (ReviewGrade.good, Duration.zero),
        (ReviewGrade.good, const Duration(days: 5)),
      ]);
      final at = base.lastReview!.add(const Duration(days: 10));

      final hard = fsrs.review(base, ReviewGrade.hard, at);
      final good = fsrs.review(base, ReviewGrade.good, at);
      final easy = fsrs.review(base, ReviewGrade.easy, at);

      expect(hard.stability, lessThan(good.stability));
      expect(good.stability, lessThan(easy.stability));
    });

    test('трудное слово растёт медленнее лёгкого', () {
      final at = t0.add(const Duration(days: 10));
      final easyWord = MemoryState(
        difficulty: 2,
        stability: 10,
        lastReview: t0,
        reps: 3,
      );
      final hardWord = MemoryState(
        difficulty: 9,
        stability: 10,
        lastReview: t0,
        reps: 3,
      );

      final grownEasy = fsrs.review(easyWord, ReviewGrade.good, at);
      final grownHard = fsrs.review(hardWord, ReviewGrade.good, at);
      expect(grownHard.stability, lessThan(grownEasy.stability));
    });

    test('рост насыщается: у зрелого слова относительный прирост меньше', () {
      double relativeGrowth(double stability) {
        final state = MemoryState(
          difficulty: 5,
          stability: stability,
          lastReview: t0,
          reps: 3,
        );
        // Повтор ровно в срок — вероятность вспомнить одинаковая.
        final at = t0.add(state.intervalFor());
        return fsrs.review(state, ReviewGrade.good, at).stability / stability;
      }

      expect(relativeGrowth(100), lessThan(relativeGrowth(2)));
    });

    test('повтор в тот же день двигает стабильность слабо', () {
      final base = after(MemoryState.unseen, [
        (ReviewGrade.good, Duration.zero),
        (ReviewGrade.good, const Duration(days: 5)),
      ]);
      final sameDay = fsrs.review(
        base,
        ReviewGrade.good,
        base.lastReview!.add(const Duration(minutes: 30)),
      );

      // Слово ещё в рабочей памяти — засчитывать это как полноценный повтор
      // означало бы завысить интервал в разы.
      expect(sameDay.stability / base.stability, lessThan(2));
      expect(sameDay.reps, base.reps + 1);
    });

    test('внутри дня «легко» всё равно лучше «снова»', () {
      final base = after(MemoryState.unseen, [
        (ReviewGrade.good, Duration.zero),
        (ReviewGrade.good, const Duration(days: 5)),
      ]);
      final at = base.lastReview!.add(const Duration(hours: 2));

      expect(
        fsrs.review(base, ReviewGrade.easy, at).stability,
        greaterThan(fsrs.review(base, ReviewGrade.again, at).stability),
      );
    });
  });

  group('сложность', () {
    test('провалы поднимают сложность, лёгкие ответы опускают', () {
      final start = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);

      var failing = start;
      var easing = start;
      var now = t0;
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(days: 3));
        failing = fsrs.review(failing, ReviewGrade.again, now);
        easing = fsrs.review(easing, ReviewGrade.easy, now);
      }

      expect(failing.difficulty, greaterThan(start.difficulty));
      expect(easing.difficulty, lessThan(start.difficulty));
    });

    test('сложность не выходит за шкалу 1..10', () {
      var state = fsrs.review(MemoryState.unseen, ReviewGrade.again, t0);
      var now = t0;
      for (var i = 0; i < 50; i++) {
        now = now.add(const Duration(days: 1));
        state = fsrs.review(state, ReviewGrade.again, now);
        expect(state.difficulty, inInclusiveRange(1, 10));
      }

      for (var i = 0; i < 50; i++) {
        now = now.add(const Duration(days: 1));
        state = fsrs.review(state, ReviewGrade.easy, now);
        expect(state.difficulty, inInclusiveRange(1, 10));
      }
    });

    test('счётчики повторов и провалов растут корректно', () {
      final state = after(MemoryState.unseen, [
        (ReviewGrade.good, Duration.zero),
        (ReviewGrade.again, const Duration(days: 2)),
        (ReviewGrade.good, const Duration(days: 1)),
        (ReviewGrade.again, const Duration(days: 4)),
      ]);
      expect(state.reps, 4);
      expect(state.lapses, 2);
    });
  });

  group('стабильность в границах', () {
    test('никакая последовательность не выводит S за пределы', () {
      var state = MemoryState.unseen;
      var now = t0;
      final grades = [
        ReviewGrade.easy,
        ReviewGrade.easy,
        ReviewGrade.again,
        ReviewGrade.hard,
        ReviewGrade.easy,
      ];
      for (var i = 0; i < 200; i++) {
        now = now.add(Duration(days: i % 7 + 1));
        state = fsrs.review(state, grades[i % grades.length], now);
        expect(state.stability, inInclusiveRange(0.01, 36500));
        expect(state.stability.isFinite, isTrue);
      }
    });
  });

  group('preview', () {
    test('даёт состояние для каждой из четырёх оценок', () {
      final state = fsrs.review(MemoryState.unseen, ReviewGrade.good, t0);
      final preview = fsrs.preview(state, t0.add(const Duration(days: 5)));

      expect(preview.keys, ReviewGrade.values.toSet());
      expect(
        preview[ReviewGrade.again]!.stability,
        lessThan(preview[ReviewGrade.easy]!.stability),
      );
    });
  });

  group('gradeFromLatency', () {
    test('неверный ответ — всегда «снова», как бы быстро ни нажали', () {
      for (final ms in [100, 1500, 9000]) {
        expect(
          gradeFromLatency(Duration(milliseconds: ms), correct: false),
          ReviewGrade.again,
        );
      }
    });

    test('верный ответ градуируется по времени отклика', () {
      expect(
        gradeFromLatency(const Duration(milliseconds: 800), correct: true),
        ReviewGrade.easy,
      );
      expect(
        gradeFromLatency(const Duration(milliseconds: 1500), correct: true),
        ReviewGrade.good,
      );
      expect(
        gradeFromLatency(const Duration(milliseconds: 5000), correct: true),
        ReviewGrade.hard,
      );
    });

    test('границы порогов работают по «строго меньше»', () {
      expect(
        gradeFromLatency(SrsBalance.gradeEasyBelow, correct: true),
        ReviewGrade.good,
      );
      expect(
        gradeFromLatency(SrsBalance.gradeGoodBelow, correct: true),
        ReviewGrade.hard,
      );
    });
  });

  group('seedMemory', () {
    test('засеянное слово имеет заданную яркость', () {
      for (final lm in [50, 55, 60]) {
        final state = seedMemory(lumens: lm, at: t0);
        expect(state.lumensAt(t0), closeTo(lm, 1),
            reason: 'засев на $lm lm');
      }
    });

    test('засеянное слово не выглядит новым и попадает в очередь', () {
      final state = seedMemory(lumens: 55, at: t0);
      expect(state.isNew, isFalse);
      expect(state.reps, 1);
      // Яркость ниже 90 % — значит слово уже просрочено и попадёт в Восход.
      expect(state.dueAt()!.isBefore(t0), isTrue);
    });

    test('чем выше засев, тем больше стабильность', () {
      expect(
        seedMemory(lumens: 80, at: t0).stability,
        greaterThan(seedMemory(lumens: 30, at: t0).stability),
      );
    });

    test('крайние значения не ломают модель', () {
      for (final lm in [0, 1, 99, 100]) {
        final state = seedMemory(lumens: lm, at: t0);
        expect(state.stability.isFinite, isTrue, reason: '$lm lm');
        expect(state.stability, greaterThan(0), reason: '$lm lm');
      }
    });
  });
}
