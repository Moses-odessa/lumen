import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/notifications/notification_service.dart';

/// Формулировки напоминаний проверяются тестом, потому что именно они решают,
/// отключит игрок уведомления или нет. «Не забудь позаниматься» отключают
/// после третьего раза.
void main() {
  group('текст напоминания', () {
    test('называет конкретное число звёзд и созвездие', () {
      final text = ReminderText.build(
        dimmingStars: 7,
        constellation: 'doctor',
        orbit: 5,
        missesBeforeReset: 3,
      );

      expect(text.title, contains('7'));
      expect(text.body, contains('doctor'));
      // Обещание времени — часть договорённости: две минуты, а не «занятие».
      expect(text.body, contains('Две минуты'));
    });

    test('без созвездия всё равно называет число', () {
      final text = ReminderText.build(
        dimmingStars: 12,
        constellation: null,
        orbit: 3,
        missesBeforeReset: 3,
      );
      expect(text.title, contains('12'));
      expect(text.body, isNotEmpty);
    });

    test('угроза орбите важнее тускнеющих звёзд', () {
      // Орбиту можно потерять безвозвратно, а звёзды вернутся.
      final text = ReminderText.build(
        dimmingStars: 40,
        constellation: 'doctor',
        orbit: 12,
        missesBeforeReset: 1,
      );
      expect(text.title, contains('12'));
      expect(text.body, contains('пропуск'));
    });

    test('без орбиты угрозой не пугаем', () {
      final text = ReminderText.build(
        dimmingStars: 5,
        constellation: 'rent',
        orbit: 0,
        missesBeforeReset: 1,
      );
      expect(text.title, contains('5'));
    });

    test('когда повторять нечего, напоминание не выдумывает повод', () {
      final text = ReminderText.build(
        dimmingStars: 0,
        constellation: null,
        orbit: 4,
        missesBeforeReset: 3,
      );
      expect(text.title, 'Небо в порядке');
      expect(text.body, contains('новое'));
    });
  });
}
