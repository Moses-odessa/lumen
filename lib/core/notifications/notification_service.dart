import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Зависимость объявлена прямо в pubspec, хотя приходит и с плагином
// уведомлений: `TZDateTime` стоит в подписи `zonedSchedule`, то есть тип
// нужен нам самим, а не транзитом. Из пакета берётся только `UTC` —
// готовая `Location` без базы зон, поэтому `initializeTimeZones()` игре не
// нужен. Почему именно UTC — у [NotificationService.scheduleDaily].
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';

/// Ежедневное напоминание.
///
/// Правила из docs/CONCEPT.md, и все три — про уважение:
///
/// 1. **Не «не забудь позаниматься», а конкретика:** «7 звёзд в созвездии
///    Врач тускнеют — две минуты вернут их». Общее напоминание игрок
///    отключает после третьего раза, конкретное — читает. И на его языке, с
///    согласованным числом: строки берутся из [AppLocalizations] — почему
///    это часть того же уважения, записано у [ReminderText].
/// 2. **Максимум одно в день** и в тот час, когда он обычно играет, а не
///    когда удобно нам. Час приходит аргументом `hour` в [scheduleDaily] —
///    там же записано, чего стоило его исполнить и где он всё-таки
///    приблизителен.
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

  /// Ставит одно напоминание на ближайшее наступление часа [hour].
  ///
  /// Планируется ровно одно: «серия напоминаний» — это способ, которым
  /// приложение превращается в источник вины.
  ///
  /// **Почему `zonedSchedule`, а не `periodicallyShowWithDuration`.** Второй
  /// умеет только «через сутки от этой минуты» — он считает от момента
  /// постановки, и часа ему передать некуда. Ровно поэтому [hour] здесь
  /// принимался и не использовался: `ReminderScheduler` считал его из
  /// `preferredHour` и журнала сессий и выбрасывал, а обещание пункта 2
  /// держалось на совпадении. Совпадение было настоящим на одном из двух
  /// путей: расписание ставится в конце ритуала, и сутки оттуда приводили
  /// как раз в час игры. На втором пути — тумблер в настройках — не
  /// приводили никуда: включённое в три ночи напоминание в три ночи и
  /// приходило, каждый день, пока игрок не сыграет.
  ///
  /// **Чем платим за исполненное обещание.** Момент считается в UTC, а не в
  /// поясе игрока, и это выбор, а не небрежность. `zonedSchedule` передаёт
  /// на платформу имя зоны (`location.name`): Android делает из него
  /// `ZoneId.of`, iOS — `[NSTimeZone timeZoneWithName:]`. Имя из базы IANA
  /// («Europe/Berlin») поняли бы оба, но узнать пояс устройства нечем — в
  /// `flutter_local_notifications` такого запроса нет, а нативный плагин
  /// ради одной строки офлайновая игра не несёт. Имя-смещение («+02:00»)
  /// Android принимает, а iOS отдаёт на нём `nil`, и час сломался бы молча
  /// на одной платформе из двух. `UTC` разбирают оба и без базы зон, а сам
  /// момент считается по местным часам игрока — поэтому **первое**
  /// срабатывание приходится точно на его час.
  ///
  /// Цена — у повторов: `matchDateTimeComponents: time` повторяет
  /// абсолютный момент, а не показание часов игрока. Перевод на летнее
  /// время и переезд в другой пояс сдвигают напоминание на разницу
  /// смещений — до следующей постановки, а она случается в конце каждого
  /// ритуала. Уехавший игрок получит несколько напоминаний по «прежнему»
  /// часу, и первая же сессия вернёт их на место; плагин часовых поясов
  /// столько не стоит.
  ///
  /// Два предела рядом с часом, чтобы их не считали починенными.
  /// `inexactAllowWhileIdle` отдаёт точность системе (Doze), то есть «в
  /// час» здесь значит «около часа»: точный будильник просит
  /// `SCHEDULE_EXACT_ALARM` — системный диалог ради напоминания, что хуже
  /// опоздания на несколько минут. И расписание не переживает перезагрузку:
  /// `RECEIVE_BOOT_COMPLETED` в манифесте не объявлено, ресивер плагина без
  /// этого права не поднимается, и напоминание возвращает следующий ритуал.
  ///
  /// [channelName] и [channelDescription] — подписи канала в системных
  /// настройках Android. Они приходят аргументами, а не стоят литералами,
  /// по той же причине, что и текст: их видит игрок, и до сих пор он видел
  /// их по-русски при любом языке интерфейса. Канал заводится при первой
  /// постановке и обновляет подписи при следующей — то есть смена языка
  /// догоняет их так же, как текст напоминания.
  Future<void> scheduleDaily({
    required String title,
    required String body,
    required int hour,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    if (!_ready) return;

    try {
      await cancelAll();
      await _plugin.zonedSchedule(
        _dailyId,
        title,
        body,
        nextOccurrence(hour),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'lumen_daily',
            channelName,
            channelDescription: channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Момент уже абсолютный: он посчитан из местных часов игрока и
        // переведён в UTC, толковать его как «показание часов» не нужно.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Повтор — сутки, тем же способом, которым платформа сама считает
        // «каждый день в это время». Без этого напоминание было бы одно за
        // всю жизнь: игрок, который перестал играть, не получил бы второго,
        // а он и есть тот, кому напоминание адресовано.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[notifications] schedule: $e');
    }
  }

  /// Ближайшее наступление часа [hour] по местным часам игрока — абсолютным
  /// моментом.
  ///
  /// Час зажимается в сутки, а не разворачивается в дату: `DateTime(y, m, d,
  /// 25)` уехал бы в следующий день и сдвинул напоминание тихо, а прийти
  /// сюда может любое число — `preferredHour` это колонка в базе игрока.
  ///
  /// Метод открыт ради теста, и это не удобство: [scheduleDaily] в тестовой
  /// среде не наблюдаем — плагин не инициализируется, `_ready` остаётся
  /// `false`, и метод молча ничего не делает. Момент — единственное, что
  /// сервис считает сам, и спросить его можно только напрямую.
  @visibleForTesting
  static tz.TZDateTime nextOccurrence(int hour) {
    final now = DateTime.now();
    final h = hour.clamp(0, 23);

    var when = DateTime(now.year, now.month, now.day, h);
    if (!when.isAfter(now)) {
      // Следующие сутки — конструктором, а не `+ Duration(days: 1)`: в день
      // перевода часов суток не 24 часа, и сложение сдвинуло бы час на
      // единицу. Переполнение дня `DateTime` нормализует сам.
      when = DateTime(now.year, now.month, now.day + 1, h);
    }
    return tz.TZDateTime.from(when, tz.UTC);
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
///
/// **Строки приходят из [AppLocalizations], а не стоят здесь литералами.**
/// Так было не всегда, и цена прежнего устройства складывалась из двух
/// половин, каждая заметная сама по себе.
///
/// Первая: язык. Напоминание — единственный текст игры, который приходит к
/// человеку сам; экран он открывает по своей воле, уведомление — нет. Русские
/// литералы означали, что игрок с украинским интерфейсом получал на телефон
/// русское сообщение, **в котором имя созвездия уже переведено правильно** —
/// имя собирает `ConstellationNaming` по языку интерфейса. То есть украинское
/// имя стояло в русской обёртке, и выглядело это не как непереведённая
/// строка, а как поломка.
///
/// Вторая: согласование. `'$dimmingStars звёзд тускнеют'` давало «1 звёзд
/// тускнеют» и «21 звёзд тускнеют» — конкатенация числа с одной формой слова
/// не умеет иначе. Поэтому число уезжает в ICU-плюрал в arb
/// (`reminderDimmingTitle`), где у русского и украинского есть все четыре
/// формы, а у языков с двумя — две. Формы выбирает `intl` по правилам CLDR,
/// и добавить язык теперь значит перевести ключ, а не найти это место в коде.
///
/// Кто и когда грузит [AppLocalizations] вне дерева виджетов — записано у
/// `ReminderScheduler.composeText`: `AppLocalizations.delegate.load` берёт
/// локаль аргументом, и `BuildContext` ему не нужен.
abstract final class ReminderText {
  static ({String title, String body}) build({
    required AppLocalizations l10n,
    required int dimmingStars,
    required String? constellation,
    required int orbit,
    required int missesBeforeReset,
  }) {
    if (missesBeforeReset <= 1 && orbit > 0) {
      return (
        title: l10n.reminderOrbitTitle(orbit),
        body: l10n.reminderOrbitBody,
      );
    }

    if (dimmingStars > 0 && constellation != null) {
      return (
        title: l10n.reminderDimmingTitle(dimmingStars),
        body: l10n.reminderDimmingIn(constellation),
      );
    }

    if (dimmingStars > 0) {
      return (
        title: l10n.reminderDimmingTitle(dimmingStars),
        body: l10n.reminderDimmingBody,
      );
    }

    return (
      title: l10n.reminderCalmTitle,
      body: l10n.reminderCalmBody,
    );
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService.instance);
