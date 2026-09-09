import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/scoring/play_time.dart';

/// Тесты на время и дни.
///
/// Величины простые, и ровно поэтому их легко посчитать неверно: поле
/// `playedDays` в профиле уже однажды означало «число строк в выборке,
/// ограниченной шестьюдесятью», и читателей у него не было ни одного —
/// иначе ошибку бы заметили.
void main() {
  group('среднее время', () {
    test('считается по дням, когда играл, а не по всем дням', () {
      // Второе было бы честнее к календарю и бесполезнее человеку: «в
      // среднем четыре минуты в день» у того, кто играет по двадцать минут
      // дважды в неделю, не описывает ни одного его дня.
      const time = PlayTime(
        total: Duration(minutes: 40),
        days: 2,
        streak: 0,
        sessions: 4,
      );
      expect(time.perDay, const Duration(minutes: 20));
    });

    test('пустая история не делит на ноль', () {
      const empty = PlayTime.empty();
      expect(empty.perDay, Duration.zero);
      expect(empty.isEmpty, isTrue);
    });

    test('одна сессия — уже не пустая история', () {
      const time = PlayTime(
        total: Duration(minutes: 5),
        days: 1,
        streak: 1,
        sessions: 1,
      );
      expect(time.isEmpty, isFalse);
      expect(time.perDay, const Duration(minutes: 5));
    });
  });
}
