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
    test('множитель растёт вместе со сложностью режима', () {
      final ordered = [
        GameMode.recognition,
        GameMode.circle,
        GameMode.tight,
        GameMode.typing,
        GameMode.phrase,
      ];
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ScoreBalance.modeMultiplier(ordered[i]),
          greaterThan(ScoreBalance.modeMultiplier(ordered[i - 1])),
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
      // Иначе выгодно фармить лёгкий режим на уже выученном слове.
      expect(
        ScoreBalance.recognitionScoreCapLm,
        ScoreBalance.speedBonusMinLm,
      );
    });

    test('режимы на производство начинаются не ниже, чем узнавание кончается',
        () {
      final recognition = ScoreBalance.modeLumenRange(GameMode.recognition);
      final circle = ScoreBalance.modeLumenRange(GameMode.circle);
      expect(circle.min, lessThan(recognition.max));
      expect(circle.max, greaterThan(recognition.max));
    });

    test('диапазоны режимов заданы для всех шести и перекрываются', () {
      // Перекрытие обязательно: планировщик выбирает режим по яркости, и
      // на каждом значении 0–100 должен находиться хотя бы один режим.
      for (final lm in [0, 25, 45, 65, 85, 100]) {
        final fits = GameMode.values.where((m) {
          final r = ScoreBalance.modeLumenRange(m);
          return lm >= r.min && lm <= r.max;
        });
        expect(fits, isNotEmpty, reason: 'для $lm lm нет режима');
      }

      for (final mode in GameMode.values) {
        final r = ScoreBalance.modeLumenRange(mode);
        expect(r.min, lessThan(r.max), reason: '$mode: пустой диапазон');
        expect(r.min, greaterThanOrEqualTo(0));
        expect(r.max, lessThanOrEqualTo(100));
      }
    });

    test('узнавание — единственный режим не на производство', () {
      expect(
        GameMode.values.where((m) => !m.isProductive),
        [GameMode.recognition],
      );
    });

    test('множитель задан для всех режимов и не ниже единицы', () {
      for (final mode in GameMode.values) {
        expect(ScoreBalance.modeMultiplier(mode), greaterThanOrEqualTo(1.0),
            reason: '$mode');
      }
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
      // Шесть вариантов дают 17 % случайного попадания.
      expect(CalibrationBalance.borderConfirmations, greaterThan(1));
    });
  });
}
