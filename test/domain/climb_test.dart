import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/domain/scoring/score.dart';

/// Заход — аркадная надстройка над уже работающим счётом.
///
/// Главное свойство, которое проверяется здесь: **награда обгоняет
/// сложность**. Если сделать наоборот, оптимальной игрой станет топтание на
/// первом уровне, и вся затея развалится молча — игра останется рабочей, но
/// перестанет тянуть вверх.
///
/// После смены набора механик заход стал ортогонален механике: он крутит
/// четыре ручки — вариантность, порог автоматизма, смещение к сложным
/// механикам, длину забега — и ни одна из них больше не привязана к тому,
/// какая именно механика попалась. Проверки ниже написаны так, чтобы это
/// свойство ломалось шумно.
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

    test('надбавка вариантов одинакова для всех механик', () {
      // Раньше число вариантов решала механика — узнавание 4, остальные 6, —
      // и один и тот же уровень захода означал для разных механик разную
      // вариантность: игрок не мог понять, от чего именно круг стал труднее.
      // Теперь вариантность приходит из плана, а заход добавляет к ней
      // число сверху. Проверка нужна именно потому, что заход этого не
      // видит: он не знает механики, и вернуть зависимость легко.
      // Что вариантность одинакова для всех механик, проверять больше нечем:
      // `defaultOptions` не принимает механику, и вернуть зависимость нельзя
      // без правки подписи. Осталось проверить то, что заход действительно
      // делает: не уменьшает число вариантов и растёт монотонно.
      var previous = ScoreBalance.defaultOptions();
      for (var level = 1; level <= 40; level++) {
        final extra = ClimbRules.difficultyFor(level).extraOptions;
        final options = ScoreBalance.defaultOptions(extra: extra);
        expect(options, greaterThanOrEqualTo(previous),
            reason: 'уровень $level: вариантов стало меньше');
        previous = options;
      }
    });

    test('заход не выводит круг за экранный потолок вариантов', () {
      // Шесть — предел не баланса, а экрана. Седьмой и восьмой заход
      // добавляет, и `extraOptionsMax` держится ровно на этом: если ручка
      // уползёт выше, круг перестанет читаться, и никакие очки этого не
      // оправдают.
      final ceiling = ScoreBalance.optionsMax + ClimbBalance.extraOptionsMax;
      for (var level = 1; level <= 100; level++) {
        final options = ScoreBalance.defaultOptions(extra: ClimbRules.difficultyFor(level).extraOptions,
        );
        expect(options, inInclusiveRange(ScoreBalance.optionsMin, ceiling),
            reason: 'уровень $level: $options вариантов');
      }
    });
  });

  group('награда против сложности', () {
    test('к пятому уровню шанс угадать падает медленнее, чем растут очки', () {
      // Оба множителя считаем относительно первого уровня и сравниваем.
      // Это и есть аркадный контракт: подниматься должно быть выгодно.
      //
      // Число вариантов берётся из `defaultOptions`, а не вписано в тест
      // шестёркой: иначе тест продолжил бы считать по старому базовому
      // числу и после того, как этап уровня начнёт двигать вариантность
      // сам.
      final optionsAtFirst = ScoreBalance.defaultOptions();
      for (var level = 2; level <= 9; level++) {
        final d = ClimbRules.difficultyFor(level);
        final guessPenalty =
            ScoreBalance.defaultOptions(extra: d.extraOptions) /
                optionsAtFirst;
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
        mode: GameMode.pickTarget,
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

    test('множитель захода умножает начисление в любой из шести механик', () {
      // Заход — надстройка над счётом, а не его часть: он не должен знать
      // механику. Пока механик было шесть прежних, это держалось на том, что
      // множитель захода стоит последним в произведении; проверки не было
      // ни у одной. Теперь механик снова шесть, и множители у них другие —
      // ошибка в одной ветке `modeMultiplier` иначе видна не была бы.
      //
      // Яркость 30 намеренно ниже [ScoreBalance.speedBonusMinLm]: на ней
      // скоростного множителя нет, и остаётся ровно то, что проверяется.
      for (final mode in GameMode.values) {
        ConnectionResult scoreWith(double climb) =>
            ScoreRules.scoreConnection(
              correct: true,
              latency: const Duration(milliseconds: 900),
              mode: mode,
              lumens: 30,
              combo: const ComboState(),
              climbMultiplier: climb,
            );

        final plain = scoreWith(1.0);
        expect(plain.score, greaterThan(0), reason: mode.name);
        expect(scoreWith(2.0).score, plain.score * 2, reason: mode.name);
      }
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

    test('заход не даёт очков там, где их не даёт механика', () {
      // Митигация «узнавание вместо владения» сильнее аркады: на ярком
      // слове узнавание не приносит очков ни на каком уровне.
      //
      // Непроизводящих механик теперь **две**: понимание проверяется и с
      // текста, и со слуха. Поэтому перечисляются не имена, а признак —
      // иначе третья такая механика появилась бы без проверки.
      final nonProductive =
          GameMode.values.where((m) => !m.isProductive).toList();
      expect(nonProductive, hasLength(2));

      for (final mode in nonProductive) {
        final result = ScoreRules.scoreConnection(
          correct: true,
          latency: const Duration(milliseconds: 500),
          mode: mode,
          lumens: 90,
          combo: const ComboState(),
          climbMultiplier: 3.0,
        );
        expect(result.score, 0, reason: mode.name);
      }
    });

    test('забег на уровне захода считает по его правилам', () {
      final run = RunScore(
        difficulty: ClimbRules.difficultyFor(5),
        climbMultiplier: ClimbRules.multiplierFor(5),
      );
      run.apply(
        correct: true,
        latency: const Duration(milliseconds: 500),
        mode: GameMode.pickTarget,
        lumens: 70,
      );
      final plain = RunScore()
        ..apply(
          correct: true,
          latency: const Duration(milliseconds: 500),
          mode: GameMode.pickTarget,
          lumens: 70,
        );
      expect(run.score, greaterThan(plain.score));
    });
  });

  group('чего заход не трогает', () {
    List<PlannedCircle> planAt(int level) => SessionPlanner.level(
          reviews: [
            for (var i = 0; i < 3; i++)
              StudyItem(itemId: 'old$i', tier: Tier.a1, lumens: 70),
          ],
          fresh: [
            for (var i = 0; i < 2; i++)
              StudyItem(
                itemId: 'new$i',
                tier: Tier.a1,
                lumens: 0,
                isNew: true,
              ),
          ],
          newWords: 2,
          reviewWords: 3,
          difficulty: ClimbRules.difficultyFor(level),
        );

    test('знакомство остаётся показом на любом уровне', () {
      // Один вариант — не поблажка, а показ: соединил, услышал, увидел
      // перевод. Проверять то, чего игрок ещё ни разу не видел, — способ
      // научить его, что игра непроходима, и никакой уровень захода этого
      // не оправдывает.
      //
      // Проверяемым это стало только теперь: вариантность едет в плане, а
      // не выводится из механики внутри сборщика вопросов, — и круг из
      // одного варианта наконец законен. Прежний сборщик возвращал `null`,
      // если не набралось двух дистракторов, и такой круг молча исчезал.
      for (final level in [1, 30]) {
        final firstShows = planAt(level).where((c) => c.isNew).toList();
        expect(firstShows, hasLength(2), reason: 'уровень $level');
        for (final circle in firstShows) {
          expect(circle.options, SessionBalance.introductionOptions,
              reason: 'уровень $level');
          expect(circle.options, ScoreBalance.optionsMin,
              reason: 'уровень $level');
          expect(circle.mode.isProductive, isFalse,
              reason: 'уровень $level: знакомство проверяет понимание');
        }
      }
    });

    test('вид дистракторов остаётся делом этапа, а не уровня', () {
      // Созвучные дистракторы — тоже сложность, но не та, которой
      // распоряжается заход: они уместны на проверке точности и вредны на
      // закреплении, и решает это этап уровня. Заход крутит четыре ручки,
      // и `distractorKind` среди них нет — раньше это было невыразимо,
      // потому что вид дистракторов был отдельным режимом («Тесный круг»),
      // и «поднять уровень» неизбежно означало бы «сменить механику».
      for (final circle in planAt(30)) {
        expect(circle.distractorKind, DistractorKind.far);
      }
    });
  });
}
