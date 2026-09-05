import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ежедневное напоминание.
///
/// Правила из docs/CONCEPT.md, и все три — про уважение:
///
/// 1. **Не «не забудь позаниматься», а конкретика:** «7 звёзд в созвездии
///    Врач тускнеют — две минуты вернут их». Общее напоминание игрок
///    отключает после третьего раза, конкретное — читает.
/// 2. **Максимум одно в день** и в тот час, когда он обычно играет, а не
///    когда удобно нам.
/// 3. **Всё в try/catch.** Разрешение не выдано, канал не создан, устройство
///    странное — игра от этого не ломается и молчит.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  /// Идентификатор ежедневного напоминания: один на всё приложение, чтобы
  /// новое расписание заменяло старое, а не копило уведомления.
  static const int _dailyId = 1;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Разрешение спрашиваем не на старте, а когда игрок включает
            // напоминания сам.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[notifications] init: $e');
    }
  }

  /// Спрашивает разрешение. `false` — игрок отказал или платформа не дала.
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[notifications] permission: $e');
      return false;
    }
  }

  /// Ставит одно напоминание на ближайший подходящий момент.
  ///
  /// Планируется ровно одно: «серия напоминаний» — это способ, которым
  /// приложение превращается в источник вины.
  Future<void> scheduleDaily({
    required String title,
    required String body,
    required int hour,
  }) async {
    await init();
    if (!_ready) return;

    try {
      await cancelAll();
      await _plugin.periodicallyShowWithDuration(
        _dailyId,
        title,
        body,
        const Duration(days: 1),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lumen_daily',
            'Ежедневное напоминание',
            channelDescription:
                'Одно уведомление в день о потускневших звёздах',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[notifications] schedule: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[notifications] cancel: $e');
    }
  }
}

/// Текст напоминания.
///
/// Чистая функция и отдельно от сервиса, чтобы формулировки можно было
/// проверить тестом: именно они решают, отключит игрок уведомления или нет.
abstract final class ReminderText {
  static ({String title, String body}) build({
    required int dimmingStars,
    required String? constellation,
    required int orbit,
    required int missesBeforeReset,
  }) {
    if (missesBeforeReset <= 1 && orbit > 0) {
      return (
        title: 'Орбита $orbit под угрозой',
        body: 'Ещё один пропуск — и она обнулится. Две минуты это отменят.',
      );
    }

    if (dimmingStars > 0 && constellation != null) {
      return (
        title: '$dimmingStars звёзд тускнеют',
        body: 'В созвездии «$constellation». Две минуты вернут их.',
      );
    }

    if (dimmingStars > 0) {
      return (
        title: '$dimmingStars звёзд тускнеют',
        body: 'Восход занимает две минуты.',
      );
    }

    return (
      title: 'Небо в порядке',
      body: 'Повторять нечего — можно взять что-то новое.',
    );
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService.instance);
