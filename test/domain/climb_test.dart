import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/domain/scoring/score.dart';

/// Заход — аркадная надстройка над уже работающим счётом.
///
/// Главное свойство, которое проверяется здесь: **награда обгоняет
/// сложность**. Если сделать наоборот, оптимальной игрой станет топтание на
/// первом уровне, и вся затея развалится молча — игра останется рабочей, но
/// перестанет тянуть вверх.
void main() {
  group('множитель', () {
    test('первый уровень без надбавки', () {
      expect(ClimbRules.multiplierFor(1), 1.0);
    });

    test('растёт линейно', () {
      expect(ClimbRules.multiplierFor(2), closeTo(1.25, 1e-9));
      expect(ClimbRules.multiplierFor(5), closeTo(2.0, 1e-9));
    });

    test('упирается в потолок и дальше не растёт', () {
      expect(ClimbRules.multiplierFor(9), ClimbBalance.levelMultiplierMax);
      expect(ClimbRules.multiplierFor(50), ClimbBalance.levelMultiplierMax);
    });

    test('нулевой и отрицательный уровень считаются первым', () {
      // Не бывает, но данные приходят из базы, и падать из-за них незачем.
      expect(ClimbRules.multiplierFor(0), 1.0);
      expect(ClimbRules.multiplierFor(-3), 1.0);
    });
  });

  group('сложность', () {
    test('на первом уровне ничего не добавлено', () {
      final d = ClimbRules.difficultyFor(1);
      expect(d.extraOptions, 0);
      expect(d.speedFastest, ScoreBalance.speedFastest);
      expect(d.modeDraws, ClimbBalance.modeDrawsBase);
      expect(d.circlesPerRun, SessionBalance.circlesPerRunMin);
    });

    test('все четыре ручки монотонны', () {
      // Аркада ломается не когда сложно, а когда сложность прыгает
      // туда-сюда: игрок перестаёт понимать, стало ли труднее.
      var previous = ClimbRules.difficultyFor(1);
      for (var level = 2; level <= 30; level++) {
        final next = ClimbRules.difficultyFor(level);
        expect(next.extraOptions, greaterThanOrEqualTo(previous.extraOptions));
        expect(next.speedFastest, lessThanOrEqualTo(previous.speedFastest));
        expect(next.modeDraws, greaterThanOrEqualTo(previous.modeDraws));
        expect(next.circlesPerRun,
            greaterThanOrEqualTo(previous.circlesPerRun));
        previous = next;
      }
    });

    test('каждая ручка упирается в свой потолок', () {
      final far = ClimbRules.difficultyFor(100);
      expect(far.extraOptions, ClimbBalance.extraOptionsMax);
      expect(far.speedFastest, ClimbBalance.speedFastestFloor);
      expect(far.modeDraws, ClimbBalance.modeDrawsMax);
      expect(far.circlesPerRun, ClimbBalance.circlesPerRunCap);
    });

    test('порог автоматизма не опускается ниже пола', () {
      // Ниже 800 мс порог перестаёт мерить автоматизм и начинает мерить
      // скорость пальца.
      for (var level = 1; level <= 100; level++) {
        expect(ClimbRules.difficultyFor(level).speedFastest,
            greaterThanOrEqualTo(ClimbBalance.speedFastestFloor));
      }
    });
  });

  group('награда против сложности', () {
    test('к пятому уровню шанс угадать падает медленнее, чем растут очки', () {
      // Оба множителя считаем относительно первого уровня и сравниваем.
      // Это и есть аркадный контракт: подниматься должно быть выгодно.
      const optionsAtFirst = 6;
      for (var level = 2; level <= 9; level++) {
        final d = ClimbRules.difficultyFor(level);
        final guessPenalty =
            (optionsAtFirst + d.extraOptions) / optionsAtFirst;
        final reward = ClimbRules.multiplierFor(level);
        expect(reward, greaterThan(guessPenalty),
            reason: 'уровень $level: награда ×$reward против сложности '
                '×${guessPenalty.toStringAsFixed(2)}');
      }
    });
  });

  group('переход между уровнями', () {
    final at = DateTime.utc(2026, 9, 7, 12);

    test('уровень пройден — сложность и сумма растут', () {
      final next = ClimbRules.afterLevel(
        const ClimbState(),
        score: 500,
        accuracy: 1.0,
        at: at,
      );
      expect(next.level, 2);
      expect(next.total, 500);
      expect(next.levelsPlayed, 1);
      expect(next.startedAt, at);
    });

    test('слабый уровень сбрасывает сложность, но не отнимает очки', () {
      // «Потерять прогресс» в игре про память — способ отучить от неё
      // насовсем. Сбрасывается эскалация, а не накопленное.
      const climb = ClimbState(level: 6, total: 4000, levelsPlayed: 5);
      final next = ClimbRules.afterLevel(
        climb,
        score: 120,
        accuracy: 0.5,
        at: at,
      );
      expect(next.level, 1);
      expect(next.total, 4120);
      expect(next.levelsPlayed, 6);
    });

    test('точность на самом пороге сброса не даёт', () {
      final next = ClimbRules.afterLevel(
        const ClimbState(level: 4),
        score: 0,
        accuracy: ClimbBalance.resetBelowAccuracy,
        at: at,
      );
      expect(next.level, 5);
    });

    test('начало захода запоминается один раз', () {
      final first = ClimbRules.afterLevel(const ClimbState(),
          score: 10, accuracy: 1, at: at);
      final second = ClimbRules.afterLevel(first,
          score: 10, accuracy: 1, at: at.add(const Duration(minutes: 5)));
      expect(second.startedAt, at);
    });
  });

  group('перерыв закрывает заход', () {
    final at = DateTime.utc(2026, 9, 7, 12);

    test('короткий перерыв — заход тот же', () {
      const climb = ClimbState(level: 5, total: 3000, levelsPlayed: 4);
      final resumed = ClimbRules.resume(
        climb,
        lastPlayedAt: at,
        now: at.add(const Duration(minutes: 10)),
      );
      expect(resumed, climb);
    });

    test('долгий перерыв — заход начинается заново', () {
      // Иначе «один присест» растянется на сутки, и рекорд часа перестанет
      // что-либо означать.
      const climb = ClimbState(level: 5, total: 3000, levelsPlayed: 4);
      final resumed = ClimbRules.resume(
        climb,
        lastPlayedAt: at,
        now: at.add(ClimbBalance.idleClosesClimb),
      );
      expect(resumed, const ClimbState());
    });

    test('первая игра вообще — заход новый', () {
      expect(ClimbRules.resume(const ClimbState(level: 7),
          lastPlayedAt: null, now: at), const ClimbState());
    });
  });

  group('очки на уровне захода', () {
    test('множитель захода умножает начисление', () {
      const args = (
        correct: true,
        latency: Duration(milliseconds: 900),
        mode: GameMode.circle,
        lumens: 70,
      );

      final plain = ScoreRules.scoreConnection(
        correct: args.correct,
        latency: args.latency,
        mode: args.mode,
        lumens: args.lumens,
        combo: const ComboState(),
      );
      final climbed = ScoreRules.scoreConnection(
        correct: args.correct,
        latency: args.latency,
        mode: args.mode,
        lumens: args.lumens,
        combo: const ComboState(),
        climbMultiplier: 2.0,
      );

      expect(climbed.score, plain.score * 2);
      expect(climbed.climbMultiplier, 2.0);
    });

    test('сжатый порог автоматизма отбирает скоростной множитель', () {
      // Тот же ответ за 1000 мс: на первом уровне это «автоматизм», на
      // высоком — уже нет. Это и есть самая болезненная ручка сложности.
      const latency = Duration(milliseconds: 1000);
      final easy = ScoreRules.speedMultiplier(latency, lumens: 70);
      final hard = ScoreRules.speedMultiplier(
        latency,
        lumens: 70,
        fastest: const Duration(milliseconds: 900),
      );
      expect(easy, ScoreBalance.kSpeedFastest);
      expect(hard, lessThan(easy));
    });

    test('заход не даёт очков там, где их не даёт режим', () {
      // Митигация «узнавание вместо владения» сильнее аркады: на ярком
      // слове узнавание не приносит очков ни на каком уровне.
      final result = ScoreRules.scoreConnection(
        correct: true,
        latency: const Duration(milliseconds: 500),
        mode: GameMode.recognition,
        lumens: 90,
        combo: const ComboState(),
        climbMultiplier: 3.0,
      );
      expect(result.score, 0);
    });

    test('забег на уровне захода считает по его правилам', () {
      final run = RunScore(
        difficulty: ClimbRules.difficultyFor(5),
        climbMultiplier: ClimbRules.multiplierFor(5),
      );
      run.apply(
        correct: true,
        latency: const Duration(milliseconds: 500),
        mode: GameMode.circle,
        lumens: 70,
      );
      final plain = RunScore()
        ..apply(
          correct: true,
          latency: const Duration(milliseconds: 500),
          mode: GameMode.circle,
          lumens: 70,
        );
      expect(run.score, greaterThan(plain.score));
    });
  });
}
