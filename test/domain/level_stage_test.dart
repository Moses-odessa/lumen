import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/scheduler/level_stage.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/score.dart';

/// Тесты на этапы уровня.
///
/// Смысл этапов в том, что «насколько трудно» отделено от «какие фразы». Все
/// проверки ниже про первое: второе решает яркость по FSRS, и путать их
/// нельзя — иначе либо сложность перестаёт расти, либо фразы перестают
/// повторяться вовремя.
///
/// **Что здесь удалено.** Сложность этапа больше не выражается ни числом
/// вариантов, ни видом дистракторов: вариантов в круге всегда шесть, потому
/// что на полном круге держится знакомство методом исключения, а неверные
/// варианты не пишутся руками — вокруг фразы стоят другие фразы, которые
/// игрок уже знает. `StageRules.optionsFor`, `gapsFor` и `distractorFor`
/// удалены, и вместе с ними удалена вся группа «вариантность по этапам»:
///
/// * «Знакомство — один вариант, и заход этого не меняет» охранял
///   `SessionBalance.introductionOptions = 1` и то, что надбавка захода в
///   показ не просачивается. Знакомство было показом: один вариант, соединил
///   и услышал. Теперь оно устроено исключением, и неполный круг ломал бы
///   ровно это.
/// * «Дальше вариантов больше, чем на показе» охранял шкалу 1 → 4 → 6 → 5 → 4
///   по этапам. Шкалы нет: у всех этапов круг одинаковый, и сложность даёт
///   набор механик.
/// * «Заход не выводит этап за экранный потолок» охранял
///   `ClimbBalance.extraOptionsMax` — седьмой и восьмой вариант от захода.
///   Ручки нет.
///
/// «Проверка спрашивает жёстче закрепления» не удалён, а перенесён: правило
/// уцелело, только выражается теперь механиками, а не числами. Оно ниже, в
/// группе про механики.
///
/// * «Фразовые механики этап не назначает» охранял `GameMode.isPhrase`: у
///   фразовых механик материалом было предложение, а не звезда, и ставились
///   они отдельно от слов. Единицей изучения стала фраза, все три механики
///   спрашивают фразу, и делить набор больше не на что.
void main() {
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

    test('проверка спрашивает жёстче закрепления', () {
      // Между ними и лежит вся идея этапов: сначала вспомнить фразу, потом
      // выдать её самому. Прежде разница мерилась числами — четыре варианта
      // против шести и тематические дистракторы против созвучных, — а теперь
      // единственная шкала сложности этапа это набор механик, и разница
      // обязана быть видна именно там.
      final consolidation = StageRules.mechanicsFor(LevelStage.consolidation)!;
      final check = StageRules.mechanicsFor(LevelStage.check)!;

      // Сужение, а не смена: проверка спрашивает тем, что закрепление уже
      // разрешало. Механика, впервые появляющаяся на проверке, была бы для
      // игрока новым заданием на этапе, который меряет знание фразы.
      expect(check, isNotEmpty);
      expect(consolidation.containsAll(check), isTrue,
          reason: 'проверка спрашивает тем, чего на закреплении не было');
      expect(check.length, lessThan(consolidation.length),
          reason: 'проверка ничего не сузила');

      // И сужение именно в эту сторону: отброшено всё, что спрашивает
      // узнавание. Разойдись это с [GameMode.isProductive] — и проверка
      // начнёт засчитывать узнанное за выданное.
      expect(
        consolidation.difference(check),
        consolidation.where((m) => !m.isProductive).toSet(),
      );
    });

    test('напоминание не сужает набор', () {
      // Слова здесь разной яркости, и выбор механики — работа планировщика,
      // а не расписания.
      expect(StageRules.mechanicsFor(LevelStage.reminder), isNull);
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
