import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/sky/progression.dart';
import 'package:lumen/domain/sky/sky_layout.dart';

void main() {
  ConstellationState constellation(
    String name, {
    required List<int> lumens,
    bool unlocked = true,
    Tier tier = Tier.a0,
  }) =>
      ConstellationState(
        name: name,
        tier: tier,
        starLumens: lumens,
        unlocked: unlocked,
      );

  group('зажжённое созвездие', () {
    test('зажжено при 80 % звёзд ярче 70 lm', () {
      // 8 из 10 — ровно порог.
      final lit = constellation('doctor', lumens: [
        ...List.filled(8, 80),
        ...List.filled(2, 10),
      ]);
      expect(lit.isLit, isTrue);
      expect(lit.litStars, 8);
    });

    test('семь из десяти — ещё не зажжено', () {
      final almost = constellation('doctor', lumens: [
        ...List.filled(7, 80),
        ...List.filled(3, 10),
      ]);
      expect(almost.isLit, isFalse);
      expect(almost.starsToLight, 1);
    });

    test('одна забытая звезда не гасит созвездие целиком', () {
      final nine = constellation('doctor', lumens: [
        ...List.filled(9, 90),
        0,
      ]);
      expect(nine.isLit, isTrue);
    });

    test('пара идеальных звёзд среди тусклых не зажигает', () {
      final few = constellation('doctor', lumens: [
        100,
        100,
        ...List.filled(8, 20),
      ]);
      expect(few.isLit, isFalse);
    });

    test('пустое созвездие не зажжено и не делит на ноль', () {
      final empty = constellation('empty', lumens: const []);
      expect(empty.isLit, isFalse);
      expect(empty.averageLumens, 0);
      expect(empty.litProgress, 0);
      expect(empty.starsToLight, 0);
    });

    test('прогресс к зажжению растёт вместе с яркими звёздами', () {
      double progress(int bright) => constellation('c', lumens: [
            ...List.filled(bright, 80),
            ...List.filled(10 - bright, 10),
          ]).litProgress;

      expect(progress(0), 0);
      expect(progress(4), lessThan(progress(6)));
      expect(progress(8), 1.0);
      expect(progress(10), 1.0);
    });

    test('звезда ровно на пороге считается горящей', () {
      final edge = constellation('c',
          lumens: List.filled(10, ProgressionBalance.litStarMinLm));
      expect(edge.isLit, isTrue);
    });
  });

  group('открытие соседей', () {
    test('соседи открываются при 60 % средней яркости', () {
      final ready = constellation('doctor', lumens: List.filled(10, 65));
      final notReady = constellation('rent', lumens: List.filled(10, 40));

      expect(ready.opensNeighbours, isTrue);
      expect(notReady.opensNeighbours, isFalse);
    });

    test('открытие каскадное: сосед соседа тоже откроется', () {
      final bright = List.filled(10, 90);
      final states = [
        constellation('a', lumens: bright),
        constellation('b', lumens: bright),
        constellation('c', lumens: bright),
      ];

      final open = Progression.unlocked(
        constellations: states,
        neighbours: {
          'a': ['b'],
          'b': ['c'],
        },
        starters: {'a'},
      );

      expect(open, {'a', 'b', 'c'});
    });

    test('тусклое созвездие никого не открывает', () {
      final open = Progression.unlocked(
        constellations: [constellation('a', lumens: List.filled(10, 20))],
        neighbours: {
          'a': ['b'],
        },
        starters: {'a'},
      );
      expect(open, {'a'});
    });

    test('стартовые созвездия открыты всегда', () {
      final open = Progression.unlocked(
        constellations: const [],
        neighbours: const {},
        starters: {'doctor', 'rent'},
      );
      expect(open, {'doctor', 'rent'});
    });
  });

  group('предложение по ярусу', () {
    List<ConstellationState> withLit(int lit, int total) => [
          for (var i = 0; i < total; i++)
            constellation('c$i',
                lumens: List.filled(10, i < lit ? 90 : 20)),
        ];

    test('70 % зажжённых — предложение подняться', () {
      expect(
        Progression.suggest(
          constellations: withLit(7, 10),
          current: Tier.a1,
        ),
        TierSuggestion.up,
      );
    });

    test('половина зажжённых — играем дальше', () {
      expect(
        Progression.suggest(
          constellations: withLit(5, 10),
          current: Tier.a1,
        ),
        TierSuggestion.stay,
      );
    });

    test('на B2 подниматься некуда', () {
      expect(
        Progression.suggest(
          constellations: withLit(10, 10),
          current: Tier.b2,
        ),
        TierSuggestion.stay,
      );
    });

    test('низкая точность предлагает спуститься', () {
      expect(
        Progression.suggest(
          constellations: withLit(0, 10),
          current: Tier.b1,
          recentAccuracy: 0.4,
        ),
        TierSuggestion.down,
      );
    });

    test('спуск важнее подъёма', () {
      // Даже с зажжённым небом низкая точность перевешивает: игрок, которому
      // тяжело, бросит раньше, чем игрок, которому легко.
      expect(
        Progression.suggest(
          constellations: withLit(10, 10),
          current: Tier.b1,
          recentAccuracy: 0.3,
        ),
        TierSuggestion.down,
      );
    });

    test('с A0 спускаться некуда', () {
      expect(
        Progression.suggest(
          constellations: withLit(0, 4),
          current: Tier.a0,
          recentAccuracy: 0.1,
        ),
        TierSuggestion.stay,
      );
    });

    test('высокая точность при быстром отклике предлагает подняться', () {
      expect(
        Progression.suggest(
          constellations: withLit(1, 10),
          current: Tier.a1,
          recentAccuracy: 0.95,
          medianLatency: const Duration(milliseconds: 1200),
        ),
        TierSuggestion.up,
      );
    });

    test('высокая точность при медленном отклике ничего не предлагает', () {
      // Знает, но не автоматически: ярус подобран правильно.
      expect(
        Progression.suggest(
          constellations: withLit(1, 10),
          current: Tier.a1,
          recentAccuracy: 0.95,
          medianLatency: const Duration(seconds: 4),
        ),
        TierSuggestion.stay,
      );
    });

    test('закрытые созвездия в долю не считаются', () {
      final states = [
        constellation('open', lumens: List.filled(10, 90)),
        constellation('locked', lumens: List.filled(10, 0), unlocked: false),
      ];
      expect(Progression.litShare(states), 1.0);
    });

    test('без открытых созвездий доля нулевая', () {
      expect(Progression.litShare(const []), 0);
    });
  });

  group('рост созвездия', () {
    test('ярус добавляет звёзды, а не заменяет их', () {
      expect(Progression.targetStars(Tier.a0), 12);
      expect(Progression.addedStars(Tier.a0), 12);
      expect(Progression.addedStars(Tier.a1), 12);
      expect(Progression.addedStars(Tier.a2), 24);
      expect(Progression.addedStars(Tier.b2), 24);
    });

    test('сумма прибавок равна итоговому размеру', () {
      var total = 0;
      for (final tier in Tier.values) {
        total += Progression.addedStars(tier);
        expect(total, Progression.targetStars(tier), reason: '$tier');
      }
    });
  });

  group('раскладка неба', () {
    test('позиции детерминированы между запусками', () {
      Map<String, List<StarInput>> input() => {
            'doctor': [
              for (var i = 0; i < 12; i++)
                StarInput(conceptId: 'c$i', lumens: i * 8),
            ],
            'rent': [
              for (var i = 0; i < 8; i++)
                StarInput(conceptId: 'r$i', lumens: 50),
            ],
          };

      final first = SkyLayout.place(constellations: input());
      final second = SkyLayout.place(constellations: input());

      for (var i = 0; i < first.length; i++) {
        expect(first[i].name, second[i].name);
        expect(first[i].center.x, second[i].center.x);
        expect(first[i].center.y, second[i].center.y);
        for (var j = 0; j < first[i].stars.length; j++) {
          expect(first[i].stars[j].position.x, second[i].stars[j].position.x);
          expect(first[i].stars[j].position.y, second[i].stars[j].position.y);
        }
      }
    });

    test('добавление созвездия не двигает уже существующие', () {
      // Небо уплотняется, а не переписывается — это касается и карты.
      final before = SkyLayout.place(constellations: {
        'alpha': [const StarInput(conceptId: 'a', lumens: 10)],
        'beta': [const StarInput(conceptId: 'b', lumens: 10)],
      });
      final after = SkyLayout.place(constellations: {
        'alpha': [const StarInput(conceptId: 'a', lumens: 10)],
        'beta': [const StarInput(conceptId: 'b', lumens: 10)],
        'zeta': [const StarInput(conceptId: 'z', lumens: 10)],
      });

      final alphaBefore = before.firstWhere((c) => c.name == 'alpha');
      final alphaAfter = after.firstWhere((c) => c.name == 'alpha');
      expect(alphaAfter.center.x, alphaBefore.center.x);
      expect(alphaAfter.center.y, alphaBefore.center.y);
    });

    test('звёзды не выходят за радиус своего созвездия', () {
      final placed = SkyLayout.place(constellations: {
        'doctor': [
          for (var i = 0; i < 96; i++)
            StarInput(conceptId: 'c$i', lumens: 50),
        ],
      });

      final c = placed.single;
      for (final star in c.stars) {
        expect(star.position.distanceTo(c.center),
            lessThanOrEqualTo(c.radius * 1.01),
            reason: star.conceptId);
      }
    });

    test('созвездия не налезают друг на друга', () {
      final placed = SkyLayout.place(constellations: {
        for (var i = 0; i < 30; i++)
          'c$i': [
            for (var j = 0; j < 12; j++)
              StarInput(conceptId: 'c$i-$j', lumens: 50),
          ],
      });

      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          final distance = placed[i].center.distanceTo(placed[j].center);
          expect(distance, greaterThan(0),
              reason: '${placed[i].name} и ${placed[j].name} в одной точке');
        }
      }
    });

    test('линий примерно по одной на три звезды', () {
      final placed = SkyLayout.place(constellations: {
        'doctor': [
          for (var i = 0; i < 12; i++)
            StarInput(conceptId: 'c$i', lumens: 50),
        ],
      });

      expect(placed.single.lines, hasLength(4));
      for (final (a, b) in placed.single.lines) {
        expect(a, inInclusiveRange(0, 11));
        expect(b, inInclusiveRange(0, 11));
        expect(a, isNot(b), reason: 'линия сама в себя');
      }
    });

    test('одинокое созвездие в центре карты', () {
      final placed = SkyLayout.place(constellations: {
        'only': [const StarInput(conceptId: 'a', lumens: 10)],
      });
      expect(placed.single.center.x, 0.5);
      expect(placed.single.center.y, 0.5);
    });

    test('созвездие без звёзд не ломает раскладку', () {
      final placed = SkyLayout.place(constellations: {'empty': const []});
      expect(placed.single.stars, isEmpty);
      expect(placed.single.lines, isEmpty);
    });
  });
}
