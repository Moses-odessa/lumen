import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/scheduler/level_stage.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/domain/scoring/score.dart';

/// Тесты на этапы уровня.
///
/// Смысл этапов в том, что «насколько трудно» отделено от «какие слова». Все
/// проверки ниже про первое: второе решает яркость по FSRS, и путать их
/// нельзя — иначе либо сложность перестаёт расти, либо слова перестают
/// повторяться вовремя.
void main() {
  group('вариантность по этапам', () {
    test('знакомство — один вариант, и заход этого не меняет', () {
      // Один вариант это отказ от проверки: выбирать не из чего, и круг
      // превращается в показ. Надбавка захода к нему не применяется — иначе
      // с четвёртого уровня первый в жизни показ слова становился бы
      // выбором из двух.
      for (final extra in [0, 1, 2, 5]) {
        expect(
          StageRules.optionsFor(LevelStage.introduction, extra: extra),
          SessionBalance.introductionOptions,
          reason: 'надбавка $extra просочилась в показ',
        );
      }
      expect(SessionBalance.introductionOptions, ScoreBalance.optionsMin);
    });

    test('дальше вариантов больше, чем на показе', () {
      for (final stage in LevelStage.values) {
        if (stage.isShowing) continue;
        expect(
          StageRules.optionsFor(stage),
          greaterThan(SessionBalance.introductionOptions),
          reason: '${stage.name} остался показом',
        );
      }
    });

    test('проверка спрашивает жёстче закрепления', () {
      // Между ними и лежит вся идея этапов: сначала вспомнить значение,
      // потом различить оттенок.
      expect(
        StageRules.optionsFor(LevelStage.check),
        greaterThan(StageRules.optionsFor(LevelStage.consolidation)),
      );
      expect(
        StageRules.distractorFor(LevelStage.check),
        DistractorKind.near,
      );
      expect(
        StageRules.distractorFor(LevelStage.consolidation),
        DistractorKind.far,
      );
    });

    test('заход не выводит этап за экранный потолок', () {
      for (var level = 1; level <= 100; level++) {
        final extra = ClimbRules.difficultyFor(level).extraOptions;
        for (final stage in LevelStage.values) {
          final options = StageRules.optionsFor(stage, extra: extra);
          expect(
            options,
            inInclusiveRange(
              ScoreBalance.optionsMin,
              ScoreBalance.optionsMax + ClimbBalance.extraOptionsMax,
            ),
            reason: '${stage.name} на уровне $level: $options вариантов',
          );
        }
      }
    });
  });

  group('механики по этапам', () {
    test('знакомство спрашивает только на понимание', () {
      // Слово только что показали; требовать воспроизведения рано.
      final allowed = StageRules.mechanicsFor(LevelStage.introduction)!;
      expect(allowed.every((m) => !m.isProductive), isTrue,
          reason: 'на знакомстве требуют произвести форму');
    });

    test('проверка спрашивает только на производство', () {
      final allowed = StageRules.mechanicsFor(LevelStage.check)!;
      expect(allowed.every((m) => m.isProductive), isTrue);
    });

    test('напоминание не сужает набор', () {
      // Слова здесь разной яркости, и выбор механики — работа планировщика,
      // а не расписания.
      expect(StageRules.mechanicsFor(LevelStage.reminder), isNull);
    });

    test('фразовые механики этап не назначает', () {
      // Их материал — предложение, а не звезда: ставятся они отдельно.
      for (final stage in LevelStage.values) {
        final allowed = StageRules.mechanicsFor(stage);
        if (allowed == null) continue;
        expect(allowed.any((m) => m.isPhrase), isFalse,
            reason: '${stage.name} назначает фразовую механику словам');
      }
    });

    test('каждый этап оставляет хоть одну механику без звука', () {
      // Иначе в беззвучном режиме этап нечем показать, и планировщику
      // остаётся только запасной вариант — то есть этап перестаёт работать.
      for (final stage in LevelStage.values) {
        final allowed = StageRules.mechanicsFor(stage);
        if (allowed == null) continue;
        expect(allowed.any((m) => !m.needsAudio), isTrue,
            reason: '${stage.name} только на слух');
      }
    });
  });

  group('цена этапа', () {
    test('показ дешевле проверки, но не бесплатен', () {
      // Ноль означал бы, что первые шесть кругов уровня не считаются игрой,
      // — а это те самые круги, где человек впервые видит слово.
      final showing = StageRules.scoreFactorFor(LevelStage.introduction);
      expect(showing, lessThan(1.0));
      expect(showing, greaterThan(0.0));

      for (final stage in LevelStage.values) {
        if (stage.isShowing) continue;
        expect(StageRules.scoreFactorFor(stage), 1.0, reason: stage.name);
      }
    });

    test('множитель этапа доходит до очков', () {
      // Яркость нулевая: знакомство — это первый показ слова, и очки на нём
      // считаются без скоростного множителя. Механика на понимание выше
      // 40 lm не приносит очков вообще (митигация «узнавание вместо
      // владения»), так что сравнивать надо там, где они есть.
      RunScore scored({double factor = 1.0}) => RunScore(stageFactor: factor)
        ..apply(
          correct: true,
          latency: const Duration(milliseconds: 500),
          mode: GameMode.pickNative,
          lumens: 0,
        );

      final full = scored();
      final showing = scored(
        factor: StageRules.scoreFactorFor(LevelStage.introduction),
      );

      expect(full.score, greaterThan(0), reason: 'сравнивать нечего');
      expect(showing.score, lessThan(full.score));
      expect(showing.score, greaterThan(0),
          reason: 'показ не должен быть бесплатным');
    });
  });

  group('спринт', () {
    test('идёт только по тому, что держится в памяти', () {
      // Порог тот же, с которого включается скоростной множитель: спринт и
      // есть измерение автоматизма, а измерять его там, где его заведомо
      // нет, незачем.
      expect(
        StageRules.minLumensFor(LevelStage.sprint),
        ScoreBalance.speedBonusMinLm,
      );
      for (final stage in LevelStage.values) {
        if (stage == LevelStage.sprint) continue;
        expect(StageRules.minLumensFor(stage), 0, reason: stage.name);
      }
    });

    test('спринт — единственный этап на время', () {
      expect(
        LevelStage.values.where((s) => s.isTimed),
        [LevelStage.sprint],
      );
    });

    test('спринта нет в порядке уровня', () {
      // Он не часть каждого уровня, а финальная проверка пройденной темы.
      expect(StageRules.levelOrder, isNot(contains(LevelStage.sprint)));
      expect(StageRules.levelOrder, hasLength(LevelStage.values.length - 1));
    });

    test('новые слова берут ровно первые три этапа', () {
      expect(
        LevelStage.values.where((s) => s.takesNewWords),
        [
          LevelStage.introduction,
          LevelStage.consolidation,
          LevelStage.check,
        ],
      );
      // Столько же, сколько показов у нового слова: одно следует из другого.
      expect(
        LevelStage.values.where((s) => s.takesNewWords).length,
        SessionBalance.newWordRepeats,
      );
    });
  });
}
