import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/content/content_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/srs/memory_state.dart';

/// Яркость одного созвездия — строка на экране статистики.
class ConstellationBrightness {
  const ConstellationBrightness({
    required this.name,
    required this.averageLumens,
    required this.stars,
    required this.burning,
  });

  final String name;
  final double averageLumens;
  final int stars;
  final int burning;
}

/// Всё, что показывает профиль.
class PlayerStats {
  const PlayerStats({
    required this.orbit,
    required this.weeklyProgress,
    required this.burningWords,
    required this.knownWords,
    required this.medianLatency,
    required this.constellations,
    required this.sparks,
    required this.playedDays,
  });

  final OrbitState orbit;
  final int weeklyProgress;

  /// Горящие слова — главная цифра профиля, а не XP.
  final int burningWords;

  /// Слов, которые игрок хоть раз видел.
  final int knownWords;

  /// Медианный отклик на зрелых словах: целевая метрика из CONCEPT.md
  /// (< 1.8 с). Считается только по ярким словам — на новом материале
  /// скорость ничего не значит.
  final Duration? medianLatency;

  final List<ConstellationBrightness> constellations;
  final int sparks;
  final int playedDays;

  bool get weeklyGoalMet =>
      weeklyProgress >= RetentionBalance.weeklyGoalDays;
}

/// Собирает статистику из журнала ответов и состояния слов.
final playerStatsProvider = FutureProvider<PlayerStats>((ref) async {
  final player = ref.watch(playerControllerProvider);
  final db = ref.watch(appDatabaseProvider);
  final content = ref.watch(currentContentDatabaseProvider);
  final now = DateTime.now();

  final states = await db.loadWordStates();
  final sessions = await db.loadSessions(limit: 60);

  final lumens = <String, Lumens>{};
  var burning = 0;
  for (final row in states) {
    lumens[row.conceptId] = MemoryState(
      difficulty: row.difficulty,
      stability: row.stability,
      lastReview: row.lastReview,
      reps: row.reps,
      lapses: row.lapses,
    ).lumensAt(now);
    if (row.burning) burning++;
  }

  // Яркость по созвездиям: состав берём из контента, значения — из памяти.
  final byConstellation = <String, List<Lumens>>{};
  final burningByConstellation = <String, int>{};
  for (final concept
      in await content.conceptsUpTo(player?.tier ?? Tier.a0)) {
    final value = lumens[concept.id] ?? 0;
    byConstellation.putIfAbsent(concept.constellation, () => []).add(value);
    if (value >= LumenBand.burning.minLm) {
      burningByConstellation.update(
        concept.constellation,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
  }

  final constellations = [
    for (final entry in byConstellation.entries)
      ConstellationBrightness(
        name: entry.key,
        averageLumens: entry.value.isEmpty
            ? 0
            : entry.value.reduce((a, b) => a + b) / entry.value.length,
        stars: entry.value.length,
        burning: burningByConstellation[entry.key] ?? 0,
      ),
  ]..sort((a, b) => b.averageLumens.compareTo(a.averageLumens));

  return PlayerStats(
    orbit: Orbit.refresh(
      OrbitState(
        level: player?.orbit ?? 0,
        missedInRow: player?.missedInRow ?? 0,
        lastPlayedAt: player?.lastPlayedAt,
        eclipseUntil: player?.eclipseUntil,
      ),
      now,
    ),
    weeklyProgress:
        Orbit.weeklyProgress(sessions.map((s) => s.startedAt), now),
    burningWords: burning,
    knownWords: states.length,
    medianLatency: await _medianLatency(db, lumens),
    constellations: constellations,
    sparks: player?.sparks ?? 0,
    playedDays: sessions.length,
  );
});

/// Медиана отклика по зрелым словам.
///
/// Именно медиана, а не среднее: одно отвлечение на минуту искажает среднее
/// так, что метрика перестаёт что-либо значить.
Future<Duration?> _medianLatency(
  AppDatabase db,
  Map<String, Lumens> lumens,
) async {
  final reviews = await db.recentReviews();
  final mature = <int>[];
  for (final review in reviews) {
    if (!review.correct) continue;
    final lm = lumens[review.conceptId] ?? 0;
    if (lm < ScoreBalance.speedBonusMinLm) continue;
    mature.add(review.latencyMs);
  }
  if (mature.isEmpty) return null;
  mature.sort();
  return Duration(milliseconds: mature[mature.length ~/ 2]);
}
