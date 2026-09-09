import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/score.dart';

/// Очки — это не «сколько красивых цифр показать», а стимул. Каждый тест
/// здесь защищает одно из четырёх правил из docs/CONCEPT.md, которые не дают
/// формуле выродиться в угадайку.
///
/// Механика в начислении участвует только множителем, и сказать про неё больше
/// нечего: ни вида дистракторов, ни числа вариантов в формуле нет. Вокруг
/// фразы стоят другие фразы, которые игрок уже знает, а вариантов в круге
/// всегда шесть — платится за то, сколько требуется от игрока, и только за
/// это.
///
/// **Что здесь удалено вместе со словарным слоем.**
///
/// * «Время ответа приводится к одному размещению» охранял `ScoreRules.paceFor`
///   — деление времени ответа на число размещений. Он был нужен фразовой
///   сборке: арена сообщала время до последней плитки, а пороги «быстро» и
///   «легко» рассчитаны на один тап, поэтому всякая верно собранная фраза
///   записывалась как `hard` и сбрасывала серию «горящей звезды». Ответ теперь
///   один на круг, делить не на что, и приведение стало тождеством.
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
          mode: GameMode.pickTarget,
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
          correct: true,
          latency: medium,
          mode: GameMode.pickTarget,
          lumens: 50);
      }
      run.apply(
        correct: false,
        latency: slow,
        mode: GameMode.pickTarget,
        lumens: 50);

      expect(run.combo.streak, 0);
      expect(run.combo.isLocked, isFalse);

      // Следующая верная связь сразу поднимает серию.
      run.apply(
        correct: true,
        latency: medium,
        mode: GameMode.pickTarget,
        lumens: 50);
      expect(run.combo.streak, 1);
    });

    test('быстрая ошибка сбрасывает комбо вдвойне', () {
      final run = RunScore();
      for (var i = 0; i < 5; i++) {
        run.apply(
          correct: true,
          latency: medium,
          mode: GameMode.pickTarget,
          lumens: 50);
      }
      run.apply(
        correct: false,
        latency: fast,
        mode: GameMode.pickTarget,
        lumens: 50);

      expect(run.combo.streak, 0);
      expect(run.combo.lockRemaining, ScoreBalance.fastErrorComboLock);

      // Три следующие верные связи не поднимают серию — тыкать наугад
      // математически убыточно.
      for (var i = 0; i < ScoreBalance.fastErrorComboLock; i++) {
        run.apply(
          correct: true,
          latency: medium,
          mode: GameMode.pickTarget,
          lumens: 50);
        expect(run.combo.streak, 0, reason: 'связь ${i + 1} под блокировкой');
      }

      run.apply(
        correct: true,
        latency: medium,
        mode: GameMode.pickTarget,
        lumens: 50);
      expect(run.combo.streak, 1);
    });

    test('под блокировкой очки идут, но без бонуса комбо', () {
      final run = RunScore();
      run.apply(
        correct: false,
        latency: fast,
        mode: GameMode.pickTarget,
        lumens: 50);
      final result = run.apply(
        correct: true,
        latency: slow,
        mode: GameMode.pickTarget,
        lumens: 50);

      expect(result.score, greaterThan(0));
      expect(result.comboMultiplier, 1.0);
    });

    test('бонус комбо применяется по состоянию до связи', () {
      final run = RunScore();
      // Первая верная связь не должна получить бонус за саму себя.
      final first = run.apply(
        correct: true, latency: slow, mode: GameMode.pickTarget, lumens: 0);
      expect(first.comboMultiplier, 1.0);

      final second = run.apply(
        correct: true, latency: slow, mode: GameMode.pickTarget, lumens: 0);
      expect(second.comboMultiplier, closeTo(1.1, 1e-9));
    });
  });

  group('начисление', () {
    test('формула: база × скорость × комбо × режим', () {
      final result = ScoreRules.scoreConnection(
        correct: true,
        latency: const Duration(milliseconds: 500),
        mode: GameMode.pickTarget,
        lumens: 80,
        combo: const ComboState(streak: 5),
      );

      // 10 × 3.0 × 1.5 × 1.6 = 72
      expect(result.score, 72);
      expect(result.speedMultiplier, 3.0);
      expect(result.comboMultiplier, closeTo(1.5, 1e-9));
      expect(result.modeMultiplier, 1.6);
    });

    test('ошибка не приносит очков и не отнимает набранные', () {
      final run = RunScore();
      run.apply(
        correct: true,
        latency: medium,
        mode: GameMode.pickTarget,
        lumens: 50);
      final before = run.score;

      final result = run.apply(
        correct: false,
        latency: medium,
        mode: GameMode.pickTarget,
        lumens: 50);

      expect(result.score, 0);
      expect(run.score, before);
    });

    test('чем больше механика требует, тем дороже тот же верный ответ', () {
      int scoreIn(GameMode mode) => ScoreRules.scoreConnection(
            correct: true,
            latency: medium,
            mode: mode,
            lumens: 0,
            combo: const ComboState(),
          ).score;

      // Лестница идёт по требованию к игроку: узнать фразу по тексту дешевле
      // всего, узнать её на слух дороже, вспомнить и выбрать на изучаемом —
      // дороже всего. Верхушка опустела дважды — «Набор» (2.0) ушёл с полем
      // ввода, фразовая сборка (2.2–2.5) с механикой вставки слов, — и
      // `pickTarget` за ними не подняли: множитель говорит, сколько требуется
      // от игрока, а не сколько механик осталось.
      const ladder = [
        GameMode.pickNative,
        GameMode.listenNative,
        GameMode.pickTarget,
      ];
      // Механика без места в лестнице стоила бы столько же, сколько соседняя,
      // и разница в требовании к игроку перестала бы оплачиваться.
      expect(ladder.toSet(), GameMode.values.toSet());

      for (var i = 1; i < ladder.length; i++) {
        expect(
          scoreIn(ladder[i]),
          greaterThan(scoreIn(ladder[i - 1])),
          reason: '${ladder[i].name} дешевле ${ladder[i - 1].name}',
        );
      }
    });
  });

  group('узнавание вместо владения', () {
    test('узнавание на выученном слове не приносит очков вообще', () {
      final result = ScoreRules.scoreConnection(
        correct: true,
        latency: fast,
        mode: GameMode.pickNative,
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
        mode: GameMode.pickNative,
        lumens: 0,
        combo: const ComboState(),
      );
      expect(result.score, greaterThan(0));
    });

    test('потолок узнавания не обходится ни комбо, ни скоростью', () {
      // Проверяется, что ноль — это именно ноль: ни серия из десяти связей,
      // ни быстрый ответ не пробивают потолок. Иначе фарм лёгкого на
      // выученном вернулся бы через множители, от которых потолок и
      // придуман.
      final capped =
          GameMode.values.where((m) => !ScoreRules.scores(m, 100));
      expect(capped, isNotEmpty);
      for (final mode in capped) {
        expect(
          ScoreRules.scoreConnection(
            correct: true,
            latency: fast,
            mode: mode,
            lumens: 100,
            combo: const ComboState(streak: 10),
          ).score,
          0,
          reason: mode.name,
        );
      }
    });

    test('продуктивные режимы приносят очки на любой яркости', () {
      for (final mode in GameMode.values.where((m) => m.isProductive)) {
        expect(ScoreRules.scores(mode, 100), isTrue, reason: '$mode');
      }
      // Обратное утверждение — «непродуктивные не приносят» — переехало в
      // «потолок режет узнавание с текста, а не со слуха»: оно перестало
      // быть верным для звука.
    });

    test('потолок режет узнавание с текста, а не со слуха', () {
      // Правило было «звук стоит по обе стороны деления, и потолок режет ту
      // половину, где варианты на родном»: платный вопрос на слух в игре был,
      // просто это был `listenTarget` с вариантами на изучаемом. Механику
      // удалили — варианты на слух всегда на родном, — и прежнее правило
      // оставило бы слух без оплаты выше 40 lm вообще.
      //
      // Цифры при этом сходятся в мёртвую точку: `speedBonusMinLm` и
      // `recognitionScoreCapLm` равны 40 и зажимают слух с двух сторон. Ниже
      // 40 скоростного множителя нет, от 40 не было бы очков — то есть
      // «переслушивание снимает скорость» не срабатывало бы никогда.
      expect(ScoreRules.scores(GameMode.listenNative, 100), isTrue);
      expect(ScoreRules.scores(GameMode.pickTarget, 100), isTrue);

      // Под потолком осталось ровно одно: узнавание слова, которое показали
      // написанным. Именно там «знаю по написанию» и превращается в фарм.
      const cap = ScoreBalance.recognitionScoreCapLm;
      final capped =
          GameMode.values.where((m) => !ScoreRules.scores(m, cap)).toList();
      expect(capped, [GameMode.pickNative]);
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
          mode: GameMode.pickTarget,
        );
      }
      expect(ScoreRules.isBurning(streak), isTrue);
    });

    test('ни одно узнавание не зажигает слово, как бы быстро ни отвечали', () {
      // Проверяются обе непроизводящие механики: узнавание с текста и
      // узнавание со слуха. Скорость на них не доказывает владения, и
      // счётчик горящих слов не должен от них расти ни на единицу.
      for (final mode in GameMode.values.where((m) => !m.isProductive)) {
        var streak = 0;
        for (var i = 0; i < 10; i++) {
          streak = ScoreRules.nextFastStreak(
            current: streak,
            correct: true,
            latency: const Duration(milliseconds: 300),
            mode: mode,
          );
        }
        expect(streak, 0, reason: mode.name);
        expect(ScoreRules.isBurning(streak), isFalse, reason: mode.name);
      }
    });

    test('медленный верный ответ обнуляет серию', () {
      final streak = ScoreRules.nextFastStreak(
        current: 2,
        correct: true,
        latency: const Duration(seconds: 3),
        mode: GameMode.pickTarget,
      );
      expect(streak, 0);
    });

    test('ошибка обнуляет серию', () {
      expect(
        ScoreRules.nextFastStreak(
          current: 2,
          correct: false,
          latency: const Duration(milliseconds: 500),
          mode: GameMode.pickTarget,
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
        mode: GameMode.pickTarget,
      );
      expect(streak, 3);
    });
  });

  group('итог забега', () {
    test('безошибочный забег получает бонус', () {
      final run = RunScore();
      for (var i = 0; i < 10; i++) {
        run.apply(
          correct: true,
          latency: medium,
          mode: GameMode.pickTarget,
          lumens: 50);
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
          correct: true,
          latency: medium,
          mode: GameMode.pickTarget,
          lumens: 50);
      }
      run.apply(
        correct: false,
        latency: slow,
        mode: GameMode.pickTarget,
        lumens: 50);

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
          correct: true,
          latency: medium,
          mode: GameMode.pickTarget,
          lumens: 50);
      }
      run.apply(
        correct: false,
        latency: slow,
        mode: GameMode.pickTarget,
        lumens: 50);

      expect(run.combo.streak, 0);
      expect(run.summary().maxCombo, 7);
    });

    test('круг, за который не заплатили, всё равно идёт в точность', () {
      // Прежде этот тест говорил, что фразовая механика идёт в тот же забег,
      // что и словесная: накопитель не должен знать про источник материала,
      // иначе точность считалась бы по одной половине забега. Источников
      // больше нет — все три механики спрашивают фразу, — но само деление
      // забега на две половины уцелело, только проходит теперь по оплате.
      //
      // Узнавание на ярком слове не приносит очков вообще (митигация
      // «узнавание вместо владения»), а ответ игрок дал верный. Считай
      // накопитель точность по оплаченным кругам — и безошибочный забег из
      // узнаваний потерял бы бонус за точность: игрока наказали бы за яркость
      // его же звёзд.
      final run = RunScore();
      run.apply(
        correct: true,
        latency: medium,
        mode: GameMode.pickTarget,
        lumens: 50);
      final unpaid = run.apply(
        correct: true,
        latency: medium,
        mode: GameMode.pickNative,
        lumens: 100);
      run.apply(
        correct: true,
        latency: medium,
        mode: GameMode.listenNative,
        lumens: 100);

      expect(unpaid.score, 0, reason: 'сравнивать нечего: круг оплачен');

      final summary = run.summary();
      expect(summary.circles, 3);
      expect(summary.correct, 3);
      expect(summary.isPerfect, isTrue);
      expect(summary.maxCombo, 3);
      expect(summary.accuracyBonus, ScoreBalance.perfectRunBonus);
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
