import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/retention/orbit.dart';
import 'package:lumen/domain/retention/sparks.dart';
import 'package:lumen/domain/scoring/balance.dart';

void main() {
  DateTime day(int d, [int hour = 10]) => DateTime(2026, 4, d, hour);

  group('орбита', () {
    test('первый день игры поднимает орбиту', () {
      final state = Orbit.play(const OrbitState(), day(1));
      expect(state.level, 1);
      expect(state.missedInRow, 0);
      expect(Orbit.playedToday(state, day(1)), isTrue);
    });

    test('второй сеанс в тот же день ничего не добавляет', () {
      // Орбита измеряет дни, а не количество сессий.
      var state = Orbit.play(const OrbitState(), day(1, 9));
      state = Orbit.play(state, day(1, 21));
      expect(state.level, 1);
    });

    test('игра день за днём поднимает орбиту линейно', () {
      var state = const OrbitState();
      for (var d = 1; d <= 5; d++) {
        state = Orbit.play(state, day(d));
      }
      expect(state.level, 5);
    });

    test('один пропуск опускает на один, а не обнуляет', () {
      // Главное отличие от стрика: перелёт не стирает полгода.
      var state = const OrbitState();
      for (var d = 1; d <= 10; d++) {
        state = Orbit.play(state, day(d));
      }
      expect(state.level, 10);

      // Играем через день: 11-е пропущено.
      state = Orbit.play(state, day(12));
      expect(state.level, 10, reason: '10 − 1 пропуск + 1 день игры');
      expect(state.missedInRow, 0);
    });

    test('два пропуска подряд ещё не сбрасывают орбиту', () {
      var state = const OrbitState();
      for (var d = 1; d <= 8; d++) {
        state = Orbit.play(state, day(d));
      }
      final refreshed = Orbit.refresh(state, day(11));

      expect(refreshed.missedInRow, 2);
      expect(refreshed.level, 6);
    });

    test('три пропуска подряд обнуляют', () {
      var state = const OrbitState();
      for (var d = 1; d <= 20; d++) {
        state = Orbit.play(state, day(d));
      }
      final refreshed = Orbit.refresh(state, day(24));

      expect(refreshed.missedInRow, RetentionBalance.orbitResetAfterMisses);
      expect(refreshed.level, 0);
    });

    test('орбита не уходит в минус', () {
      var state = Orbit.play(const OrbitState(), day(1));
      state = Orbit.refresh(state, day(3));
      expect(state.level, greaterThanOrEqualTo(0));
    });

    test('игра после пропуска сбрасывает счётчик пропусков', () {
      var state = const OrbitState();
      for (var d = 1; d <= 5; d++) {
        state = Orbit.play(state, day(d));
      }
      state = Orbit.play(state, day(7));
      expect(state.missedInRow, 0);
    });

    test('до сброса видно, сколько пропусков осталось', () {
      var state = const OrbitState();
      for (var d = 1; d <= 5; d++) {
        state = Orbit.play(state, day(d));
      }
      expect(Orbit.missesBeforeReset(state),
          RetentionBalance.orbitResetAfterMisses);

      state = Orbit.refresh(state, day(8));
      expect(Orbit.missesBeforeReset(state), 1);
    });

    test('у не игравшего пересчёт ничего не делает', () {
      const state = OrbitState();
      expect(Orbit.refresh(state, day(30)).level, 0);
      expect(Orbit.playedToday(state, day(30)), isFalse);
    });

    test('вчерашняя игра пропуском не считается', () {
      var state = Orbit.play(const OrbitState(), day(1));
      state = Orbit.refresh(state, day(2));
      expect(state.missedInRow, 0);
      expect(state.level, 1);
    });
  });

  group('затмение', () {
    test('дни под затмением не считаются пропусками', () {
      var state = const OrbitState();
      for (var d = 1; d <= 5; d++) {
        state = Orbit.play(state, day(d));
      }

      // Уезжаем на неделю, оплатив паузу искрами.
      state = Orbit.eclipse(state, day(5), days: 7);
      final after = Orbit.refresh(state, day(11));

      expect(after.level, 5, reason: 'орбита должна сохраниться');
      expect(after.missedInRow, 0);
    });

    test('после затмения пропуски снова считаются', () {
      var state = const OrbitState();
      for (var d = 1; d <= 5; d++) {
        state = Orbit.play(state, day(d));
      }
      state = Orbit.eclipse(state, day(5), days: 2);

      final after = Orbit.refresh(state, day(12));
      expect(after.missedInRow, greaterThan(0));
      expect(after.level, lessThan(5));
    });
  });

  group('недельная цель', () {
    test('пять дней из семи — цель выполнена', () {
      final played = [day(1), day(2), day(4), day(5), day(7)];
      expect(Orbit.weeklyProgress(played, day(7)), 5);
      expect(Orbit.weeklyGoalMet(played, day(7)), isTrue);
    });

    test('четырёх дней не хватает', () {
      final played = [day(1), day(2), day(4), day(5)];
      expect(Orbit.weeklyGoalMet(played, day(7)), isFalse);
    });

    test('цель оставляет два законных выходных', () {
      expect(RetentionBalance.weeklyGoalDays, lessThan(7));
    });

    test('несколько сессий в один день считаются за один', () {
      final played = [day(1, 8), day(1, 13), day(1, 22)];
      expect(Orbit.weeklyProgress(played, day(1)), 1);
    });

    test('дни старше недели не считаются', () {
      final played = [day(1), day(2), day(20), day(21)];
      expect(Orbit.weeklyProgress(played, day(21)), 2);
    });

    test('будущие дни не считаются', () {
      expect(Orbit.weeklyProgress([day(25)], day(21)), 0);
    });
  });

  group('искры', () {
    test('начисляются от прироста яркости, а не от очков', () {
      // Иначе их можно нафармить повтором лёгкого.
      final little = Sparks.forLevel(lumensGained: 10, newWords: 6);
      final much = Sparks.forLevel(lumensGained: 200, newWords: 6);
      expect(much, greaterThan(little));
    });

    test('за вызов платят по верным ответам', () {
      expect(Sparks.forChallenge(correct: 0, total: 20), 0);
      expect(
        Sparks.forChallenge(correct: 15, total: 20),
        lessThan(Sparks.forChallenge(correct: 20, total: 20)),
      );
    });

    test('безошибочный вызов даёт бонус, но не кратный', () {
      final perfect = Sparks.forChallenge(correct: 20, total: 20);
      final almost = Sparks.forChallenge(correct: 19, total: 20);
      expect(perfect - almost, lessThan(almost));
    });

    test('пустой вызов ничего не приносит', () {
      expect(Sparks.forChallenge(correct: 0, total: 0), 0);
    });

    test('покупка списывает ровно цену', () {
      expect(Sparks.spend(500, SparkPurchase.eclipse),
          500 - SparkPurchase.eclipse.cost);
    });

    test('без денег покупка не проходит', () {
      expect(Sparks.canAfford(10, SparkPurchase.cosmetic), isFalse);
      expect(Sparks.spend(10, SparkPurchase.cosmetic), isNull);
    });

    test('за искры не продаётся ничего, что ограничивает обучение', () {
      // Проверка списка покупок: он закрытый и в нём только пауза, порядок
      // тем и косметика.
      expect(SparkPurchase.values, hasLength(3));
      expect(
        SparkPurchase.values,
        containsAll([
          SparkPurchase.eclipse,
          SparkPurchase.constellation,
          SparkPurchase.cosmetic,
        ]),
      );
    });
  });
}
