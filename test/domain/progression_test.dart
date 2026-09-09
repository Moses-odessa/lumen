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

  group('появление созвездия', () {
    // Прежние тесты этой группы проверяли, что 12+12+24+24+24 = 96, то есть
    // константу саму с собой. Обе функции, которые они вызывали
    // (`targetStars`, `addedStars`), не имели ни одного вызова в приложении и
    // существовали ради этой проверки.

    test('созвездие из нескольких звёзд ещё не созвездие', () {
      expect(Progression.appears(1), isFalse);
      expect(Progression.appears(
        ProgressionBalance.minStarsForConstellation - 1,
      ), isFalse);
    });

    test('на пороге созвездие появляется и больше не исчезает', () {
      expect(
        Progression.appears(ProgressionBalance.minStarsForConstellation),
        isTrue,
      );
      // Размер накопительный: раз появившись, созвездие не может сжаться.
      for (var stars = ProgressionBalance.minStarsForConstellation;
          stars < 400;
          stars += 37) {
        expect(Progression.appears(stars), isTrue, reason: '$stars звёзд');
      }
    });
  });

  group('раскладка неба', () {
    test('позиции детерминированы между запусками', () {
      Map<String, List<StarInput>> input() => {
            'doctor': [
              for (var i = 0; i < 12; i++)
                StarInput(itemId: 'c$i', lumens: i * 8),
            ],
            'rent': [
              for (var i = 0; i < 8; i++)
                StarInput(itemId: 'r$i', lumens: 50),
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
        'alpha': [const StarInput(itemId: 'a', lumens: 10)],
        'beta': [const StarInput(itemId: 'b', lumens: 10)],
      });
      final after = SkyLayout.place(constellations: {
        'alpha': [const StarInput(itemId: 'a', lumens: 10)],
        'beta': [const StarInput(itemId: 'b', lumens: 10)],
        'zeta': [const StarInput(itemId: 'z', lumens: 10)],
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
            StarInput(itemId: 'c$i', lumens: 50),
        ],
      });

      final c = placed.single;
      for (final star in c.stars) {
        expect(star.position.distanceTo(c.center),
            lessThanOrEqualTo(c.radius * 1.01),
            reason: star.itemId);
      }
    });

    test('расстояние между центрами не зависит от числа созвездий', () {
      // Свойство, ради которого радиус на спирали считается от постоянного
      // числа, а не от фактического: добавление созвездия не сдвигает
      // остальные. Из него же следует, что потолок радиуса звёзд можно
      // задать константой.
      for (final count in [9, 15, 24, 30, 40, 50]) {
        final placed = SkyLayout.place(constellations: {
          for (var i = 0; i < count; i++)
            'c$i': [StarInput(itemId: 'c$i-0', lumens: 50)],
        });
        var nearest = double.infinity;
        for (var i = 0; i < placed.length; i++) {
          for (var j = i + 1; j < placed.length; j++) {
            final d = placed[i].center.distanceTo(placed[j].center);
            if (d < nearest) nearest = d;
          }
        }
        expect(nearest, closeTo(SkyLayout.minCenterDistance, 0.001),
            reason: '$count созвездий');
      }
    });

    test('звёзды разных созвездий не налезают друг на друга', () {
      // Прежний тест назывался так же и проверял, что расстояние между
      // центрами больше нуля. Он проходил всегда — и потому не заметил, что
      // созвездия перекрывались на 41 % уже на A0: двум созвездиям по
      // двенадцать звёзд требовалось 0.200 при доступных 0.119.
      //
      // Проверять надо не центры, а то, могут ли отдельные звёзды оказаться
      // в одном месте. Свечению налезать можно, звёздам нельзя.
      for (final stars in [12, 24, 96, 250]) {
        final placed = SkyLayout.place(constellations: {
          for (var i = 0; i < 24; i++)
            'c$i': [
              for (var j = 0; j < stars; j++)
                StarInput(itemId: 'c$i-$j', lumens: 50),
            ],
        });

        for (var i = 0; i < placed.length; i++) {
          for (var j = i + 1; j < placed.length; j++) {
            final distance = placed[i].center.distanceTo(placed[j].center);
            expect(
              distance,
              greaterThanOrEqualTo(placed[i].radius + placed[j].radius - 1e-9),
              reason: '$stars звёзд: ${placed[i].name} и ${placed[j].name} '
                  'перекрываются',
            );
          }
        }
      }
    });

    test('ни одна звезда не уезжает за край карты', () {
      // Карта — это единичный квадрат: виджет умножает нормированные
      // координаты на свой размер и рисует внутри него. Что вышло за [0, 1],
      // не нарисовано и недостижимо — созвездие просто исчезает.
      //
      // Проверка появилась по настоящей потере. Спираль считалась от расчёта
      // на тридцать созвездий, разговорник принёс пятьдесят, и двенадцать из
      // них ушли за границу: у семи за краем оказались звёзды, у двух — сам
      // центр. Прежние тесты этого не видели: они спрашивали расстояния между
      // созвездиями, а не то, лежат ли те на карте.
      //
      // Считается по краю созвездия — центр плюс радиус звёзд, — потому что
      // видна игроку именно звезда, а не центр. Свечение за край выходить
      // может: размытое пятно у границы читается как продолжение неба.
      for (final count in [10, 20, 30, 40, 50]) {
        final placed = SkyLayout.place(constellations: {
          // Двадцать звёзд — столько фраз приносит тема разговорника, то
          // есть настоящий, а не удобный размер созвездия.
          for (var i = 0; i < count; i++)
            'c$i': [
              for (var j = 0; j < 20; j++)
                StarInput(itemId: 'c$i-$j', lumens: 50),
            ],
        });

        for (final c in placed) {
          for (final axis in [
            ('x', c.center.x),
            ('y', c.center.y),
          ]) {
            expect(axis.$2 - c.radius, greaterThanOrEqualTo(0),
                reason: '$count созвездий: ${c.name} за краем по ${axis.$1}');
            expect(axis.$2 + c.radius, lessThanOrEqualTo(1),
                reason: '$count созвездий: ${c.name} за краем по ${axis.$1}');
          }
        }
      }
    });

    test('центры созвездий различны', () {
      final placed = SkyLayout.place(constellations: {
        for (var i = 0; i < 30; i++)
          'c$i': [
            for (var j = 0; j < 12; j++)
              StarInput(itemId: 'c$i-$j', lumens: 50),
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
            StarInput(itemId: 'c$i', lumens: 50),
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
        'only': [const StarInput(itemId: 'a', lumens: 10)],
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
