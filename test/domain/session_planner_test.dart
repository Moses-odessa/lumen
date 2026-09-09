import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/level_stage.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Планировщик проверяется на синтетическом словаре: важны не конкретные
/// слова, а свойства раскладки — тусклые вперёд, новые вразбивку, механика по
/// владению.
void main() {
  final now = DateTime.utc(2026, 3, 1, 8);

  StudyItem word(
    String id, {
    int lumens = 50,
    Duration? overdue,
    bool isNew = false,
    bool hasAudio = true,
    Tier tier = Tier.a1,
  }) =>
      StudyItem(
        itemId: id,
        tier: tier,
        lumens: lumens,
        due: isNew ? null : now.subtract(overdue ?? const Duration(hours: 1)),
        isNew: isNew,
        hasAudio: hasAudio,
      );

  group('пул сессии', () {
    test('самые тусклые идут первыми', () {
      final pool = SessionPlanner.pool([
        word('bright', lumens: 90),
        word('dim', lumens: 12),
        word('medium', lumens: 55),
      ], now);

      expect(pool.map((w) => w.itemId), ['dim', 'medium', 'bright']);
    });

    test('не просроченные слова в пул не попадают', () {
      final pool = SessionPlanner.pool([
        word('due', lumens: 40),
        StudyItem(
          itemId: 'later',
          tier: Tier.a1,
          lumens: 10,
          due: now.add(const Duration(days: 3)),
        ),
      ], now);

      expect(pool.map((w) => w.itemId), ['due']);
    });

    test('новые слова в пул повторений не попадают', () {
      final pool = SessionPlanner.pool([
        word('review', lumens: 40),
        word('fresh', isNew: true),
      ], now);

      expect(pool.map((w) => w.itemId), ['review']);
    });

    test('пул ограничен размером', () {
      final many = [
        for (var i = 0; i < 100; i++) word('w$i', lumens: i),
      ];
      expect(SessionPlanner.pool(many, now).length,
          SessionBalance.sessionPoolSize);
      expect(SessionPlanner.pool(many, now, size: 5).length, 5);
    });

    test('при равной яркости раньше идёт то, что дольше ждало', () {
      final pool = SessionPlanner.pool([
        word('recent', lumens: 30, overdue: const Duration(hours: 1)),
        word('stale', lumens: 30, overdue: const Duration(days: 9)),
      ], now);

      expect(pool.first.itemId, 'stale');
    });

    test('слово ровно на границе due считается просроченным', () {
      final pool = SessionPlanner.pool([
        StudyItem(
            itemId: 'edge', tier: Tier.a0, lumens: 20, due: now),
      ], now);
      expect(pool, hasLength(1));
    });
  });

  group('выбор механики', () {
    test('требовательность растёт вслед за владением', () {
      // Лестница та же, что была (узнавание → круг → слух → производство),
      // но ступеней теперь четыре, и разделены они не режимами, а тем, что
      // в центре и на каком языке варианты.
      expect(SessionPlanner.modeFor(5), GameMode.pickNative);
      expect(SessionPlanner.modeFor(22), GameMode.listenNative);
      expect(SessionPlanner.modeFor(40), GameMode.pickTarget);
      // На 90 lm стоял `listenTarget`; механики больше нет, и верхнюю
      // ступень занял `pickTarget` — потолок его диапазона поднят до 100
      // ровно затем, чтобы самое выученное слово не спрашивалось самой
      // дешёвой механикой.
      expect(SessionPlanner.modeFor(90), GameMode.pickTarget);
    });

    test('без озвучки механики на слух не выбираются', () {
      final mode = SessionPlanner.modeFor(75, hasAudio: false);
      // Проверяем свойство, а не имя: механика на слух одна, но признак
      // остаётся признаком — непоказуема без голоса любая из них.
      expect(mode.needsAudio, isFalse);
    });

    test('беззвучный режим исключает слух на всей шкале', () {
      const silent = SessionCapabilities(audioEnabled: false);
      for (var lm = 0; lm <= 100; lm += 5) {
        expect(SessionPlanner.modeFor(lm, capabilities: silent).needsAudio,
            isFalse,
            reason: '$lm lm');
      }
    });

    // УДАЛЕНО: «выключенный набор исключает «Набор»».
    //
    // Механики с полем ввода больше нет, а вместе с ней ушёл и переключатель
    // SessionCapabilities.typingEnabled. Гарантия «планировщик не поставит
    // круг с вводом, когда ввод выключен» стала беспредметной: вводить текст
    // в игре негде, и выключать нечего.

    test('фразовые механики по яркости не выбираются — их ставит этап', () {
      // Раньше так вела себя одна «фраза», теперь фразовых механик две, и
      // обе не имеют диапазона по яркости слова: их материал — предложение.
      for (var lm = 0; lm <= 100; lm++) {
        expect(SessionPlanner.modeFor(lm).isPhrase, isFalse, reason: '$lm lm');
      }
    });

    test('со случайностью механика всё равно подходит по яркости', () {
      final random = Random(42);
      for (var i = 0; i < 200; i++) {
        final lm = random.nextInt(101);
        final mode = SessionPlanner.modeFor(lm, random: random);
        final range = ScoreBalance.modeLumenRange(mode);
        expect(lm, inInclusiveRange(range.min, range.max),
            reason: '$mode не подходит для $lm lm');
      }
    });

    test('со случайностью появляется разнообразие механик', () {
      final random = Random(7);
      final seen = {
        for (var i = 0; i < 100; i++)
          SessionPlanner.modeFor(28, random: random),
      };
      expect(seen.length, greaterThan(1));
    });

    test('битые данные не роняют планировщик', () {
      // Яркость вне всех диапазонов и без звука — играть всё равно можно:
      // берётся самая требовательная из доступных механик.
      const nothing = SessionCapabilities(audioEnabled: false);
      expect(SessionPlanner.modeFor(200, capabilities: nothing),
          GameMode.pickTarget);
    });

    test('этап сужает набор, а яркость лишь выбирает внутри него', () {
      // Новое: `allowed`. На 22 lm сама по себе выбралась бы listenNative;
      // этап, который слуха не разрешил, обязан получить механику из своего
      // набора, а не «почти ту же».
      expect(
        SessionPlanner.modeFor(22,
            allowed: const {GameMode.pickNative, GameMode.pickTarget}),
        GameMode.pickNative,
      );
    });

    test('яркость вне разрешённых диапазонов не выводит за набор этапа', () {
      // 90 lm не накрывает ни pickNative, ни listenNative. Прежний код в
      // такой ситуации возвращал «Круг» — механику, которую этап не
      // разрешал; теперь берётся самая требовательная из разрешённых.
      expect(
        SessionPlanner.modeFor(90,
            allowed: const {GameMode.pickNative, GameMode.listenNative}),
        GameMode.listenNative,
      );
    });

    test('этап только на слух без звука не даёт непоказуемый круг', () {
      const silent = SessionCapabilities(audioEnabled: false);
      final mode = SessionPlanner.modeFor(
        70,
        capabilities: silent,
        allowed: const {GameMode.listenNative},
      );
      // Разрешённого не осталось ничего: показать нечего, и притворяться
      // нечем — но круг без задания хуже, чем круг проще запрошенного.
      expect(mode, GameMode.pickNative);
      expect(mode.needsAudio, isFalse);
    });
  });

  group('уровень этапами', () {
    List<StudyItem> reviews(int n) =>
        [for (var i = 0; i < n; i++) word('r$i', lumens: 20 + i)];
    List<StudyItem> fresh(int n) =>
        [for (var i = 0; i < n; i++) word('n$i', lumens: 0, isNew: true)];

    /// Все круги уровня подряд — то, что раньше возвращал сам `level`.
    List<PlannedCircle> flat(List<StagedRun> runs) =>
        [for (final run in runs) ...run.circles];

    test('этапы идут в порядке возрастания требований', () {
      final runs = SessionPlanner.level(
        reviews: reviews(12),
        fresh: fresh(6),
      );

      expect(runs.map((r) => r.stage), [
        LevelStage.introduction,
        LevelStage.consolidation,
        LevelStage.check,
        LevelStage.reminder,
      ]);

      // Требования растут: на знакомстве выбирать не из чего, дальше есть.
      final options = [for (final run in runs) run.circles.first.options];
      expect(options.first, SessionBalance.introductionOptions);
      for (var i = 1; i < options.length; i++) {
        expect(options[i], greaterThan(SessionBalance.introductionOptions),
            reason: 'этап ${runs[i].stage.name} остался показом');
      }
    });

    test('состав уровня: шесть новых по три показа плюс двенадцать повторов',
        () {
      final plan = flat(SessionPlanner.level(
        reviews: reviews(12),
        fresh: fresh(6),
      ));

      expect(
          plan.length,
          SessionBalance.reviewsPerLevel +
              SessionBalance.newWordsPerLevel *
                  SessionBalance.newWordRepeats);
      expect(plan.length, 30);
    });

    test('новое слово встречается по разу на каждом из первых трёх этапов',
        () {
      // Раньше показы вплетались между повторами и разводились правилом
      // «не ближе трёх кругов». Теперь их разводят сами этапы, и разведены
      // они максимально: между двумя показами лежит целый забег.
      final runs = SessionPlanner.level(
        reviews: reviews(12),
        fresh: fresh(6),
      );

      for (final id in ['n0', 'n1', 'n2', 'n3', 'n4', 'n5']) {
        final stages = [
          for (final run in runs)
            if (run.circles.any((c) => c.itemId == id)) run.stage,
        ];
        expect(stages, [
          LevelStage.introduction,
          LevelStage.consolidation,
          LevelStage.check,
        ], reason: id);

        // И ровно по одному кругу на этап: два показа внутри одного забега
        // проверяли бы буфер кратковременной памяти, а не повторение.
        for (final run in runs) {
          expect(run.circles.where((c) => c.itemId == id).length,
              lessThanOrEqualTo(1),
              reason: '$id на этапе ${run.stage.name}');
        }
      }
    });

    test('первый показ нового слова — понимание без таймера', () {
      final runs = SessionPlanner.level(reviews: reviews(12), fresh: fresh(6));
      final introduction =
          runs.firstWhere((r) => r.stage == LevelStage.introduction);

      for (final circle in introduction.circles) {
        expect(circle.isNew, isTrue, reason: circle.itemId);
        expect(StageRules.mechanicsFor(LevelStage.introduction),
            contains(circle.mode));
        expect(circle.options, SessionBalance.introductionOptions);
        expect(circle.options, ScoreBalance.optionsMin);
      }
    });

    test('дистракторы на проверке созвучные, на закреплении тематические', () {
      final runs = SessionPlanner.level(reviews: reviews(12), fresh: fresh(6));

      for (final run in runs) {
        final expected = run.stage == LevelStage.check
            ? DistractorKind.near
            : DistractorKind.far;
        expect(run.circles.map((c) => c.distractorKind).toSet(), {expected},
            reason: run.stage.name);
      }
    });

    test('этап спрашивает только разрешёнными механиками', () {
      final runs = SessionPlanner.level(
        reviews: reviews(12),
        fresh: fresh(6),
        random: Random(7),
      );

      for (final run in runs) {
        final allowed = StageRules.mechanicsFor(run.stage);
        if (allowed == null) continue;
        for (final circle in run.circles) {
          expect(allowed, contains(circle.mode),
              reason: '${run.stage.name}: ${circle.mode.name}');
        }
      }
    });

    test('напоминанию достаются самые тусклые повторы', () {
      final runs = SessionPlanner.level(
        reviews: [
          word('bright', lumens: 90),
          word('mid', lumens: 50),
          word('dim', lumens: 5),
        ],
        fresh: const [],
        reviewWords: 3,
      );

      // Очередь отсортирована по яркости, и последний этап забирает её
      // хвост — то, что ближе всего к тому, чтобы быть забытым совсем.
      final reminder = runs.firstWhere((r) => r.stage == LevelStage.reminder);
      expect(reminder.circles.map((c) => c.itemId), contains('bright'));

      final consolidation =
          runs.firstWhere((r) => r.stage == LevelStage.consolidation);
      expect(consolidation.circles.map((c) => c.itemId), contains('dim'));
    });

    test('уровень без новых слов — это просто повторы', () {
      final plan = flat(
        SessionPlanner.level(reviews: reviews(12), fresh: const []),
      );
      expect(plan, hasLength(12));
      expect(plan.every((c) => !c.isNew), isTrue);
    });

    test('уровень без повторов — три этапа по новым словам', () {
      final runs = SessionPlanner.level(reviews: const [], fresh: fresh(3));

      expect(runs.map((r) => r.stage), [
        LevelStage.introduction,
        LevelStage.consolidation,
        LevelStage.check,
      ]);
      expect(flat(runs), hasLength(9));
    });

    test('пустой вход даёт пустой уровень', () {
      expect(
          SessionPlanner.level(reviews: const [], fresh: const []), isEmpty);
    });

    test('пустой этап не превращается в пустой забег', () {
      // Забег из нуля кругов — это экран, который нечем показать.
      final runs = SessionPlanner.level(reviews: const [], fresh: fresh(2));
      expect(runs.every((r) => r.circles.isNotEmpty), isTrue);
    });

    test('материала меньше запрошенного — уровень просто короче', () {
      final plan = flat(SessionPlanner.level(
        reviews: reviews(3),
        fresh: fresh(1),
      ));
      expect(plan.length, 3 + 1 * SessionBalance.newWordRepeats);
    });
  });

  group('спринт', () {
    test('берёт только яркие слова', () {
      final run = SessionPlanner.sprint(
        candidates: [
          word('dim', lumens: 10),
          word('bright', lumens: 90),
          word('mid', lumens: 60),
        ],
        goal: SprintGoal.attempt(0),
      );

      expect(run, isNotNull);
      final ids = run!.circles.map((c) => c.itemId).toSet();
      expect(ids, isNot(contains('dim')),
          reason: 'гонка на незнакомом материале учит панике, а не языку');
      expect(ids, containsAll(['bright', 'mid']));
    });

    test('новых слов не берёт никогда', () {
      final run = SessionPlanner.sprint(
        candidates: [
          word('new', lumens: 90, isNew: true),
          word('known', lumens: 90),
        ],
        goal: SprintGoal.attempt(0),
      );
      expect(run!.circles.map((c) => c.itemId).toSet(), {'known'});
    });

    test('без ярких слов спринта нет', () {
      expect(
        SessionPlanner.sprint(
          candidates: [word('dim', lumens: 10)],
          goal: SprintGoal.attempt(0),
        ),
        isNull,
      );
    });

    test('кругов ставится с запасом на ошибки', () {
      // Ошибка возвращает слово в конец очереди. Упереться в конец списка
      // раньше, чем взята планка, нельзя.
      final goal = SprintGoal.attempt(0);
      final run = SessionPlanner.sprint(
        candidates: [word('a', lumens: 90), word('b', lumens: 90)],
        goal: goal,
      );
      expect(run!.circles.length, greaterThan(goal.connections));
    });

    test('планка растёт с попытками, а время не сжимается', () {
      // Сжатое время превращает спринт в проверку скорости пальца, а не
      // автоматизма.
      var previous = SprintGoal.attempt(0);
      for (var attempt = 1; attempt < 5; attempt++) {
        final goal = SprintGoal.attempt(attempt);
        expect(goal.connections, greaterThan(previous.connections));
        expect(goal.duration, previous.duration);
        previous = goal;
      }
    });

    test('планка считается верными связями, а не ответами', () {
      final goal = SprintGoal.attempt(0);
      expect(goal.reachedBy(goal.connections - 1), isFalse);
      expect(goal.reachedBy(goal.connections), isTrue);
    });
  });

  group('Восход', () {
    test('только повторы, самые тусклые первыми', () {
      final plan = SessionPlanner.sunrise(
        candidates: [
          word('bright', lumens: 88),
          word('fresh', isNew: true),
          word('dim', lumens: 9),
        ],
        now: now,
      );

      expect(plan.map((c) => c.itemId), ['dim', 'bright']);
      expect(plan.every((c) => !c.isNew), isTrue);
    });

    test('механика подбирается по яркости каждого слова', () {
      final plan = SessionPlanner.sunrise(
        candidates: [word('a', lumens: 10), word('b', lumens: 95)],
        now: now,
      );
      expect(plan.first.mode, GameMode.pickNative);
      expect(plan.last.mode, GameMode.pickTarget);
    });
  });

  group('разбиение на забеги', () {
    test('план режется на забеги заданной длины', () {
      // Уровень теперь приходит этапами, и резать имеет смысл каждый этап
      // по отдельности: забег обрывается на границе этапа, а не там, где
      // кончились десять кругов подряд.
      final circles = [
        for (var i = 0; i < 30; i++)
          PlannedCircle(
              itemId: 'w$i',
              mode: GameMode.pickTarget,
              isNew: false,
              lumens: 50),
      ];
      final runs = SessionPlanner.intoRuns(circles);

      expect(runs, hasLength(3));
      expect(runs.every((r) => r.length == 10), isTrue);
    });

    test('короткий хвост приклеивается к предыдущему забегу', () {
      final circles = [
        for (var i = 0; i < 22; i++)
          PlannedCircle(
              itemId: 'w$i',
              mode: GameMode.pickTarget,
              isNew: false,
              lumens: 50),
      ];
      final runs = SessionPlanner.intoRuns(circles, perRun: 10);

      // 10 + 10 + 2 → последние два приклеиваются, чтобы не было забега
      // из двух кругов.
      expect(runs, hasLength(2));
      expect(runs.last, hasLength(12));
    });

    test('пустой план не даёт забегов', () {
      expect(SessionPlanner.intoRuns(const []), isEmpty);
    });

    test('план короче забега остаётся одним забегом', () {
      final circles = [
        for (var i = 0; i < 4; i++)
          PlannedCircle(
              itemId: 'w$i',
              mode: GameMode.pickTarget,
              isNew: false,
              lumens: 50),
      ];
      expect(SessionPlanner.intoRuns(circles), hasLength(1));
    });
  });

  group('свой темп', () {
    test('по умолчанию новых слов ровно столько, сколько в уровне', () {
      expect(
        SessionPlanner.allowedNewWords(reviewCount: 500, freePace: false),
        SessionBalance.newWordsPerLevel,
      );
    });

    test('свой темп позволяет больше, пока очередь короткая', () {
      final allowed =
          SessionPlanner.allowedNewWords(reviewCount: 100, freePace: true);
      expect(allowed, greaterThan(SessionBalance.newWordsPerLevel));
    });

    test('чем длиннее очередь повторений, тем меньше новых на слово', () {
      final small =
          SessionPlanner.allowedNewWords(reviewCount: 20, freePace: true);
      final large =
          SessionPlanner.allowedNewWords(reviewCount: 400, freePace: true);
      expect(large, greaterThan(small));
      // Но доля новых остаётся ограниченной.
      expect(large / (large + 400), lessThanOrEqualTo(
          SessionBalance.maxNewWordShare + 0.01));
    });

    test('пустая очередь не запрещает учить новое', () {
      expect(
        SessionPlanner.allowedNewWords(reviewCount: 0, freePace: true),
        SessionBalance.newWordsPerLevel,
      );
    });

    test('доля новых слов в плане считается по словам, а не по кругам', () {
      final runs = SessionPlanner.level(
        reviews: [for (var i = 0; i < 12; i++) word('r$i', lumens: 30)],
        fresh: [
          for (var i = 0; i < 6; i++) word('n$i', lumens: 0, isNew: true),
        ],
      );
      final plan = [for (final run in runs) ...run.circles];
      // 6 новых из 18 слов, хотя кругов у новых втрое больше.
      //
      // Считается по `isNew`, а тот стоит только на первом показе — то есть
      // на этапе знакомства. Остальные два показа того же слова идут
      // обычными кругами, и это верно: доля нужна, чтобы не утопить игрока
      // в новом материале, а не чтобы посчитать круги.
      expect(SessionPlanner.newWordShare(plan), closeTo(6 / 18, 1e-9));
    });

    test('пустой план — нулевая доля', () {
      expect(SessionPlanner.newWordShare(const []), 0);
    });
  });

  group('сложность круга', () {
    test('вид дистракторов едет на круге, а не выводится из механики', () {
      // Раньше «созвучные» означало другую механику («Тесный круг»), и
      // спросить «то же самое, но с созвучными» было нельзя. Теперь два
      // круга одной механики отличаются только этим параметром.
      const wide = PlannedCircle(
          itemId: 'arzt',
          mode: GameMode.pickTarget,
          isNew: false,
          lumens: 62);
      final tight = wide.copyWith(distractorKind: DistractorKind.near);

      expect(wide.distractorKind, DistractorKind.far);
      expect(tight.distractorKind, DistractorKind.near);
      expect(tight.mode, wide.mode);
    });

    test('по умолчанию круг тематический и на полное число вариантов', () {
      const circle = PlannedCircle(
          itemId: 'arzt',
          mode: GameMode.pickTarget,
          isNew: false,
          lumens: 62);
      expect(circle.distractorKind, DistractorKind.far);
      expect(circle.options, ScoreBalance.optionsMax);
    });

    test('copyWith меняет сложность, но не слово и не его яркость', () {
      const circle = PlannedCircle(
          itemId: 'arzt',
          mode: GameMode.pickTarget,
          isNew: false,
          lumens: 62);
      final easier = circle.copyWith(
        mode: GameMode.pickNative,
        options: ScoreBalance.optionsMin,
        isNew: true,
      );

      expect(easier.itemId, 'arzt');
      expect(easier.lumens, 62);
      expect(easier.mode, GameMode.pickNative);
      expect(easier.options, 1);
      expect(easier.isNew, isTrue);
    });
  });

  test('PlannedCircle читаемо печатается', () {
    // Круг с созвучными вариантами — то, что прежде было отдельным режимом
    // «tight»: в печати это должно быть видно, иначе два внешне одинаковых
    // круга не различить в логе.
    const circle = PlannedCircle(
      itemId: 'arzt',
      mode: GameMode.pickTarget,
      isNew: false,
      lumens: 62,
      distractorKind: DistractorKind.near,
    );
    expect(circle.toString(), contains('arzt'));
    expect(circle.toString(), contains('pickTarget'));
    expect(circle.toString(), contains('near'));
  });
}
