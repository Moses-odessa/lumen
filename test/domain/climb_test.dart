import 'dart:math';

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
/// Заход ортогонален механике: он крутит три ручки — порог автоматизма,
/// смещение к трудным механикам, длину забега — и ни одна из них не привязана
/// к тому, какая именно механика попалась. Проверки ниже написаны так, чтобы
/// это свойство ломалось шумно.
///
/// **Что здесь удалено вместе с четвёртой ручкой.** Вариантности у захода
/// больше нет: вариантов в круге всегда шесть, потому что на полном круге
/// держится знакомство методом исключения — вокруг новой фразы стоят пять уже
/// известных.
///
/// * «Надбавка вариантов растёт монотонно» охранял `extraOptions` против
///   `ScoreBalance.defaultOptions(extra:)`: заход прибавлял к кругу седьмой и
///   восьмой вариант, и требовалось, чтобы прибавка не убывала.
/// * «Заход не выводит круг за экранный потолок вариантов» охранял
///   `ClimbBalance.extraOptionsMax`: восьмой вариант читается уже плохо, и
///   предел там был экранный, а не балансный.
/// * «Вид дистракторов остаётся делом этапа, а не уровня» охранял
///   `PlannedCircle.distractorKind`: тематические против созвучных — сложность,
///   которой распоряжается этап, а не заход. Рукописных неверных вариантов в
///   игре нет вовсе, вокруг фразы стоят другие фразы, и `DistractorKind`
///   удалён вместе с ними.
///
/// Переписать их на новое правило нельзя: «заход не трогает вариантность»
/// стало истиной по построению — числа вариантов как настройки не существует,
/// и вернуть зависимость нельзя без правки подписей в `lib/`. Тест, который
/// невозможно сломать, — это отсутствующий тест.
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
      expect(d.speedFastest, ScoreBalance.speedFastest);
      expect(d.modeDraws, ClimbBalance.modeDrawsBase);
      expect(d.circlesPerRun, SessionBalance.circlesPerRunMin);
    });

    test('все три ручки монотонны', () {
      // Аркада ломается не когда сложно, а когда сложность прыгает
      // туда-сюда: игрок перестаёт понимать, стало ли труднее.
      var previous = ClimbRules.difficultyFor(1);
      for (var level = 2; level <= 30; level++) {
        final next = ClimbRules.difficultyFor(level);
        expect(next.speedFastest, lessThanOrEqualTo(previous.speedFastest));
        expect(next.modeDraws, greaterThanOrEqualTo(previous.modeDraws));
        expect(next.circlesPerRun,
            greaterThanOrEqualTo(previous.circlesPerRun));
        previous = next;
      }
    });

    test('каждая ручка упирается в свой потолок', () {
      final far = ClimbRules.difficultyFor(100);
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
    test('награда обгоняет единственную ручку, которая её отбирает', () {
      // Аркадный контракт: подниматься должно быть выгодно. Иначе оптимальной
      // игрой станет топтание на первом уровне.
      //
      // Прежде здесь сравнивался шанс угадать: заход добавлял к кругу седьмой
      // и восьмой вариант, и надбавка была настоящей помехой. Вариантности у
      // захода больше нет, и сравнивать стало с чем одним — с порогом
      // «автоматизма». Из трёх ручек только он **отбирает** уже привычную
      // награду: длина забега платит за себя кругами, а смещение к трудным
      // механикам поднимает множитель механики, то есть тоже платит.
      //
      // Поэтому сложность здесь — во сколько раз труднее стало дотянуться до
      // максимального скоростного множителя, а награда — множитель уровня.
      for (var level = 2; level <= 30; level++) {
        final d = ClimbRules.difficultyFor(level);
        final speedPenalty = ScoreBalance.speedFastest.inMicroseconds /
            d.speedFastest.inMicroseconds;
        final reward = ClimbRules.multiplierFor(level);
        expect(reward, greaterThan(speedPenalty),
            reason: 'уровень $level: награда ×$reward против сложности '
                '×${speedPenalty.toStringAsFixed(2)}');
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

    test('множитель захода умножает начисление в любой из трёх механик', () {
      // Заход — надстройка над счётом, а не его часть: он не должен знать
      // механику. Держится это на том, что множитель захода стоит последним в
      // произведении, и проверки не было ни у одной механики, пока их было
      // шесть. Механик стало три, множители у них другие — ошибка в одной
      // ветке `modeMultiplier` иначе видна не была бы.
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
      // Перечисляется не имя, а признак — «механика, которой на этой яркости
      // не платят», — иначе следующая такая появилась бы без проверки.
      // Признак этот больше не совпадает с «непроизводящая»: вопрос на слух
      // непроизводящий, но потолок узнавания его не режет, потому что
      // написание на слух не показывают.
      final unpaid = GameMode.values
          .where((m) => !ScoreRules.scores(m, 90))
          .toList();
      expect(unpaid, [GameMode.pickNative]);

      for (final mode in unpaid) {
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
    // Заход передаётся сюда целиком, и `Random` передаётся тоже: без него
    // смещение к трудным механикам не работает вовсе — выбор берёт последнюю
    // подходящую и никаких попыток не делает. Тогда план первого уровня и
    // план тридцатого совпали бы, и «на любом уровне» ниже проверяло бы одно
    // и то же дважды.
    List<PlannedCircle> planAt(int level) => [
          for (final run in SessionPlanner.level(
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
            random: Random(1),
            difficulty: ClimbRules.difficultyFor(level),
          ))
            ...run.circles,
        ];

    test('знакомство спрашивает понимание на любом уровне', () {
      // Требовать произвести фразу, которую игрок ещё ни разу не видел, —
      // способ научить его, что игра непроходима, и никакой уровень захода
      // этого не оправдывает. Ручка, которой заход мог бы это сломать,
      // настоящая: смещение к трудным механикам берёт лучшую из N случайных
      // попыток, и на тридцатом уровне попыток впятеро больше, чем на первом.
      //
      // Прежде тест говорил про один вариант в круге — знакомство было
      // показом. Теперь оно устроено исключением: круг полный, вокруг новой
      // фразы стоят пять уже известных, и «не проверять» означает не механику
      // на производство, а отсутствие окна на ответ. Оба свойства ниже.
      for (final level in [1, 30]) {
        final firstShows = planAt(level).where((c) => c.isNew).toList();
        expect(firstShows, hasLength(2), reason: 'уровень $level');
        for (final circle in firstShows) {
          expect(circle.mode.isProductive, isFalse,
              reason: 'уровень $level: знакомство проверяет понимание');
        }
      }
    });

    test('окна на ответ у знакомства нет ни на каком уровне', () {
      // Пять секунд на ответ — правило забега, но чтобы прийти к ответу
      // исключением, игроку надо прочитать пять знакомых строчек. Торопить его
      // в этот момент значит требовать угадать, а не сообразить. Флаг [isNew]
      // — единственное, по чему `RunController` узнаёт такой круг, и ставит
      // его планировщик, а не заход.
      for (final level in [1, 30]) {
        final circles = planAt(level);
        expect(circles.where((c) => c.isNew).map((c) => c.itemId).toSet(),
            {'new0', 'new1'}, reason: 'уровень $level');
        // И только знакомство: второй и третий показ той же фразы стоят на
        // закреплении и проверке, и там окно уже есть — иначе новая фраза
        // проходила бы весь уровень без таймера.
        expect(
          circles.where((c) => c.itemId.startsWith('new') && !c.isNew),
          isNotEmpty,
          reason: 'уровень $level: новая фраза нигде не спрашивается с окном',
        );
      }
    });
  });
}
