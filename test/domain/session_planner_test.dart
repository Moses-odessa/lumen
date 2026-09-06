import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Планировщик проверяется на синтетическом словаре: важны не конкретные
/// слова, а свойства раскладки — тусклые вперёд, новые вразбивку, режим по
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

  group('выбор режима', () {
    test('сложность растёт вслед за владением', () {
      expect(SessionPlanner.modeFor(5), GameMode.recognition);
      expect(SessionPlanner.modeFor(30), GameMode.circle);
      expect(SessionPlanner.modeFor(55), GameMode.audio);
      expect(SessionPlanner.modeFor(90), GameMode.typing);
    });

    test('без озвучки «Слух» не выбирается', () {
      final mode = SessionPlanner.modeFor(75, hasAudio: false);
      expect(mode, isNot(GameMode.audio));
    });

    test('беззвучный режим исключает «Слух» на всей шкале', () {
      const silent = SessionCapabilities(audioEnabled: false);
      for (var lm = 0; lm <= 100; lm += 5) {
        expect(SessionPlanner.modeFor(lm, capabilities: silent),
            isNot(GameMode.audio), reason: '$lm lm');
      }
    });

    test('выключенный набор исключает «Набор»', () {
      const noTyping = SessionCapabilities(typingEnabled: false);
      expect(SessionPlanner.modeFor(95, capabilities: noTyping),
          isNot(GameMode.typing));
    });

    test('босс-фраза по яркости не выбирается — её ставят явно', () {
      for (var lm = 0; lm <= 100; lm++) {
        expect(SessionPlanner.modeFor(lm), isNot(GameMode.phrase),
            reason: '$lm lm');
      }
    });

    test('со случайностью режим всё равно подходит по яркости', () {
      final random = Random(42);
      for (var i = 0; i < 200; i++) {
        final lm = random.nextInt(101);
        final mode = SessionPlanner.modeFor(lm, random: random);
        final range = ScoreBalance.modeLumenRange(mode);
        expect(lm, inInclusiveRange(range.min, range.max),
            reason: '$mode не подходит для $lm lm');
      }
    });

    test('со случайностью появляется разнообразие режимов', () {
      final random = Random(7);
      final seen = {
        for (var i = 0; i < 100; i++)
          SessionPlanner.modeFor(65, random: random),
      };
      expect(seen.length, greaterThan(1));
    });

    test('битые данные не роняют планировщик', () {
      // Все режимы отключены — играть всё равно можно.
      const nothing =
          SessionCapabilities(audioEnabled: false, typingEnabled: false);
      expect(SessionPlanner.modeFor(200, capabilities: nothing),
          GameMode.circle);
    });
  });

  group('уровень', () {
    List<StudyItem> reviews(int n) =>
        [for (var i = 0; i < n; i++) word('r$i', lumens: 20 + i)];
    List<StudyItem> fresh(int n) =>
        [for (var i = 0; i < n; i++) word('n$i', lumens: 0, isNew: true)];

    test('состав уровня: шесть новых по три показа плюс двенадцать повторов',
        () {
      final plan = SessionPlanner.level(
        reviews: reviews(12),
        fresh: fresh(6),
      );

      expect(plan.length,
          SessionBalance.reviewsPerLevel +
              SessionBalance.newWordsPerLevel *
                  SessionBalance.newWordRepeats);
      // Три забега по десять кругов.
      expect(plan.length, 30);
    });

    test('первый показ нового слова — узнавание без таймера', () {
      final plan = SessionPlanner.level(reviews: reviews(12), fresh: fresh(6));

      for (final id in ['n0', 'n1', 'n2', 'n3', 'n4', 'n5']) {
        final shows = plan.where((c) => c.itemId == id).toList();
        expect(shows, hasLength(SessionBalance.newWordRepeats));
        expect(shows.first.isNew, isTrue);
        expect(shows.first.mode, GameMode.recognition);
      }
    });

    test('одно слово никогда не идёт двумя кругами подряд', () {
      final plan = SessionPlanner.level(reviews: reviews(12), fresh: fresh(6));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].itemId, isNot(plan[i - 1].itemId),
            reason: 'позиция $i');
      }
    });

    test('новые слова разбросаны, а не идут блоком', () {
      final plan = SessionPlanner.level(reviews: reviews(12), fresh: fresh(6));
      final positions = <int>[];
      for (var i = 0; i < plan.length; i++) {
        if (plan[i].itemId.startsWith('n')) positions.add(i);
      }

      // Новые занимают больше половины плана, но не должны толпиться
      // в начале: середина их позиций близка к середине уровня.
      final median = positions[positions.length ~/ 2];
      expect(median, inInclusiveRange(plan.length ~/ 4, plan.length * 3 ~/ 4));
    });

    test('повторы идут от самых тусклых', () {
      final plan = SessionPlanner.level(
        reviews: [
          word('bright', lumens: 80),
          word('dim', lumens: 10),
        ],
        fresh: const [],
        reviewWords: 2,
      );
      expect(plan.map((c) => c.itemId), ['dim', 'bright']);
    });

    test('уровень без новых слов — это просто повторы', () {
      final plan = SessionPlanner.level(reviews: reviews(12), fresh: const []);
      expect(plan, hasLength(12));
      expect(plan.every((c) => !c.isNew), isTrue);
    });

    test('уровень без повторов раскладывает новые по кругу', () {
      final plan = SessionPlanner.level(reviews: const [], fresh: fresh(3));

      expect(plan, hasLength(9));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].itemId, isNot(plan[i - 1].itemId));
      }
    });

    test('пустой вход даёт пустой план', () {
      expect(SessionPlanner.level(reviews: const [], fresh: const []),
          isEmpty);
    });

    test('материала меньше запрошенного — план просто короче', () {
      final plan = SessionPlanner.level(reviews: reviews(2), fresh: fresh(1));
      expect(plan, hasLength(2 + SessionBalance.newWordRepeats));
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

    test('режим подбирается по яркости каждого слова', () {
      final plan = SessionPlanner.sunrise(
        candidates: [word('a', lumens: 10), word('b', lumens: 95)],
        now: now,
      );
      expect(plan.first.mode, GameMode.recognition);
      expect(plan.last.mode, GameMode.typing);
    });
  });

  group('разбиение на забеги', () {
    test('план режется на забеги заданной длины', () {
      final plan = SessionPlanner.level(
        reviews: [for (var i = 0; i < 12; i++) word('r$i', lumens: 30)],
        fresh: [
          for (var i = 0; i < 6; i++) word('n$i', lumens: 0, isNew: true),
        ],
      );
      final runs = SessionPlanner.intoRuns(plan);

      expect(runs, hasLength(3));
      expect(runs.every((r) => r.length == 10), isTrue);
    });

    test('короткий хвост приклеивается к предыдущему забегу', () {
      final circles = [
        for (var i = 0; i < 22; i++)
          PlannedCircle(
              itemId: 'w$i',
              mode: GameMode.circle,
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
              mode: GameMode.circle,
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
      final plan = SessionPlanner.level(
        reviews: [for (var i = 0; i < 12; i++) word('r$i', lumens: 30)],
        fresh: [
          for (var i = 0; i < 6; i++) word('n$i', lumens: 0, isNew: true),
        ],
      );
      // 6 новых из 18 слов, хотя кругов у новых втрое больше.
      expect(SessionPlanner.newWordShare(plan), closeTo(6 / 18, 1e-9));
    });

    test('пустой план — нулевая доля', () {
      expect(SessionPlanner.newWordShare(const []), 0);
    });
  });

  test('PlannedCircle читаемо печатается', () {
    const circle = PlannedCircle(
        itemId: 'arzt', mode: GameMode.tight, isNew: false, lumens: 62);
    expect(circle.toString(), contains('arzt'));
    expect(circle.toString(), contains('tight'));
  });
}
