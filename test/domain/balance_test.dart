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
      // docs (a–f), а дорожает игра иначе — понять на слух дешевле, чем
      // выбрать форму на изучаемом. Прежняя верхушка «Набор» (2.0) удалена
      // вместе с полем ввода, и её место занял buildPhrase.
      final ordered = [
        GameMode.pickNative,
        GameMode.listenNative,
        GameMode.pickTarget,
        GameMode.listenTarget,
        GameMode.fillGaps,
        GameMode.buildPhrase,
      ];
      // Иначе седьмая механика проехала бы мимо проверки: её просто не было
      // бы в списке, и порядок остался бы «упорядоченным».
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
      // Иначе выгодно фармить лёгкую механику на уже выученном слове.
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

    test('диапазоны механик заданы для всех шести и перекрываются', () {
      // Перекрытие обязательно: планировщик выбирает механику по яркости, и
      // на каждом значении 0–100 должна находиться хотя бы одна.
      //
      // В подсчёт идут только механики на слово. Фразовые накрывают всю шкалу
      // не потому, что уместны везде, а потому, что яркость одного слова к
      // ним неприменима: их ставит этап уровня. Пусти их сюда — и проверка
      // станет тавтологией «шкала накрыта, потому что fillGaps накрывает
      // всё», а дырку между механиками на слово перестанет ловить.
      final wordModes = GameMode.values.where((m) => m.isWordMode);
      for (var lm = 0; lm <= 100; lm++) {
        final fits = wordModes.where((m) {
          final r = ScoreBalance.modeLumenRange(m);
          return lm >= r.min && lm <= r.max;
        });
        expect(fits, isNotEmpty, reason: 'для $lm lm нет механики на слово');
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
      final byPrice = GameMode.values.where((m) => m.isWordMode).toList()
        ..sort((a, b) => ScoreBalance.modeMultiplier(a)
            .compareTo(ScoreBalance.modeMultiplier(b)));
      for (var i = 1; i < byPrice.length; i++) {
        final cheaper = ScoreBalance.modeLumenRange(byPrice[i - 1]);
        final dearer = ScoreBalance.modeLumenRange(byPrice[i]);
        expect(dearer.min, greaterThan(cheaper.min),
            reason: '${byPrice[i].name} дороже, но начинается не позже');
        expect(dearer.max, greaterThan(cheaper.max),
            reason: '${byPrice[i].name} дороже, но кончается не позже');
      }
    });

    // Тест «узнавание — единственный режим не на производство» удалён:
    // гарантии больше нет ни в одной форме. Понимание теперь проверяется
    // двумя механиками — с текста (pickNative) и со слуха (listenNative), —
    // так что «единственный» стало неверным утверждением, а не сломанным
    // тестом; вместе с ним ушёл и сам GameMode.recognition, чьё имя тест
    // называл. Ниже стоит проверка нового, уже двухэлементного набора.
    test('на производство работают все механики, кроме двух на понимание', () {
      // Набор обязан быть закрытым списком, а не «всё, что не перечислено»:
      // правило «горящего слова» считается только в продуктивных механиках, и
      // механика, случайно оказавшаяся продуктивной, начнёт закрывать слово
      // как выученное на одном узнавании.
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

    test('круг из одного варианта законен', () {
      // Раньше минимумом было три варианта: сборщик возвращал null, если не
      // набралось двух дистракторов, и такой круг молча исчезал из уровня.
      // Знакомство с новым словом устроено ровно на одном варианте —
      // соединил, услышал, увидел перевод. Вернись минимум к двум, и
      // знакомство исчезнет так же тихо, как исчезали те круги.
      expect(ScoreBalance.optionsMin, 1);
      expect(
        SessionBalance.introductionOptions,
        greaterThanOrEqualTo(ScoreBalance.optionsMin),
      );
      expect(
        SessionBalance.introductionOptions,
        lessThan(ScoreBalance.defaultOptions()),
        reason: 'знакомство — показ, а не проверка: вариантов должно быть '
            'меньше, чем в обычном круге',
      );
    });

    test('число вариантов задаёт этап, а не механика', () {
      // Раньше решала механика: узнавание 4, остальные 6, набор 0. Отсюда
      // росла невозможность попросить «то же самое, но легче» — этап уровня
      // мог менять сложность только сменой механики. Начни механика решать
      // это снова, и вариантность перестанет быть шкалой.
      // Проверять «одинаково ли для всех механик» больше нечем и незачем:
      // `defaultOptions` не принимает механику вовсе, и попытка вернуть
      // зависимость не пройдёт компиляцию. Это сильнее теста.
      //
      // Сначала здесь стояла подпись `optionsFor(GameMode mode, {int extra})`
      // с неиспользуемым аргументом — «на будущее». Она обещала зависимость,
      // которой не было, и тест против неё проверял бы воображаемое
      // поведение. Осталось то, что остаётся проверять: число не ниже
      // минимума, не выше потолка и растёт от захода.
      expect(ScoreBalance.defaultOptions(), ScoreBalance.optionsMax);
      expect(ScoreBalance.defaultOptions(),
          greaterThanOrEqualTo(ScoreBalance.optionsMin));
    });

    test('заход добавляет варианты и не выходит за края', () {
      // Единственный способ снизить шанс угадать, не меняя ни механику, ни
      // материал. Потолок при этом обязан остаться: восьмой вариант в круге
      // читается уже плохо, и предел здесь экранный, а не балансный.
      expect(ClimbBalance.extraOptionsMax, greaterThan(0));
      var previous = ScoreBalance.defaultOptions();
      for (var extra = 1; extra <= ClimbBalance.extraOptionsMax; extra++) {
        final current =
            ScoreBalance.defaultOptions(extra: extra);
        expect(current, greaterThan(previous), reason: 'заход +$extra не дал');
        previous = current;
      }
      expect(
        previous,
        ScoreBalance.optionsMax + ClimbBalance.extraOptionsMax,
        reason: 'потолок обрезал прибавку захода',
      );
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
    test('уровень собирается из повторов вдвое чаще, чем из новых слов', () {
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

    test('собрать фразу нельзя перебором', () {
      // Из трёх слов перестановок шесть, и по-немецки допустима не одна из
      // них: задание проходится тыком, а не памятью, и тогда оно не проверяет
      // ничего. Четыре слова дают 24 порядка — там уже надо вспоминать.
      expect(SessionBalance.buildPhraseMinWords, greaterThan(3));
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

    test('засев яркости — не с нуля, но и не как у выученного слова', () {
      // Подтверждённое слово должно попасть в очередь повторений, а не
      // считаться горящим: полоса между «мерцает» и «ровный свет».
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

    test('граница яруса подтверждается больше одного раза', () {
      // Круг из ScoreBalance.optionsMax вариантов даёт 17 % случайного
      // попадания: одного подтверждения мало, чтобы отличить знание от тыка.
      expect(CalibrationBalance.borderConfirmations, greaterThan(1));
    });
  });

  group('пул пропуска фразы', () {
    test('своих слов ровно столько, чтобы добор не начался', () {
      // Запас нулевой, и это надо знать. Сборщик ограничивает пул величиной
      // `optionsMax + extraOptionsMax` и сперва кладёт в него ответы, поэтому
      // на слот остаётся ровно `phraseOptionsPerSlot` неверных слов. При
      // семи добор `far`-дистракторами и соседями по теме не начинается
      // никогда.
      //
      // Поднять `extraOptionsMax` до трёх — и добор включится, а вместе с ним
      // вернутся находки первого раунда вычитки A0: `far` у `right_adv` это
      // `[links, geradeaus]`, то есть «Gehen Sie nach links», а у
      // `hunger_noun` — `[Durst, Appetit]`, то есть «Ich habe großen Durst».
      // Оба предложения правильные, и оба игра объявит неверными.
      //
      // Тест поэтому не «проверяет число», а держит зависимость: правка
      // баланса обязана сопровождаться правкой контента, и узнать об этом
      // нужно здесь, а не от игрока.
      expect(
        schema.phraseOptionsPerSlot,
        ScoreBalance.optionsMax + ClimbBalance.extraOptionsMax - 1,
        reason: 'после правки баланса у каждой фразы запущенного яруса надо '
            'дописать неверные слова: dart run tool/validate_content.dart '
            'покажет, у каких',
      );
    });

    test('слово перед пропуском находится', () {
      // От этого зависит, какую из двух проверок применять к фразе: рамка с
      // артиклем отсеивает вариант несовпадением рода, безартиклевая —
      // требованием артикля у исчисляемого.
      expect(
        schema.phraseSlotMarkers('Wo ist die {post}?'),
        ['die'],
      );
      expect(
        schema.phraseSlotMarkers('Ich habe seit gestern {pain}.'),
        ['gestern'],
      );
      expect(
        schema.phraseSlotMarkers('Ich {want} einen Termin {book}.'),
        ['ich', 'termin'],
      );
      expect(schema.phraseSlotMarkers('{word} ist da.'), ['']);

      expect(schema.genderMarkers.contains('die'), isTrue);
      expect(schema.genderMarkers.contains('zur'), isTrue,
          reason: 'предлог, слипшийся с артиклем, задаёт род не хуже артикля');
      expect(schema.genderMarkers.contains('gestern'), isFalse);
    });
  });
}
