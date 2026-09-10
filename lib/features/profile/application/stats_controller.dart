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
    required this.constellation,
    required this.averageLumens,
    required this.stars,
    required this.bright,
  });

  /// Slug темы: идентичность, по которой фразы группируются ниже, а **не**
  /// подпись для игрока.
  ///
  /// Поле звалось `name`, и экран печатал его как есть — отсюда
  /// `place_time_price` в списке яркости. Одно слово значило две вещи
  /// (идентичность темы и подпись), и промахнуться было нечем: что подписывать
  /// этим нельзя, нигде не написано. Теперь имя для показа получает экран через
  /// `ConstellationNaming` — почему именно экран, разобрано у `ProfileScreen`,
  /// — а поле называется тем, чем является.
  ///
  /// Имени для показа в классе нет вовсе, и это тоже решение: положить его сюда
  /// значило бы сделать язык интерфейса зависимостью статистики — смена языка
  /// пересчитывала бы состояния слов, сессии, все фразы яруса и медиану
  /// отклика ради одной строки в каждой строке списка.
  final String constellation;

  final double averageLumens;
  final int stars;

  /// Сколько звёзд созвездия яркие — тем же порогом
  /// [ProgressionBalance.litStarMinLm], которым считает карточка созвездия на
  /// небе (`ConstellationState.litStars`).
  ///
  /// Поле звалось `burning` и считалось по [LumenBand.burning] (85 lm), то
  /// есть профиль и небо отвечали разными числами на **один и тот же** вопрос
  /// про одно и то же созвездие: «сколько его звёзд светит достаточно». Порог
  /// 85 не значил здесь ничего — сравнить это число было не с чем, а полоса
  /// «горит» и без него видна в подписи яркости рядом. Порог 70 значит
  /// ровно одно и то же на обоих экранах: столько звёзд идёт в зачёт
  /// зажжения созвездия, и разница между 70 и 85 больше не выглядит как
  /// расхождение данных.
  final int bright;
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

  /// Фразы «на автомате» — главная цифра профиля, а не XP.
  ///
  /// Это флаг `word_states.burning`: три верных ответа подряд быстрее
  /// [ScoreBalance.burningLatency] в продуктивной механике. Яркостью он не
  /// является вовсе — потому и подписан на экране словом про скорость, а не
  /// про свет. Раньше подпись была та же, что у трёх пороговых чисел
  /// («світять»), и профиль показывал «0 світять» рядом со небом, где светили
  /// пять: у новичка этого флага быть не может по построению, а яркость у
  /// него есть с первого дня.
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
  /// Считается по фразам, которые игрок **помнит**, а не видел: «сколько
  /// фраз я знаю» в профиле показывается тремя разными числами (на автомате
  /// — по флагу скорости, яркие — по [ProgressionBalance.litStarMinLm],
  /// известные — по факту показа), и четвёртое с тем же названием было бы
  /// издевательством.
  ///
  /// Три числа остались, но у каждого теперь своё слово на экране. Раньше
  /// слово было одно, и считалось им четыре разных порога — три здесь и
  /// сводка неба (`SkySnapshot.litStars`, 15 lm), которая в этот учёт не
  /// попала. Что с чем развели — записано у [ConstellationBrightness.bright]
  /// и [burningWords].
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
  final brightByConstellation = <String, int>{};
  var onTier = 0;
  var litOnTier = 0;

  for (final phrase in await content.phrasesUpTo(tier)) {
    final value = lumens[phrase.id] ?? 0;
    byConstellation.putIfAbsent(phrase.constellation, () => []).add(value);
    // Порог тот же, что у карточки созвездия на небе, а не
    // `LumenBand.burning`: почему — у `ConstellationBrightness.bright`.
    if (value >= ProgressionBalance.litStarMinLm) {
      brightByConstellation.update(
        phrase.constellation,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    // Заполнение шкалы считается по фразам **текущего** яруса, а не по всему,
    // что ниже: иначе на B1 шкала показывала бы почти полный ярус за счёт
    // выученного A0, и подъём выше выглядел бы как откат назад.
    if (phrase.tier != tier.code) continue;
    onTier++;
    if (value >= ProgressionBalance.litStarMinLm) litOnTier++;
  }

  final constellations = [
    for (final entry in byConstellation.entries)
      ConstellationBrightness(
        constellation: entry.key,
        averageLumens: entry.value.isEmpty
            ? 0
            : entry.value.reduce((a, b) => a + b) / entry.value.length,
        stars: entry.value.length,
        bright: brightByConstellation[entry.key] ?? 0,
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
