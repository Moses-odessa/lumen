import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/content/content_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/scoring/play_time.dart';
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
    required this.playTime,
    required this.tier,
    required this.tierProgress,
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

  /// Время и дни: всего, в день, дней подряд.
  ///
  /// Здесь было поле `playedDays`, и оно лгало: `sessions.length` по выборке,
  /// ограниченной шестьюдесятью строками, то есть «дней» считалось сессиями и
  /// упиралось в потолок запроса. Читателей у поля не было ни одного — иначе
  /// ошибку бы заметили.
  final PlayTime playTime;

  /// Где игрок на шкале A0→B2.
  final Tier tier;

  /// Насколько заполнен текущий ярус: доля его слов с яркостью не ниже
  /// порога «зажжено».
  ///
  /// Порог взят существующий — [ProgressionBalance.litStarMinLm], тот же, по
  /// которому зажигается созвездие. Заводить рядом второе число «70» значило
  /// бы, что шкала и карта считают прогресс по-разному, и игрок не смог бы
  /// их сопоставить.
  ///
  /// Считается по словам, которые игрок **помнит**, а не видел: «сколько
  /// слов я знаю» в профиле уже показывается тремя разными числами
  /// (горящие по флагу, яркие по 85 lm, известные по факту показа), и
  /// четвёртое с тем же названием было бы издевательством.
  final double tierProgress;

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
    lumens[row.itemId] = MemoryState(
      difficulty: row.difficulty,
      stability: row.stability,
      lastReview: row.lastReview,
      reps: row.reps,
      lapses: row.lapses,
    ).lumensAt(now);
    if (row.burning) burning++;
  }

  // Яркость по созвездиям: состав берём из контента, значения — из памяти.
  final tier = player?.tier ?? Tier.a0;
  final byConstellation = <String, List<Lumens>>{};
  final burningByConstellation = <String, int>{};
  var onTier = 0;
  var litOnTier = 0;

  for (final concept in await content.conceptsUpTo(tier)) {
    final value = lumens[concept.id] ?? 0;
    byConstellation.putIfAbsent(concept.constellation, () => []).add(value);
    if (value >= LumenBand.burning.minLm) {
      burningByConstellation.update(
        concept.constellation,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    // Заполнение шкалы считается по словам **текущего** яруса, а не по всему,
    // что ниже: иначе на B1 шкала показывала бы почти полный ярус за счёт
    // выученного A0, и подъём выше выглядел бы как откат назад.
    if (concept.tier != tier.code) continue;
    onTier++;
    if (value >= ProgressionBalance.litStarMinLm) litOnTier++;
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
    playTime: await db.loadPlayTime(now),
    tier: tier,
    tierProgress: onTier == 0 ? 0 : litOnTier / onTier,
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
    final lm = lumens[review.itemId] ?? 0;
    if (lm < ScoreBalance.speedBonusMinLm) continue;
    mature.add(review.latencyMs);
  }
  if (mature.isEmpty) return null;
  mature.sort();
  return Duration(milliseconds: mature[mature.length ~/ 2]);
}
