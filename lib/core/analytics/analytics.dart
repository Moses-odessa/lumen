import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// События аналитики. Список закрытый и повторяет метрики из
/// docs/CONCEPT.md: полярная звезда — удержанные слова, а не DAU, поэтому
/// событий про «время в приложении» здесь нет намеренно.
abstract final class AnalyticsEvents {
  // Онбординг и калибровка.
  static const onboardingOpened = 'onboarding_opened';
  static const languagesChosen = 'languages_chosen';
  static const calibrationStarted = 'calibration_started';
  static const calibrationCompleted = 'calibration_completed';
  static const calibrationSkipped = 'calibration_skipped';
  static const tierSuggested = 'tier_suggested';
  static const tierChanged = 'tier_changed';

  // Ядро игры.
  static const runStarted = 'run_started';
  static const runFinished = 'run_finished';
  static const levelCompleted = 'level_completed';
  static const wordBurning = 'word_burning';

  // Ритуал и удержание.
  static const ritualStarted = 'ritual_started';
  static const sunriseCompleted = 'sunrise_completed';
  static const resultShared = 'result_shared';
  static const notificationOpened = 'notification_opened';

  // Небо.
  static const constellationLit = 'constellation_lit';
  static const constellationUnlocked = 'constellation_unlocked';

  // Донаты и данные.
  static const donateOpened = 'donate_opened';
  static const dataExported = 'data_exported';
  static const dataDeleted = 'data_deleted';
}

/// Фасад аналитики. Реализация по умолчанию ничего не отправляет по сети:
/// приложение офлайн-первое, а трекеров в нём нет принципиально.
abstract class AnalyticsService {
  void log(String event, [Map<String, Object?> props = const {}]);
}

/// Реализация по умолчанию — лог в консоль в debug-сборке.
class LoggingAnalytics implements AnalyticsService {
  const LoggingAnalytics();

  @override
  void log(String event, [Map<String, Object?> props = const {}]) {
    if (kDebugMode) {
      debugPrint('[analytics] $event ${props.isEmpty ? '' : props}');
    }
  }
}

final analyticsProvider =
    Provider<AnalyticsService>((ref) => const LoggingAnalytics());
