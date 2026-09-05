import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/score.dart';

/// Очки — это не «сколько красивых цифр показать», а стимул. Каждый тест
/// здесь защищает одно из четырёх правил из docs/CONCEPT.md, которые не дают
/// формуле выродиться в угадайку.
void main() {
  const fast = Duration(milliseconds: 900);
  const medium = Duration(milliseconds: 1500);
  const slow = Duration(seconds: 5);

  group('множитель скорости', () {
    test('на тусклом слове таймера нет вообще', () {
      // Инвариант README: на новом материале скорость не измеряется.
      for (final latency in [fast, medium, slow]) {
        expect(
          ScoreRules.speedMultiplier(latency, lumens: 0),
          ScoreBalance.kSpeedSlow,
        );
        expect(
          ScoreRules.speedMultiplier(latency,
              lumens: ScoreBalance.speedBonusMinLm - 1),
          ScoreBalance.kSpeedSlow,
        );
      }
    });

    test('на выученном слове лестница порогов работает', () {
      const lm = 80;
      expect(ScoreRules.speedMultiplier(const Duration(milliseconds: 500),
          lumens: lm), ScoreBalance.kSpeedFastest);
      expect(ScoreRules.speedMultiplier(const Duration(milliseconds: 1500),
          lumens: lm), ScoreBalance.kSpeedFast);
      expect(ScoreRules.speedMultiplier(const Duration(milliseconds: 3000),
          lumens: lm), ScoreBalance.kSpeedMedium);
      expect(ScoreRules.speedMultiplier(const Duration(seconds: 10),
          lumens: lm), ScoreBalance.kSpeedSlow);
    });

    test('множитель включается ровно на пороге яркости', () {
      expect(
        ScoreRules.speedMultiplier(fast,
            lumens: ScoreBalance.speedBonusMinLm),
        ScoreBalance.kSpeedFastest,
      );
    });

    test('штрафа за медленность нет — множитель не опускается ниже 1', () {
      expect(
        ScoreRules.speedMultiplier(const Duration(minutes: 5), lumens: 100),
        greaterThanOrEqualTo(1.0),
      );
    });
  });

  group('комбо', () {
    test('множитель растёт по шагу и упирается в потолок', () {
      expect(const ComboState(streak: 0).multiplier, 1.0);
      expect(const ComboState(streak: 5).multiplier, closeTo(1.5, 1e-9));
      expect(const ComboState(streak: 100).multiplier,
          ScoreBalance.kComboMax);
    });

    test('верные подряд наращивают серию', () {
      final run = RunScore();
      for (var i = 0; i < 4; i++) {
        run.apply(
          correct: true,
          latency: medium,
          mode: GameMode.circle,
          lumens: 50,
        );
      }
      expect(run.combo.streak, 4);
      expect(run.maxCombo, 4);
    });

    test('медленная ошибка обнуляет комбо, но не блокирует его', () {
      final run = RunScore();
      for (var i = 0; i < 3; i++) {
        run.apply(
          correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      }
      run.apply(
        correct: false, latency: slow, mode: GameMode.circle, lumens: 50);

      expect(run.combo.streak, 0);
      expect(run.combo.isLocked, isFalse);

      // Следующая верная связь сразу поднимает серию.
      run.apply(
        correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      expect(run.combo.streak, 1);
    });

    test('быстрая ошибка сбрасывает комбо вдвойне', () {
      final run = RunScore();
      for (var i = 0; i < 5; i++) {
        run.apply(
          correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      }
      run.apply(
        correct: false, latency: fast, mode: GameMode.circle, lumens: 50);

      expect(run.combo.streak, 0);
      expect(run.combo.lockRemaining, ScoreBalance.fastErrorComboLock);

      // Три следующие верные связи не поднимают серию — тыкать наугад
      // математически убыточно.
      for (var i = 0; i < ScoreBalance.fastErrorComboLock; i++) {
        run.apply(
          correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
        expect(run.combo.streak, 0, reason: 'связь ${i + 1} под блокировкой');
      }

      run.apply(
        correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      expect(run.combo.streak, 1);
    });

    test('под блокировкой очки идут, но без бонуса комбо', () {
      final run = RunScore();
      run.apply(
        correct: false, latency: fast, mode: GameMode.circle, lumens: 50);
      final result = run.apply(
        correct: true, latency: slow, mode: GameMode.circle, lumens: 50);

      expect(result.score, greaterThan(0));
      expect(result.comboMultiplier, 1.0);
    });

    test('бонус комбо применяется по состоянию до связи', () {
      final run = RunScore();
      // Первая верная связь не должна получить бонус за саму себя.
      final first = run.apply(
        correct: true, latency: slow, mode: GameMode.circle, lumens: 0);
      expect(first.comboMultiplier, 1.0);

      final second = run.apply(
        correct: true, latency: slow, mode: GameMode.circle, lumens: 0);
      expect(second.comboMultiplier, closeTo(1.1, 1e-9));
    });
  });

  group('начисление', () {
    test('формула: база × скорость × комбо × режим', () {
      final result = ScoreRules.scoreConnection(
        correct: true,
        latency: const Duration(milliseconds: 500),
        mode: GameMode.typing,
        lumens: 80,
        combo: const ComboState(streak: 5),
      );

      // 10 × 3.0 × 1.5 × 2.0 = 90
      expect(result.score, 90);
      expect(result.speedMultiplier, 3.0);
      expect(result.comboMultiplier, closeTo(1.5, 1e-9));
      expect(result.modeMultiplier, 2.0);
    });

    test('ошибка не приносит очков и не отнимает набранные', () {
      final run = RunScore();
      run.apply(
        correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      final before = run.score;

      final result = run.apply(
        correct: false, latency: medium, mode: GameMode.circle, lumens: 50);

      expect(result.score, 0);
      expect(run.score, before);
    });

    test('сложный режим приносит больше очков за тот же ответ', () {
      int scoreIn(GameMode mode) => ScoreRules.scoreConnection(
            correct: true,
            latency: medium,
            mode: mode,
            lumens: 0,
            combo: const ComboState(),
          ).score;

      expect(scoreIn(GameMode.phrase), greaterThan(scoreIn(GameMode.typing)));
      expect(scoreIn(GameMode.typing), greaterThan(scoreIn(GameMode.circle)));
    });
  });

  group('узнавание вместо владения', () {
    test('узнавание на выученном слове не приносит очков вообще', () {
      final result = ScoreRules.scoreConnection(
        correct: true,
        latency: fast,
        mode: GameMode.recognition,
        lumens: ScoreBalance.recognitionScoreCapLm,
        combo: const ComboState(streak: 10),
      );
      expect(result.score, 0);
      // Но комбо всё равно растёт: игрок ответил верно.
      expect(result.combo.streak, 11);
    });

    test('узнавание на новом слове очки приносит', () {
      final result = ScoreRules.scoreConnection(
        correct: true,
        latency: medium,
        mode: GameMode.recognition,
        lumens: 0,
        combo: const ComboState(),
      );
      expect(result.score, greaterThan(0));
    });

    test('продуктивные режимы приносят очки на любой яркости', () {
      for (final mode in GameMode.values.where((m) => m.isProductive)) {
        expect(ScoreRules.scores(mode, 100), isTrue, reason: '$mode');
      }
      expect(ScoreRules.scores(GameMode.recognition, 100), isFalse);
    });
  });

  group('горящее слово', () {
    test('три быстрых верных подряд в продуктивном режиме', () {
      var streak = 0;
      for (var i = 0; i < ScoreBalance.burningFastStreak; i++) {
        streak = ScoreRules.nextFastStreak(
          current: streak,
          correct: true,
          latency: const Duration(milliseconds: 1000),
          mode: GameMode.circle,
        );
      }
      expect(ScoreRules.isBurning(streak), isTrue);
    });

    test('узнавание не зажигает слово, как бы быстро ни отвечали', () {
      var streak = 0;
      for (var i = 0; i < 10; i++) {
        streak = ScoreRules.nextFastStreak(
          current: streak,
          correct: true,
          latency: const Duration(milliseconds: 300),
          mode: GameMode.recognition,
        );
      }
      expect(streak, 0);
      expect(ScoreRules.isBurning(streak), isFalse);
    });

    test('медленный верный ответ обнуляет серию', () {
      final streak = ScoreRules.nextFastStreak(
        current: 2,
        correct: true,
        latency: const Duration(seconds: 3),
        mode: GameMode.circle,
      );
      expect(streak, 0);
    });

    test('ошибка обнуляет серию', () {
      expect(
        ScoreRules.nextFastStreak(
          current: 2,
          correct: false,
          latency: const Duration(milliseconds: 500),
          mode: GameMode.circle,
        ),
        0,
      );
    });

    test('порог быстроты для горения — свой, не как у очков', () {
      // 1.5 с: слово горит и при ответе, который не даёт максимума очков.
      final streak = ScoreRules.nextFastStreak(
        current: 2,
        correct: true,
        latency: const Duration(milliseconds: 1400),
        mode: GameMode.circle,
      );
      expect(streak, 3);
    });
  });

  group('итог забега', () {
    test('безошибочный забег получает бонус', () {
      final run = RunScore();
      for (var i = 0; i < 10; i++) {
        run.apply(
          correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      }
      final summary = run.summary();

      expect(summary.isPerfect, isTrue);
      expect(summary.accuracy, 1.0);
      expect(summary.accuracyBonus, ScoreBalance.perfectRunBonus);
      expect(summary.total, greaterThan(summary.baseScore));
    });

    test('забег с ошибкой бонуса не получает', () {
      final run = RunScore();
      for (var i = 0; i < 9; i++) {
        run.apply(
          correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      }
      run.apply(
        correct: false, latency: slow, mode: GameMode.circle, lumens: 50);

      final summary = run.summary();
      expect(summary.isPerfect, isFalse);
      expect(summary.accuracy, closeTo(0.9, 1e-9));
      expect(summary.total, summary.baseScore);
    });

    test('пустой забег не ломает подсчёт', () {
      final summary = RunScore().summary();
      expect(summary.total, 0);
      expect(summary.accuracy, 0);
      expect(summary.isPerfect, isFalse);
    });

    test('максимальное комбо запоминается, даже если сбилось', () {
      final run = RunScore();
      for (var i = 0; i < 7; i++) {
        run.apply(
          correct: true, latency: medium, mode: GameMode.circle, lumens: 50);
      }
      run.apply(
        correct: false, latency: slow, mode: GameMode.circle, lumens: 50);

      expect(run.combo.streak, 0);
      expect(run.summary().maxCombo, 7);
    });
  });

  group('ComboState', () {
    test('сравнивается по значению', () {
      expect(const ComboState(streak: 3), const ComboState(streak: 3));
      expect(
        const ComboState(streak: 3).hashCode,
        const ComboState(streak: 3).hashCode,
      );
      expect(const ComboState(streak: 3),
          isNot(const ComboState(streak: 3, lockRemaining: 1)));
    });

    test('читаемо печатается', () {
      expect(const ComboState(streak: 2).toString(), contains('2'));
    });
  });
}
