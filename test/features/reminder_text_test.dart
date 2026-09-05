import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/notifications/notification_service.dart';
import 'package:lumen/features/challenge/application/challenge_client.dart';

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

  group('ключ дня вызова', () {
    test('считается в UTC — вызов один для всех часовых поясов', () {
      final moscowEvening = DateTime.utc(2026, 5, 10, 21).toLocal();
      final key = ChallengeClient.dayKey(moscowEvening);
      expect(key, '2026-05-10');
    });

    test('формат с ведущими нулями', () {
      expect(ChallengeClient.dayKey(DateTime.utc(2026, 1, 3)), '2026-01-03');
    });
  });

  group('клиент вызова', () {
    test('без настроенного CDN вызов просто недоступен', () async {
      final client = ChallengeClient(baseUrl: '');
      expect(client.isConfigured, isFalse);
      expect(await client.load('de', DateTime.utc(2026, 5, 10)), isNull);
    });

    test('разбирает файл дня', () {
      final challenge = DailyChallenge.fromJson({
        'day': '2026-05-10',
        'lang': 'de',
        'seconds': 60,
        'pairs': [
          {
            'concept': 'doctor_person',
            'target': 'Arzt',
            'article': 'der',
            'audio': 'de/arzt',
          },
        ],
      });

      expect(challenge.day, '2026-05-10');
      expect(challenge.duration, const Duration(seconds: 60));
      expect(challenge.pairs.single.target, 'Arzt');
      expect(challenge.pairs.single.article, 'der');
    });

    test('файл без пар не ломает разбор', () {
      final challenge = DailyChallenge.fromJson({
        'day': '2026-05-10',
        'lang': 'de',
      });
      expect(challenge.pairs, isEmpty);
      expect(challenge.duration, const Duration(seconds: 60));
    });
  });
}
