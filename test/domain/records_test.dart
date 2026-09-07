import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/records.dart';

/// Стена рекордов: облака нет, соперник — ты вчерашний.
///
/// Тонкое место здесь одно, и оно не в арифметике: **текущее окно не должно
/// попадать в рекорд**. Иначе «рекорд часа» побивается сам собой на каждом
/// круге, цифра всегда равна текущей, и цели не остаётся.
void main() {
  final now = DateTime.utc(2026, 9, 7, 14, 30);

  ScoredLevel at(DateTime when, int score, {String? climb}) =>
      ScoredLevel(at: when, score: score, climbId: climb);

  group('час', () {
    test('рекорд берётся из закрытого часа, а не из текущего', () {
      final wall = RecordWall.from([
        // Прошлый час: 900.
        at(DateTime.utc(2026, 9, 7, 13, 5), 400),
        at(DateTime.utc(2026, 9, 7, 13, 40), 500),
        // Текущий час: 1200 — больше, но час ещё не кончился.
        at(DateTime.utc(2026, 9, 7, 14, 10), 1200),
      ], now);

      final hour = wall[RecordWindow.hour]!;
      expect(hour.best, 900);
      expect(hour.current, 1200);
      // Текущее уже лучше рекорда — это и есть то, что показывают игроку.
      expect(hour.isRecordNow, isTrue);
      expect(hour.remaining, 0);
    });

    test('до рекорда считается остаток', () {
      final wall = RecordWall.from([
        at(DateTime.utc(2026, 9, 7, 11, 0), 2000),
        at(DateTime.utc(2026, 9, 7, 14, 5), 750),
      ], now);

      final hour = wall[RecordWindow.hour]!;
      expect(hour.best, 2000);
      expect(hour.current, 750);
      expect(hour.remaining, 1250);
      expect(hour.isRecordNow, isFalse);
    });

    test('часы не сливаются между днями', () {
      // Четырнадцать часов вчера и четырнадцать сегодня — разные ведра.
      final wall = RecordWall.from([
        at(DateTime.utc(2026, 9, 6, 14, 10), 3000),
        at(DateTime.utc(2026, 9, 7, 14, 10), 100),
      ], now);
      expect(wall[RecordWindow.hour]!.best, 3000);
      expect(wall[RecordWindow.hour]!.current, 100);
    });
  });

  group('день, неделя, месяц', () {
    test('суммы складываются по своим вёдрам', () {
      final wall = RecordWall.from([
        // Прошлый месяц, прошлая неделя, прошлый день.
        at(DateTime.utc(2026, 8, 20, 9), 1000),
        at(DateTime.utc(2026, 8, 20, 11), 500),
        // Эта неделя, но прошлый день.
        at(DateTime.utc(2026, 9, 6, 10), 700),
        // Сегодня.
        at(DateTime.utc(2026, 9, 7, 9), 200),
      ], now);

      expect(wall[RecordWindow.day]!.best, 1500);
      expect(wall[RecordWindow.day]!.current, 200);
      expect(wall[RecordWindow.month]!.best, 1500);
      // Текущий месяц: 700 + 200.
      expect(wall[RecordWindow.month]!.current, 900);
    });

    test('неделя считается по ISO: понедельник начинает', () {
      // 6 сентября 2026 — воскресенье, 7-е — понедельник. Значит это разные
      // недели, и сливать их нельзя.
      final wall = RecordWall.from([
        at(DateTime.utc(2026, 9, 6, 12), 800),
        at(DateTime.utc(2026, 9, 7, 12), 100),
      ], now);
      expect(wall[RecordWindow.week]!.best, 800);
      expect(wall[RecordWindow.week]!.current, 100);
    });

    test('конец декабря и начало января не попадают в одну неделю', () {
      // Ровно та ошибка, из-за которой год берётся у четверга недели, а не
      // у самого дня.
      final wall = RecordWall.from([
        at(DateTime.utc(2025, 12, 29, 12), 500), // понедельник
        at(DateTime.utc(2026, 1, 5, 12), 900), // следующий понедельник
      ], DateTime.utc(2026, 3, 1));
      expect(wall[RecordWindow.week]!.best, 900);
    });
  });

  group('заход', () {
    test('лучший заход — сумма его уровней', () {
      final wall = RecordWall.from([
        at(DateTime.utc(2026, 9, 5, 10), 300, climb: 'c1'),
        at(DateTime.utc(2026, 9, 5, 10, 8), 500, climb: 'c1'),
        at(DateTime.utc(2026, 9, 5, 10, 17), 700, climb: 'c1'),
        at(DateTime.utc(2026, 9, 6, 10), 400, climb: 'c2'),
      ], now);
      expect(wall[RecordWindow.climb]!.best, 1500);
    });

    test('открытый заход не идёт в рекорд, но виден как текущий', () {
      final wall = RecordWall.from([
        at(DateTime.utc(2026, 9, 5, 10), 900, climb: 'c1'),
        // Последняя запись свежая — заход ещё идёт.
        at(DateTime.utc(2026, 9, 7, 14, 20), 2000, climb: 'c2'),
      ], now);
      final climb = wall[RecordWindow.climb]!;
      expect(climb.best, 900);
      expect(climb.current, 2000);
    });

    test('заход, закрытый перерывом, попадает в рекорд', () {
      final last =
          now.subtract(ClimbBalance.idleClosesClimb + const Duration(minutes: 1));
      final wall = RecordWall.from([
        at(last, 2500, climb: 'c9'),
      ], now);
      final climb = wall[RecordWindow.climb]!;
      expect(climb.best, 2500);
      expect(climb.current, 0);
    });

    test('записи без захода не считаются заходом', () {
      // История, накопленная до появления заходов, не должна превращаться в
      // один гигантский рекорд.
      final wall = RecordWall.from([
        at(DateTime.utc(2026, 9, 1, 10), 5000),
        at(DateTime.utc(2026, 9, 2, 10), 5000),
      ], now);
      expect(wall[RecordWindow.climb]!.best, 0);
      // При этом день и месяц по ним считаются: очки настоящие.
      expect(wall[RecordWindow.day]!.best, 5000);
    });
  });

  group('пустая история', () {
    test('все окна нулевые и ни одно не объявляется рекордом', () {
      final wall = RecordWall.from(const [], now);
      for (final window in RecordWindow.values) {
        final entry = wall[window]!;
        expect(entry.best, 0, reason: '$window');
        expect(entry.current, 0, reason: '$window');
        // Нулевой результат не рекорд: поздравлять не с чем.
        expect(entry.isRecordNow, isFalse, reason: '$window');
      }
    });
  });
}
