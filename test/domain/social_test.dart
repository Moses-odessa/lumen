import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/social/duel.dart';
import 'package:lumen/domain/social/league.dart';

void main() {
  LeagueMember member(String id, int lumens, {int days = 3}) =>
      LeagueMember(
        id: id,
        displayName: id,
        lumensGained: lumens,
        daysPlayed: days,
      );

  group('лига', () {
    test('рейтинг строится по приросту яркости', () {
      // Не по XP: любая валюта, которую можно нафармить повтором лёгкого,
      // будет фармиться.
      final table = League.standings([
        member('a', 120),
        member('b', 400),
        member('c', 250),
      ]);

      expect(table.map((s) => s.member.id), ['b', 'c', 'a']);
      expect(table.first.rank, 1);
    });

    test('при равном приросте выше тот, кто играл больше дней', () {
      final table = League.standings([
        member('a', 300, days: 2),
        member('b', 300, days: 6),
      ]);
      expect(table.first.member.id, 'b');
    });

    test('таблица одинакова у всех, кто её открыл', () {
      final members = [
        member('a', 300, days: 3),
        member('b', 300, days: 3),
        member('c', 300, days: 3),
      ];
      final first = League.standings(members).map((s) => s.member.id);
      final second =
          League.standings(members.reversed.toList()).map((s) => s.member.id);
      expect(first, second);
    });

    test('зоны считаются от верха и низа полной группы', () {
      final table = League.standings([
        for (var i = 0; i < League.groupSize; i++)
          member('p$i', League.groupSize - i),
      ]);

      expect(table.first.zone, LeagueZone.promotion);
      expect(table[League.promoted - 1].zone, LeagueZone.promotion);
      expect(table[League.promoted].zone, LeagueZone.stay);
      expect(table.last.zone, LeagueZone.relegation);
    });

    test('в маленькой группе никого не опускают', () {
      // Опускать половину участников неполной группы — издевательство.
      final table = League.standings([
        member('a', 300),
        member('b', 200),
        member('c', 100),
      ]);
      expect(table.map((s) => s.zone), everyElement(isNot(LeagueZone.relegation)));
    });

    test('игрока можно найти в таблице', () {
      final table = League.standings([member('a', 10), member('b', 20)]);
      expect(League.find(table, 'a')!.rank, 2);
      expect(League.find(table, 'нет такого'), isNull);
    });

    test('пустая группа не роняет таблицу', () {
      expect(League.standings(const []), isEmpty);
    });

    test('неделя считается от понедельника в UTC', () {
      // Иначе игроки в разных поясах попадут в разные недели одной группы.
      final monday = DateTime.utc(2026, 6, 1);
      final sunday = DateTime.utc(2026, 6, 7, 23, 59);
      final nextMonday = DateTime.utc(2026, 6, 8);

      expect(League.weekKey(monday), League.weekKey(sunday));
      expect(League.weekKey(nextMonday), isNot(League.weekKey(monday)));
    });
  });

  group('дуэль', () {
    Set<String> vocab(int from, int to) =>
        {for (var i = from; i < to; i++) 'w$i'};

    test('матч идёт только на пересечении словарей', () {
      final shared = Duel.sharedVocabulary(vocab(0, 50), vocab(30, 80));
      expect(shared, hasLength(20));
      expect(shared.every((w) => vocab(30, 50).contains(w)), isTrue);
    });

    test('маленькое пересечение — не дуэль', () {
      // Играть словами, которых соперник не знает, — лотерея, а не матч.
      expect(Duel.canDuel(vocab(0, 50), vocab(45, 60)), isFalse);
      expect(Duel.canDuel(vocab(0, 100), vocab(0, 100)), isTrue);
    });

    test('набор одинаков у обоих участников', () {
      final shared = Duel.sharedVocabulary(vocab(0, 100), vocab(0, 100));
      final mine = Duel.pickWords(shared, seed: 42);
      final theirs = Duel.pickWords(shared, seed: 42);
      expect(mine, theirs);
      expect(mine, hasLength(Duel.pairs));
    });

    test('разные дни дают разные наборы', () {
      final shared = Duel.sharedVocabulary(vocab(0, 100), vocab(0, 100));
      expect(
        Duel.pickWords(shared, seed: 1),
        isNot(Duel.pickWords(shared, seed: 2)),
      );
    });

    test('короткое пересечение берётся целиком', () {
      final shared = ['a', 'b', 'c'];
      expect(Duel.pickWords(shared, seed: 7), shared);
    });

    test('побеждает знание, а не скорость пальцев', () {
      final result = Duel.judge(
        playerCorrect: 18,
        playerTimeMs: 59000,
        opponent: const DuelOpponent(
          id: 'x',
          displayName: 'X',
          kind: OpponentKind.human,
          correct: 15,
          total: 20,
          timeMs: 30000,
        ),
      );
      expect(result.outcome, DuelOutcome.win);
    });

    test('при равном счёте решает время', () {
      final result = Duel.judge(
        playerCorrect: 15,
        playerTimeMs: 40000,
        opponent: const DuelOpponent(
          id: 'x',
          displayName: 'X',
          kind: OpponentKind.human,
          correct: 15,
          total: 20,
          timeMs: 30000,
        ),
      );
      expect(result.outcome, DuelOutcome.loss);
    });

    test('полное равенство — ничья, а не победа по алфавиту', () {
      final result = Duel.judge(
        playerCorrect: 15,
        playerTimeMs: 30000,
        opponent: const DuelOpponent(
          id: 'x',
          displayName: 'X',
          kind: OpponentKind.human,
          correct: 15,
          total: 20,
          timeMs: 30000,
        ),
      );
      expect(result.outcome, DuelOutcome.draw);
    });

    test('призрак честно помечен в результате', () {
      final result = Duel.judge(
        playerCorrect: 10,
        playerTimeMs: 30000,
        opponent: const DuelOpponent(
          id: 'ghost',
          displayName: 'Реплей',
          kind: OpponentKind.ghost,
          correct: 12,
          total: 20,
          timeMs: 28000,
        ),
      );
      expect(result.againstGhost, isTrue);
    });

    test('живой соперник берётся раньше призрака', () {
      const human = DuelOpponent(
        id: 'human',
        displayName: 'Игрок',
        kind: OpponentKind.human,
        correct: 14,
        total: 20,
        timeMs: 40000,
      );
      const ghost = DuelOpponent(
        id: 'ghost',
        displayName: 'Реплей',
        kind: OpponentKind.ghost,
        correct: 10,
        total: 20,
        timeMs: 40000,
      );

      final matched = Duel.matchmake(
        playerVocabulary: vocab(0, 100),
        pool: [(opponent: human, vocabulary: vocab(0, 100))],
        ghost: ghost,
      );
      expect(matched?.id, 'human');
    });

    test('без подходящего живого возвращается призрак', () {
      const ghost = DuelOpponent(
        id: 'ghost',
        displayName: 'Реплей',
        kind: OpponentKind.ghost,
        correct: 10,
        total: 20,
        timeMs: 40000,
      );

      final matched = Duel.matchmake(
        playerVocabulary: vocab(0, 100),
        pool: [
          (
            opponent: const DuelOpponent(
              id: 'far',
              displayName: 'Далёкий',
              kind: OpponentKind.human,
              correct: 0,
              total: 20,
              timeMs: 0,
            ),
            // Пересечение слишком мало для честного матча.
            vocabulary: vocab(200, 220),
          ),
        ],
        ghost: ghost,
      );

      expect(matched?.kind, OpponentKind.ghost);
    });

    test('без соперников и без призрака матча нет', () {
      expect(
        Duel.matchmake(playerVocabulary: vocab(0, 100), pool: const []),
        isNull,
      );
    });

    test('ботов под видом людей не бывает', () {
      // Список видов соперника закрытый: человек и честно помеченный реплей.
      expect(OpponentKind.values, [OpponentKind.human, OpponentKind.ghost]);
    });
  });
}
