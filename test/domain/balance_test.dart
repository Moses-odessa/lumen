import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

// Пайплайн — отдельная программа, и числа в нём дублируются намеренно.
// Импорт здесь нужен затем, чтобы дублирование проверялось, а не бралось на
// веру: путь относительный, потому что tool/ не пакет.
import '../../tool/content_schema.dart' as schema;

/// Тесты на константы баланса. Смысл не в том, чтобы «покрыть цифры», а в том,
/// чтобы зафиксировать связи между ними: если правка баланса ломает
/// договорённость из docs/CONCEPT.md, это должно быть видно сразу.
///
/// **Что здесь удалено вместе со словарным слоем.** Игра стала разговорником:
/// единица изучения — фраза, механик три, вариантов в круге всегда шесть.
/// Правила, которые охраняли перечисленные ниже тесты, не изменились — их
/// больше нет вовсе, поэтому тесты удалены, а не переписаны.
///
/// * «Круг из одного варианта законен» охранял `optionsMin = 1` и
///   `SessionBalance.introductionOptions`: знакомство было **показом** — один
///   вариант, соединил и услышал. Теперь знакомство устроено **исключением**:
///   вокруг новой фразы стоят пять уже известных, и неполный круг ломал бы
///   ровно это. Круг из одного варианта не «стал незаконен» — его нечем
///   выразить: числа вариантов как настройки не существует.
/// * «Число вариантов задаёт этап, а не механика» охранял `defaultOptions()`
///   против `optionsMax`. Вариантность перестала быть шкалой сложности:
///   `optionsMin`, `optionsMax` и `defaultOptions` удалены, осталась одна
///   константа [ScoreBalance.optionsPerCircle].
/// * «Заход добавляет варианты и не выходит за края» охранял
///   `ClimbBalance.extraOptionsMax`: заход прибавлял к кругу седьмой и
///   восьмой вариант. Ручка удалена целиком — заход повышает сложность
///   порогом «автоматизма» и смещением к трудным механикам.
/// * «Собрать фразу нельзя перебором» и «пропусков минимум два» охраняли
///   `phraseMinWords` и `phraseGapsMin`: из какого предложения можно вынуть
///   слова и сколько именно вынуть. Вставки слов в предложение в игре нет,
///   фраза заучивается целиком.
/// * «Глубина пропусков растёт по этапам» охранял `StageRules.gapsFor` —
///   ту же шкалу, что число вариантов, только на пропусках. Метода нет.
/// * Группа «пул пропуска фразы» (два теста) охраняла `phraseOptionsPerSlot`,
///   `phraseSlotMarkers` и `genderMarkers` из `tool/content_schema.dart`:
///   сколько неверных слов лежит у каждого слота и как по слову перед
///   пропуском определяется род. Неверные варианты больше не пишутся руками —
///   вокруг фразы стоят другие фразы, которые игрок уже знает, — и вместе с
///   рукописными дистракторами из пайплайна ушли все три сущности.
void main() {
  group('LumenBand', () {
    test('границы полос совпадают с таблицей яркости', () {
      expect(LumenBand.of(0), LumenBand.fading);
      expect(LumenBand.of(14), LumenBand.fading);
      expect(LumenBand.of(15), LumenBand.dimming);
      expect(LumenBand.of(34), LumenBand.dimming);
      expect(LumenBand.of(35), LumenBand.flickering);
      expect(LumenBand.of(59), LumenBand.flickering);
      expect(LumenBand.of(60), LumenBand.steady);
      expect(LumenBand.of(84), LumenBand.steady);
      expect(LumenBand.of(85), LumenBand.burning);
      expect(LumenBand.of(100), LumenBand.burning);
    });

    test('полосы идут по возрастанию яркости без разрывов', () {
      for (var i = 1; i < LumenBand.values.length; i++) {
        expect(
          LumenBand.values[i].minLm,
          greaterThan(LumenBand.values[i - 1].minLm),
        );
      }
    });
  });

  group('Tier', () {
    test('подъём и спуск ограничены краями', () {
      expect(Tier.a0.down, isNull);
      expect(Tier.b2.up, isNull);
      expect(Tier.a1.up, Tier.a2);
      expect(Tier.a1.down, Tier.a0);
    });

    test('неизвестный код не ломает игру, а даёт самый простой ярус', () {
      expect(Tier.fromCode('c1'), Tier.a0);
      expect(Tier.fromCode('b1'), Tier.b1);
    });
  });

  group('ScoreBalance', () {
    test('множитель растёт вместе со сложностью механики', () {
      // Порядок перечислен руками, а не взят из enum: enum идёт по букве из
      // docs (a–c), а дорожает игра иначе — узнать фразу по тексту дешевле
      // всего, узнать её на слух дороже, вспомнить и выбрать на изучаемом —
      // дороже всего.
      //
      // Верхушка лестницы опустела дважды: «Набор» (2.0) ушёл вместе с полем
      // ввода, фразовая сборка (2.2–2.5) — вместе с механикой вставки слов.
      // Поднимать `pickTarget` за ними не стали, и правильно: множитель
      // говорит, сколько требуется от игрока, а не сколько механик осталось.
      final ordered = [
        GameMode.pickNative,
        GameMode.listenNative,
        GameMode.pickTarget,
      ];
      // Иначе новая механика проехала бы мимо проверки: её просто не было бы
      // в списке, и порядок остался бы «упорядоченным».
      expect(ordered.toSet(), GameMode.values.toSet(),
          reason: 'механика без места в порядке цены');
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ScoreBalance.modeMultiplier(ordered[i]),
          greaterThan(ScoreBalance.modeMultiplier(ordered[i - 1])),
          reason: '${ordered[i].name} не дороже ${ordered[i - 1].name}',
        );
      }
    });

    test('пороги скорости упорядочены', () {
      expect(
        ScoreBalance.speedFastest,
        lessThan(ScoreBalance.speedFast),
      );
      expect(ScoreBalance.speedFast, lessThan(ScoreBalance.speedMedium));
      expect(ScoreBalance.kSpeedFastest, greaterThan(ScoreBalance.kSpeedFast));
      expect(ScoreBalance.kSpeedMedium, greaterThan(ScoreBalance.kSpeedSlow));
    });

    test('скоростной бонус не действует ниже порога «мерцания»', () {
      // Инвариант README: на новом материале таймера нет вообще.
      expect(
        ScoreBalance.speedBonusMinLm,
        greaterThanOrEqualTo(LumenBand.flickering.minLm),
      );
    });

    test('узнавание не приносит очков там, где начинается скоростной бонус',
        () {
      // Иначе выгодно фармить лёгкую механику на уже выученной фразе.
      //
      // Равенство стало нести второй смысл, и его стоит знать: два порога
      // зажимают вопрос на слух с двух сторон. Ниже 40 lm скоростного
      // множителя нет, от 40 lm нет очков — и правило «переслушивание снимает
      // скоростной множитель» не срабатывало бы никогда, если бы потолок
      // узнавания резал слух. Поэтому слух из-под потолка выведен, см.
      // `ScoreRules.scores`.
      expect(
        ScoreBalance.recognitionScoreCapLm,
        ScoreBalance.speedBonusMinLm,
      );
    });

    test('механики на производство включаются раньше, чем кончается узнавание',
        () {
      // Перекрытие, а не стык: без него есть яркость, на которой понимание
      // уже не ставится, а производство ещё не ставится, и планировщику
      // приходится выбирать механику вопреки своему же правилу.
      final pickNative = ScoreBalance.modeLumenRange(GameMode.pickNative);
      final pickTarget = ScoreBalance.modeLumenRange(GameMode.pickTarget);
      expect(pickTarget.min, lessThan(pickNative.max));
      expect(pickTarget.max, greaterThan(pickNative.max));
    });

    test('диапазоны заданы для всех трёх механик и накрывают всю шкалу', () {
      // Перекрытие обязательно: планировщик выбирает механику по яркости, и
      // на каждом значении 0–100 должна находиться хотя бы одна. Дырка
      // означала бы фразу, которую нечем спросить: планировщик уходит в
      // запасную механику, и этап уровня перестаёт что-либо решать.
      //
      // Раньше в подсчёт шли только механики на слово: фразовые накрывали всю
      // шкалу не потому, что уместны везде, а потому, что яркость одного
      // слова к ним неприменима. Отдельного слова в игре нет, все три
      // механики спрашивают фразу, и делить набор больше не на что.
      for (var lm = 0; lm <= 100; lm++) {
        final fits = GameMode.values.where((m) {
          final r = ScoreBalance.modeLumenRange(m);
          return lm >= r.min && lm <= r.max;
        });
        expect(fits, isNotEmpty, reason: 'для $lm lm нет ни одной механики');
      }

      for (final mode in GameMode.values) {
        final r = ScoreBalance.modeLumenRange(mode);
        expect(r.min, lessThan(r.max), reason: '$mode: пустой диапазон');
        expect(r.min, greaterThanOrEqualTo(0));
        expect(r.max, lessThanOrEqualTo(100));
      }
    });

    test('чем дороже механика, тем позже она включается', () {
      // На этом согласии держится правило планировщика «из подходящих берём
      // самую требовательную»: он читает свой список по порядку и берёт
      // последнюю подходящую. Разойдись цена с диапазоном — и за самую
      // сложную он начнёт выдавать ту, что просто стоит ниже в списке.
      final byPrice = GameMode.values.toList()
        ..sort((a, b) => ScoreBalance.modeMultiplier(a)
            .compareTo(ScoreBalance.modeMultiplier(b)));
      for (var i = 1; i < byPrice.length; i++) {
        final cheaper = ScoreBalance.modeLumenRange(byPrice[i - 1]);
        final dearer = ScoreBalance.modeLumenRange(byPrice[i]);
        expect(dearer.min, greaterThan(cheaper.min),
            reason: '${byPrice[i].name} дороже, но начинается не позже');
        // Конец диапазона проверяется нестрого: у двух дорогих механик он
        // общий — потолок неба. Вопрос на слух остался в игре один и обязан
        // доставать до самых ярких звёзд, иначе выученная фраза больше никогда
        // не звучит вопросом. Планировщику достаточно порядка начал: где
        // подходят обе, он берёт стоящую дальше в своём списке, то есть
        // дорогую.
        expect(dearer.max, greaterThanOrEqualTo(cheaper.max),
            reason: '${byPrice[i].name} дороже, но кончается раньше');
      }
    });

    // Тест «узнавание — единственный режим не на производство» удалён:
    // гарантии больше нет ни в одной форме. Понимание проверяется двумя
    // механиками — с текста (pickNative) и со слуха (listenNative), — так что
    // «единственный» стало неверным утверждением, а не сломанным тестом.
    // Ниже стоит проверка нового, уже двухэлементного набора.
    test('на производство работает одна механика из трёх', () {
      // Набор обязан быть закрытым списком, а не «всё, что не перечислено»:
      // правило «горящей фразы» считается только в продуктивных механиках, и
      // механика, случайно оказавшаяся продуктивной, начнёт закрывать фразу
      // как выученную на одном узнавании.
      expect(
        GameMode.values.where((m) => !m.isProductive).toSet(),
        {GameMode.pickNative, GameMode.listenNative},
      );
    });

    test('множитель задан для всех механик и не ниже единицы', () {
      for (final mode in GameMode.values) {
        expect(ScoreBalance.modeMultiplier(mode), greaterThanOrEqualTo(1.0),
            reason: '$mode');
      }
    });

    test('повторов уровня хватает, чтобы окружить новую фразу известными', () {
      // Знакомство работает исключением: вокруг новой фразы стоят пять уже
      // известных, и игрок понимает, какая шестая, потому что остальные пять
      // узнаёт. Известные приходят только из материала сессии — загрузчик
      // отбирает их среди повторов по яркости, — поэтому повторов на уровне
      // обязано быть не меньше, чем мест вокруг центра.
      //
      // Меньше — и пул добирается незнакомыми фразами яруса: игрок выбирает из
      // шести чужих строчек, «сообразить» превращается в «угадать», а сломается
      // это тихо, потому что круг соберётся и покажется как обычный.
      expect(
        SessionBalance.reviewsPerLevel,
        greaterThanOrEqualTo(ScoreBalance.optionsPerCircle - 1),
      );
    });

    test('известной для исключения фраза становится, едва её начали узнавать',
        () {
      // Порог — нижняя граница полосы «узнаёте, но не вспоминаете сами», и для
      // исключения этого достаточно: узнать пять знакомых строчек легче, чем
      // вспомнить любую из них. Требовать уверенного знания значило бы, что на
      // первых уровнях исключать не из чего.
      expect(
        ScoreBalance.knownForEliminationLm,
        LumenBand.flickering.minLm,
      );
      // И порог обязан оставаться не выше засева калибровки: подтверждённые на
      // тесте фразы — это весь запас известного у игрока, который только что
      // прошёл онбординг. Подними порог над засевом, и первый же круг
      // окажется выбором из шести незнакомых у человека, который свой ярус
      // только что доказал.
      expect(
        ScoreBalance.knownForEliminationLm,
        lessThanOrEqualTo(CalibrationBalance.seedLmMin),
      );
    });

    test('окно на ответ длиннее самого медленного порога, который ещё платит',
        () {
      // Просрочка — это ответ «не вспомнил»: фраза тускнеет и возвращается в
      // очередь. Значит окно решает, какие исходы вообще существуют.
      //
      // Штрафа за медленность нет: ответ медленнее [ScoreBalance.speedMedium]
      // приносит множитель 1.0, но приносит. Окно короче этого порога отменило
      // бы обещание молча — «медленный верный ответ» перестал бы существовать
      // как исход, любой такой круг закрывался бы просрочкой.
      expect(
        ScoreBalance.answerWindow,
        greaterThan(ScoreBalance.speedMedium),
      );
      // Та же мысль со стороны памяти: FSRS обязан уметь получить «трудно» от
      // игрока, который вспомнил с усилием, а не только «не вспомнил» от того,
      // кто не успел.
      expect(
        ScoreBalance.answerWindow,
        greaterThan(SrsBalance.gradeGoodBelow),
      );
    });
  });

  group('RevealBalance', () {
    test('пауза после ответа зависит от исхода, а не от механики', () {
      // На верном ответе читать нечего — подсветка и озвучка. На ошибке и на
      // просроченном окне надо успеть увидеть и услышать верный вариант, иначе
      // промах ничему не учит; просрочка — тот же промах, и пауза у неё та же.
      expect(RevealBalance.wrong, greaterThan(RevealBalance.correct),
          reason: 'верный вариант не успеть прочитать');

      // Прежде значений было четыре: два лишних держали перевод и озвучку
      // целого предложения на фразовой сборке. Механики нет, значений нет, а
      // `forMode` осталась ровно потому, что оба пути игры — забег и
      // калибровка — обязаны спрашивать паузу в одном месте. Пока 420 мс и
      // 1100 мс лежали внутри `RunController`, у калибровки не было **никакой**
      // паузы: два пути разошлись молча.
      final byMode = {
        for (final mode in GameMode.values)
          (
            RevealBalance.forMode(mode, correct: true),
            RevealBalance.forMode(mode, correct: false),
          ),
      };
      expect(byMode, hasLength(1),
          reason: 'механика снова начала решать длину паузы');
    });
  });

  group('ProgressionBalance', () {
    // Таблицы накопительных размеров созвездия (12/24/48/72/96), фраз и
    // уровней здесь больше нет, и тесты на них удалены вместе с ней. Они
    // проверяли константу саму с собой: что 12 меньше 24, что 96 = 32×3, что
    // 16×6 = 96. Ни один из них не мог упасть иначе как от правки той же
    // таблицы, и ни один не сказал бы, разошлась ли она с контентом. А она
    // разошлась: баланс обещал 4/8/16/24/32 фразы на созвездие, в контенте
    // лежало 4/8/12/12/12, и никто этого не заметил.
    //
    // Осталось одно правило и один порог — и оба проверяются против чего-то
    // внешнего, а не против себя.

    test('порог появления созвездия одинаков в приложении и в пайплайне', () {
      // Число дублируется намеренно: tool/ — отдельная программа и не тянет
      // за собой lib/. Дублирование без проверки — это два правила, которые
      // однажды начнут означать разное.
      expect(
        ProgressionBalance.minStarsForConstellation,
        schema.minStarsForConstellation,
      );
    });

    test('порог появления больше единицы и меньше уровня', () {
      // Созвездие из одной звезды — точка, а не созвездие. Но порог выше
      // размера уровня означал бы тему, которую нельзя пройти за один
      // подход, ещё до того как она появилась.
      expect(ProgressionBalance.minStarsForConstellation, greaterThan(1));
      expect(
        ProgressionBalance.minStarsForConstellation,
        lessThanOrEqualTo(SessionBalance.newWordsPerLevel * 2),
      );
    });

    test('порог «зажжено» выше порога открытия соседей', () {
      // Иначе соседние созвездия откроются позже, чем текущее зажжётся.
      expect(
        ProgressionBalance.litStarMinLm,
        greaterThan(ProgressionBalance.unlockNeighborsAvgLm),
      );
    });
  });

  group('SessionBalance', () {
    test('уровень собирается из повторов вдвое чаще, чем из новых фраз', () {
      expect(
        SessionBalance.reviewsPerLevel,
        SessionBalance.newWordsPerLevel * 2,
      );
    });

    test('пул сессии вмещает весь уровень', () {
      expect(
        SessionBalance.sessionPoolSize,
        greaterThanOrEqualTo(
          SessionBalance.newWordsPerLevel + SessionBalance.reviewsPerLevel,
        ),
      );
    });
  });

  group('RetentionBalance', () {
    test('орбита сбрасывается не раньше третьего пропуска', () {
      // Главная боль Duolingo: страх потерять полгода из-за одного перелёта.
      expect(RetentionBalance.orbitResetAfterMisses, greaterThanOrEqualTo(3));
    });

    test('недельная цель оставляет законные выходные', () {
      expect(RetentionBalance.weeklyGoalDays, lessThan(7));
    });
  });

  group('CalibrationBalance', () {
    test('гребёнка проходит по всем ярусам', () {
      expect(CalibrationBalance.combStepsMax, Tier.values.length);
    });

    test('засев яркости — не с нуля, но и не как у выученной фразы', () {
      // Подтверждённая фраза должна попасть в очередь повторений, а не
      // считаться горящей: полоса между «мерцает» и «ровный свет».
      expect(
        LumenBand.of(CalibrationBalance.seedLmMin),
        LumenBand.flickering,
      );
      expect(
        LumenBand.of(CalibrationBalance.seedLmMax),
        LumenBand.steady,
      );
      expect(
        CalibrationBalance.seedLmMin,
        lessThan(CalibrationBalance.seedLmMax),
      );
    });

    test('подтвердить границу труднее, чем подняться ярусом выше', () {
      // Круг из [ScoreBalance.optionsPerCircle] вариантов даёт 17 %
      // случайного попадания: одного подтверждения мало, чтобы отличить знание
      // от тыка.
      expect(CalibrationBalance.borderConfirmations, greaterThan(1));
      // Но главное — цена: два верных подряд поднимают пробу ярусом выше, а
      // подтверждения **заканчивают тест** и назначают игроку ярус на всё
      // дальнейшее. Сравняй их, и калибровка будет заканчиваться там же, где
      // прежде просто делала шаг вверх, — то есть на первой же удачной паре.
      //
      // Прежде рядом стояло второе требование: хотя бы одно подтверждение
      // «тесным кругом», на созвучных вариантах. Рукописных дистракторов в
      // игре нет, тесного круга как отдельного вида круга не существует, и
      // осталось только число — тем важнее, чтобы оно было чем-то подпёрто.
      expect(
        CalibrationBalance.borderConfirmations,
        greaterThan(CalibrationBalance.correctToRise),
      );
    });
  });
}
