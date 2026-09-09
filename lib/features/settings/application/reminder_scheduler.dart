import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/srs/memory_state.dart';

/// Ставит ежедневное напоминание с конкретным текстом.
///
/// «Не забудь позаниматься» игрок отключает после третьего раза. «7 звёзд в
/// созвездии Врач тускнеют» — читает, потому что это про него и про его
/// небо. Чтобы так написать, нужно посмотреть в базу, а не в шаблон.
class ReminderScheduler {
  const ReminderScheduler(this._ref);

  final Ref _ref;

  Future<void> reschedule() async {
    final player = _ref.read(playerControllerProvider);
    if (player == null || !player.notificationsEnabled) {
      await _ref.read(notificationServiceProvider).cancelAll();
      return;
    }

    try {
      final text = await _composeText(player.tier);
      await _ref.read(notificationServiceProvider).scheduleDaily(
            title: text.title,
            body: text.body,
            // Час игры, а не «удобный нам»: если человек играет вечером,
            // утреннее напоминание для него — просто шум.
            hour: player.preferredHour ?? await _guessHour() ?? 20,
          );
    } catch (_) {
      // Напоминание — сервис, а не механика: его отказ игру не трогает.
    }
  }

  /// Сколько звёзд тускнеет и в каком созвездии их больше всего.
  Future<({String title, String body})> _composeText(Tier tier) async {
    final db = _ref.read(appDatabaseProvider);
    final content = _ref.read(currentContentDatabaseProvider);
    final player = _ref.read(playerControllerProvider);
    final now = DateTime.now();

    final dimming = <String, int>{};
    var total = 0;

    final constellationByItem = {
      for (final p in await content.phrasesUpTo(tier)) p.id: p.constellation,
    };

    for (final row in await db.loadWordStates()) {
      final lm = MemoryState(
        difficulty: row.difficulty,
        stability: row.stability,
        lastReview: row.lastReview,
        reps: row.reps,
        lapses: row.lapses,
      ).lumensAt(now);

      // «Тускнеет» — это полосы ниже уверенного знания, а не всё подряд:
      // напоминание должно называть настоящее число, иначе оно врёт.
      if (lm >= LumenBand.flickering.minLm) continue;
      total++;

      final constellation = constellationByItem[row.itemId];
      if (constellation != null) {
        dimming.update(constellation, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final worst = dimming.isEmpty
        ? null
        : dimming.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final orbit = Orbit.refresh(
      OrbitState(
        level: player?.orbit ?? 0,
        missedInRow: player?.missedInRow ?? 0,
        lastPlayedAt: player?.lastPlayedAt,
        eclipseUntil: player?.eclipseUntil,
      ),
      now,
    );

    return ReminderText.build(
      dimmingStars: total,
      constellation: worst,
      orbit: orbit.level,
      missesBeforeReset: Orbit.missesBeforeReset(orbit),
    );
  }

  /// Час, в который игрок обычно играет — по журналу сессий.
  Future<int?> _guessHour() async {
    try {
      final sessions =
          await _ref.read(appDatabaseProvider).loadSessions(limit: 30);
      if (sessions.isEmpty) return null;

      final byHour = <int, int>{};
      for (final session in sessions) {
        final hour = session.startedAt.toLocal().hour;
        byHour.update(hour, (n) => n + 1, ifAbsent: () => 1);
      }
      return byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    } catch (_) {
      return null;
    }
  }
}

final reminderSchedulerProvider =
    Provider<ReminderScheduler>(ReminderScheduler.new);
