import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/level_stage.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Планировщик проверяется на синтетическом наборе фраз: важны не сами
/// предложения, а свойства раскладки — тусклые вперёд, новые вразбивку,
/// механика по владению.
///
/// Единица изучения — фраза, а не слово. Планировщику это почти безразлично:
/// он знает о материале ровно [StudyItem] — ярус, яркость и срок, — и заменой
/// слова на фразу здесь изменились названия, а не правила.
///
/// ── Что этот файл охранял и чего больше нет ────────────────────────────────
///
/// * «выключенный набор исключает «Набор»» — механики с полем ввода больше
///   нет, а вместе с ней ушёл и переключатель
///   `SessionCapabilities.typingEnabled`. Гарантия «планировщик не поставит
///   круг с вводом, когда ввод выключен» стала беспредметной: вводить текст в
///   игре негде, и выключать нечего.
/// * «фразовые механики по яркости не выбираются — их ставит этап» — охранял
///   то, что у `fillGaps` и `buildPhrase` нет диапазона по яркости слова: их
///   материал — предложение, а не слово. Теперь предложение — материал всех
///   трёх механик, `GameMode.isPhrase` не существует, и диапазон есть у
///   каждой. Тест перенесён на то, что осталось правдой в том же месте кода:
///   шкала яркости накрыта механиками целиком, без дырок.
/// * «дистракторы на проверке созвучные, на закреплении тематические» и «вид
///   дистракторов едет на круге, а не выводится из механики» — охраняли
///   `PlannedCircle.distractorKind` и `StageRules.distractorFor`. Рукописных
///   неверных вариантов в игре нет вовсе: вокруг фразы стоят другие фразы,
///   которые игрок уже знает, и «тематический против созвучного» к ним
///   неприменимо.
/// * «по умолчанию круг тематический и на полное число вариантов» — охранял
///   `PlannedCircle.options` и `ScoreBalance.optionsMax`. Вариантов в круге
///   всегда шесть: на полном круге держится знакомство методом исключения, и
///   шкалой сложности их число быть перестало.
void main() {
  final now = DateTime.utc(2026, 3, 1, 8);

  StudyItem phrase(
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
        phrase('bright', lumens: 90),
        phrase('dim', lumens: 12),
        phrase('medium', lumens: 55),
      ], now);

      expect(pool.map((p) => p.itemId), ['dim', 'medium', 'bright']);
    });

    test('не просроченные фразы в пул не попадают', () {
      final pool = SessionPlanner.pool([
        phrase('due', lumens: 40),
        StudyItem(
          itemId: 'later',
          tier: Tier.a1,
          lumens: 10,
          due: now.add(const Duration(days: 3)),
        ),
      ], now);

      expect(pool.map((p) => p.itemId), ['due']);
    });

    test('новые фразы в пул повторений не попадают', () {
      final pool = SessionPlanner.pool([
        phrase('review', lumens: 40),
        phrase('fresh', isNew: true),
      ], now);

      expect(pool.map((p) => p.itemId), ['review']);
    });

    test('пул ограничен размером', () {
      final many = [
        for (var i = 0; i < 100; i++) phrase('p$i', lumens: i),
      ];
      expect(SessionPlanner.pool(many, now).length,
          SessionBalance.sessionPoolSize);
      expect(SessionPlanner.pool(many, now, size: 5).length, 5);
    });

    test('при равной яркости раньше идёт то, что дольше ждало', () {
      final pool = SessionPlanner.pool([
        phrase('recent', lumens: 30, overdue: const Duration(hours: 1)),
        phrase('stale', lumens: 30, overdue: const Duration(days: 9)),
      ], now);

      expect(pool.first.itemId, 'stale');
    });

    test('фраза ровно на границе due считается просроченной', () {
      final pool = SessionPlanner.pool([
        StudyItem(itemId: 'edge', tier: Tier.a0, lumens: 20, due: now),
      ], now);
      expect(pool, hasLength(1));
    });
  });

  group('выбор механики', () {
    test('у каждой механики центр и варианты на разных языках', () {
      // На этом отрицании стоит вся защита от двух верных ответов. Сборщик
      // круга берёт язык центра как «тот, которого нет в вариантах»
      // (`question_builder.dart`), и считает на нём двусмысленность: два
      // варианта верны одновременно тогда, когда текст центра описывает оба.
      // Похожесть же он считает на языке вариантов — том, который игрок
      // читает в плитках. Совпади эти языки, обе проверки поменялись бы
      // местами молча, и круг с двумя верными ответами вернулся бы.
      //
      // Таблица здесь переписана руками, а не выведена из кода: она и есть
      // устройство механик. Четвёртая механика обязана сюда попасть — а
      // попав, обязана иметь центр на языке, которого нет вокруг.
      const centreInTarget = {
        // Центр — изучаемая фраза, вокруг переводы: понимание.
        GameMode.pickNative: true,
        // Центр — перевод, вокруг изучаемые фразы: воспроизведение.
        GameMode.pickTarget: false,
        // Центр звучит на изучаемом, вокруг переводы: слух вместе со смыслом.
        GameMode.listenNative: true,
      };

      expect(centreInTarget.keys.toSet(), GameMode.values.toSet(),
          reason: 'механика без записанного языка центра: сборщик круга '
              'выведет его отрицанием и может ошибиться молча');
      for (final mode in GameMode.values) {
        expect(mode.optionsInTargetLanguage, isNot(centreInTarget[mode]),
            reason: '${mode.name}: центр и варианты на одном языке — круг без '
                'задания, и проверка двух верных ответов считает не тот язык');
      }
    });

    test('требовательность растёт вслед за владением', () {
      // Лестница та же, что была (узнавание → круг → слух → производство),
      // но ступеней теперь три, и разделены они не режимами, а тем, что
      // в центре и на каком языке варианты.
      expect(SessionPlanner.modeFor(5), GameMode.pickNative);
      expect(SessionPlanner.modeFor(22), GameMode.listenNative);
      expect(SessionPlanner.modeFor(40), GameMode.pickTarget);
      // На 90 lm стоял `listenTarget`; механики больше нет, и верхнюю
      // ступень занял `pickTarget` — потолок его диапазона поднят до 100
      // ровно затем, чтобы самая выученная фраза не спрашивалась самой
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

    test('на любой яркости есть механика, чей диапазон её накрывает', () {
      // Диапазоны механик обязаны накрывать шкалу целиком. Дырка в ней не
      // роняет планировщик и вообще ничего не ломает на глаз: яркость не
      // подходит ни одной механике, `modeFor` уходит в ветку «самая
      // требовательная из разрешённых» и возвращает круг, который для этой
      // яркости не предназначен. Игрок при этом видит рабочий экран.
      //
      // Проверка нужна именно без случайности: она про покрытие шкалы, а не
      // про выбор внутри подходящих — тот охраняет тест ниже.
      for (var lm = 0; lm <= 100; lm++) {
        final range = ScoreBalance.modeLumenRange(SessionPlanner.modeFor(lm));
        expect(lm, inInclusiveRange(range.min, range.max),
            reason: '$lm lm не накрыт ни одним диапазоном');
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
      // Прежний код в такой ситуации возвращал «Круг» — механику, которую
      // этап не разрешал; теперь берётся самая требовательная из разрешённых.
      const allowed = {GameMode.listenNative, GameMode.pickTarget};
      const lm = 5;

      // Условие теста проверяется, а не подразумевается. Диапазоны переехали
      // вместе с удалением `listenTarget`: тускло-яркая пара, на которой это
      // правило раньше показывали (90 lm при pickNative и listenNative),
      // теперь накрыта слухом целиком, и тест молча проверял бы обычную
      // ветку «подходящее нашлось».
      for (final mode in allowed) {
        final range = ScoreBalance.modeLumenRange(mode);
        expect(lm, isNot(inInclusiveRange(range.min, range.max)),
            reason: '$mode накрывает $lm lm — правило проверяется не на том');
      }

      expect(SessionPlanner.modeFor(lm, allowed: allowed), GameMode.pickTarget);
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
        [for (var i = 0; i < n; i++) phrase('r$i', lumens: 20 + i)];
    List<StudyItem> fresh(int n) =>
        [for (var i = 0; i < n; i++) phrase('n$i', lumens: 0, isNew: true)];

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

      // Требования растут не числом вариантов — их всегда шесть, — а тем,
      // о чём этап спрашивает. Знакомство спрашивает узнавание: фразу только
      // что показали, требовать её обратно рано. Проверка спрашивает
      // воспроизведение — знает ли игрок фразу настолько, чтобы выдать её, а
      // не узнать среди шести.
      final introduction =
          runs.firstWhere((r) => r.stage == LevelStage.introduction);
      expect(introduction.circles.every((c) => !c.mode.isProductive), isTrue,
          reason: 'знакомство спрашивает производство');

      final check = runs.firstWhere((r) => r.stage == LevelStage.check);
      expect(check.circles.every((c) => c.mode.isProductive), isTrue,
          reason: 'проверка спрашивает узнавание');
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

    test('новая фраза встречается по разу на каждом из первых трёх этапов',
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

    test('первый показ новой фразы — понимание и без окна на ответ', () {
      final runs = SessionPlanner.level(reviews: reviews(12), fresh: fresh(6));
      final introduction =
          runs.firstWhere((r) => r.stage == LevelStage.introduction);

      for (final circle in introduction.circles) {
        // `isNew` — это и есть «без таймера»: окно на ответ открывается на
        // каждом круге, кроме помеченного так. Раньше знакомство узнавалось
        // ещё и по одному варианту в круге; вариантов всегда шесть, потому
        // что знакомство идёт исключением, и метка осталась единственным
        // признаком показа.
        expect(circle.isNew, isTrue, reason: circle.itemId);
        expect(StageRules.mechanicsFor(LevelStage.introduction),
            contains(circle.mode));
        expect(circle.mode.isProductive, isFalse, reason: circle.itemId);
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

    test('повторы делятся между этапами по яркости, а не идут трижды', () {
      final runs = SessionPlanner.level(
        reviews: [
          phrase('bright', lumens: 90),
          phrase('mid', lumens: 50),
          phrase('dim', lumens: 5),
        ],
        fresh: const [],
        reviewWords: 3,
      );

      // Очередь отсортирована по яркости от тусклых, и этапы забирают её с
      // начала: самое близкое к тому, чтобы быть забытым совсем, идёт раньше,
      // пока внимания больше.
      //
      // ВНИМАНИЕ: комментарий в `SessionPlanner.level` обещает обратное —
      // «напоминанию идут самые тусклые», — а забирает напоминание хвост
      // очереди, то есть самое яркое. Тест описывает код, а расхождение с
      // комментарием вынесено в отчёт: править `lib/` в задаче переноса
      // тестов нельзя, а тест с названием-неправдой хуже отсутствующего.
      String only(LevelStage stage) => runs
          .firstWhere((r) => r.stage == stage)
          .circles
          .map((c) => c.itemId)
          .single;

      expect(only(LevelStage.consolidation), 'dim');
      expect(only(LevelStage.check), 'mid');
      expect(only(LevelStage.reminder), 'bright');
    });

    test('уровень без новых фраз — это просто повторы', () {
      final plan = flat(
        SessionPlanner.level(reviews: reviews(12), fresh: const []),
      );
      expect(plan, hasLength(12));
      expect(plan.every((c) => !c.isNew), isTrue);
    });

    test('уровень без повторов — три этапа по новым фразам', () {
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
    test('берёт только яркие фразы', () {
      final run = SessionPlanner.sprint(
        candidates: [
          phrase('dim', lumens: 10),
          phrase('bright', lumens: 90),
          phrase('mid', lumens: 60),
        ],
        goal: SprintGoal.attempt(0),
      );

      expect(run, isNotNull);
      final ids = run!.circles.map((c) => c.itemId).toSet();
      expect(ids, isNot(contains('dim')),
          reason: 'гонка на незнакомом материале учит панике, а не языку');
      expect(ids, containsAll(['bright', 'mid']));
    });

    test('новых фраз не берёт никогда', () {
      final run = SessionPlanner.sprint(
        candidates: [
          phrase('new', lumens: 90, isNew: true),
          phrase('known', lumens: 90),
        ],
        goal: SprintGoal.attempt(0),
      );
      expect(run!.circles.map((c) => c.itemId).toSet(), {'known'});
    });

    test('без ярких фраз спринта нет', () {
      expect(
        SessionPlanner.sprint(
          candidates: [phrase('dim', lumens: 10)],
          goal: SprintGoal.attempt(0),
        ),
        isNull,
      );
    });

    test('кругов ставится с запасом на ошибки', () {
      // Ошибка возвращает фразу в конец очереди. Упереться в конец списка
      // раньше, чем взята планка, нельзя.
      final goal = SprintGoal.attempt(0);
      final run = SessionPlanner.sprint(
        candidates: [phrase('a', lumens: 90), phrase('b', lumens: 90)],
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
          phrase('bright', lumens: 88),
          phrase('fresh', isNew: true),
          phrase('dim', lumens: 9),
        ],
        now: now,
      );

      expect(plan.map((c) => c.itemId), ['dim', 'bright']);
      expect(plan.every((c) => !c.isNew), isTrue);
    });

    test('механика подбирается по яркости каждой фразы', () {
      final plan = SessionPlanner.sunrise(
        candidates: [phrase('a', lumens: 10), phrase('b', lumens: 95)],
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
              itemId: 'p$i',
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
              itemId: 'p$i',
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
              itemId: 'p$i',
              mode: GameMode.pickTarget,
              isNew: false,
              lumens: 50),
      ];
      expect(SessionPlanner.intoRuns(circles), hasLength(1));
    });
  });

  group('свой темп', () {
    test('по умолчанию новых фраз ровно столько, сколько в уровне', () {
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

    test('чем длиннее очередь повторений, тем меньше новых на фразу', () {
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

    test('доля новых считается по фразам, а не по кругам', () {
      final runs = SessionPlanner.level(
        reviews: [for (var i = 0; i < 12; i++) phrase('r$i', lumens: 30)],
        fresh: [
          for (var i = 0; i < 6; i++) phrase('n$i', lumens: 0, isNew: true),
        ],
      );
      final plan = [for (final run in runs) ...run.circles];
      // 6 новых из 18 фраз, хотя кругов у новых втрое больше.
      //
      // Считается по `isNew`, а тот стоит только на первом показе — то есть
      // на этапе знакомства. Остальные два показа той же фразы идут
      // обычными кругами, и это верно: доля нужна, чтобы не утопить игрока
      // в новом материале, а не чтобы посчитать круги.
      expect(SessionPlanner.newWordShare(plan), closeTo(6 / 18, 1e-9));
    });

    test('пустой план — нулевая доля', () {
      expect(SessionPlanner.newWordShare(const []), 0);
    });
  });

  group('круг в плане', () {
    test('copyWith меняет механику и метку показа, но не фразу и не яркость',
        () {
      // Ручек у `copyWith` осталось две. `options` и `distractorKind` ушли:
      // вариантов всегда шесть, а неверные варианты — это другие фразы из
      // пула, и круг о них не знает. Зато `isNew` менять надо по-прежнему:
      // одна и та же фраза идёт показом на знакомстве и обычным кругом
      // дальше, и различает эти круги только метка.
      const circle = PlannedCircle(
        itemId: 'doctor_a0_help',
        mode: GameMode.pickTarget,
        isNew: false,
        lumens: 62,
      );
      final easier = circle.copyWith(mode: GameMode.pickNative, isNew: true);

      expect(easier.itemId, 'doctor_a0_help');
      expect(easier.lumens, 62);
      expect(easier.mode, GameMode.pickNative);
      expect(easier.isNew, isTrue);
      // Исходный круг не тронут: план строится копированием, и мутация
      // испортила бы уже разложенные этапы.
      expect(circle.mode, GameMode.pickTarget);
      expect(circle.isNew, isFalse);
    });

    test('PlannedCircle читаемо печатается', () {
      // Раньше в печати требовался вид дистракторов: два круга одной
      // механики отличались только им, и в логе их было не различить. Вида
      // нет, и различает круги яркость — значит она обязана быть в строке,
      // иначе два показа одной фразы на разных этапах сливаются в одну
      // запись.
      const circle = PlannedCircle(
        itemId: 'doctor_a0_help',
        mode: GameMode.pickTarget,
        isNew: false,
        lumens: 62,
      );
      expect(circle.toString(), contains('doctor_a0_help'));
      expect(circle.toString(), contains('pickTarget'));
      expect(circle.toString(), contains('62'));
    });
  });
}
