import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

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
    test('созвездие растёт с ярусом и не сжимается', () {
      for (var i = 1; i < Tier.values.length; i++) {
        expect(
          ProgressionBalance.starsPerConstellation(Tier.values[i]),
          greaterThan(
            ProgressionBalance.starsPerConstellation(Tier.values[i - 1]),
          ),
        );
      }
    });

    test('размеры совпадают с таблицей прогрессии', () {
      expect(ProgressionBalance.starsPerConstellation(Tier.a0), 12);
      expect(ProgressionBalance.starsPerConstellation(Tier.b2), 96);
    });

    test('порог «зажжено» выше порога открытия соседей', () {
      // Иначе соседние созвездия откроются позже, чем текущее зажжётся.
      expect(
        ProgressionBalance.litStarMinLm,
        greaterThan(ProgressionBalance.unlockNeighborsAvgLm),
      );
    });

    test('фразы и уровни растут вместе со звёздами', () {
      for (var i = 1; i < Tier.values.length; i++) {
        final prev = Tier.values[i - 1];
        final tier = Tier.values[i];
        expect(
          ProgressionBalance.phrasesPerConstellation(tier),
          greaterThan(ProgressionBalance.phrasesPerConstellation(prev)),
          reason: '$tier: фраз не больше, чем на $prev',
        );
        expect(
          ProgressionBalance.levelsPerConstellation(tier),
          greaterThan(ProgressionBalance.levelsPerConstellation(prev)),
          reason: '$tier: уровней не больше, чем на $prev',
        );
      }
    });

    test('на каждые три звезды приходится примерно одна фраза', () {
      // Соотношение из таблицы прогрессии: 12/4, 24/8, 48/16, 72/24, 96/32.
      for (final tier in Tier.values) {
        expect(
          ProgressionBalance.starsPerConstellation(tier),
          ProgressionBalance.phrasesPerConstellation(tier) * 3,
          reason: '$tier',
        );
      }
    });

    test('каждый уровень закрывает шесть звёзд созвездия', () {
      // Уровни, как и звёзды, величина накопительная: 12/2, 24/4, 48/8,
      // 72/12, 96/16 — ровно по шесть новых слов на уровень. Если правка
      // баланса разойдётся с этим, созвездие перестанет проходиться нацело.
      for (final tier in Tier.values) {
        expect(
          ProgressionBalance.levelsPerConstellation(tier) *
              SessionBalance.newWordsPerLevel,
          ProgressionBalance.starsPerConstellation(tier),
          reason: '$tier: звёзды не делятся на уровни по '
              '${SessionBalance.newWordsPerLevel}',
        );
      }
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
