import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

/// Час напоминания: доезжает ли он до будильника.
///
/// Проверка появилась потому, что раньше не доезжал: `hour` принимался и не
/// использовался — `periodicallyShowWithDuration` умеет только «через сутки
/// от этой минуты», — а `ReminderScheduler` считал этот час из
/// `preferredHour` и журнала сессий и выбрасывал. Зелёными при этом были все
/// тесты напоминания: они спрашивают текст, а время постановки наблюдаемого
/// результата не имеет вовсе.
///
/// Само уведомление здесь не ставится и поставлено быть не может:
/// `NotificationService` — синглтон с приватным конструктором, в тестовой
/// среде плагин не инициализируется, и `scheduleDaily` молча ничего не
/// делает. Наблюдаемое одно — момент, и он спрашивается напрямую.
void main() {
  /// Момент по местным часам игрока: `TZDateTime` живёт в UTC, а обещание
  /// сервиса — про час на часах человека.
  DateTime localOf(tz.TZDateTime when) =>
      DateTime.fromMillisecondsSinceEpoch(when.millisecondsSinceEpoch);

  test('момент попадает на запрошенный час и он ещё не наступил', () {
    final now = DateTime.now();

    for (var hour = 0; hour < 24; hour++) {
      final when = localOf(NotificationService.nextOccurrence(hour));

      expect(when.hour, hour, reason: 'час $hour: не тот час');
      expect(when.isAfter(now), isTrue, reason: 'час $hour: уже прошёл');
      // Меньше суток с запасом на день перевода часов: в нём 23 или 25
      // часов, и «ближайшее наступление» на сутки не похоже только там.
      expect(when.difference(now).inHours, lessThan(25),
          reason: 'час $hour: дальше, чем через сутки');
    }
  });

  test('час за пределами суток зажимается, а не уезжает в дату', () {
    // `DateTime(y, m, d, 25)` — законный вызов: конструктор развернул бы его
    // в следующий день, час первый, и напоминание сдвинулось бы молча.
    // Число сюда приходит из колонки `preferred_hour` базы игрока.
    expect(localOf(NotificationService.nextOccurrence(24)).hour, 23);
    expect(localOf(NotificationService.nextOccurrence(-1)).hour, 0);
  });

  test('имя зоны — то, которое разберут обе платформы', () {
    // `zonedSchedule` передаёт на платформу `location.name`: Android делает
    // из него `ZoneId.of`, iOS — `[NSTimeZone timeZoneWithName:]`. На
    // имени-смещении («+02:00») iOS отдаёт `nil` и час ломается молча, на
    // «local» падает уже Android. Проверка держит `UTC`, потому что сломать
    // это можно одной строкой и заметить только на устройстве.
    expect(NotificationService.nextOccurrence(20).location.name, 'UTC');
  });
}
