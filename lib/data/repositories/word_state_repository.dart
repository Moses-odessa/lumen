import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/game_mode.dart';
import '../../domain/entities/tier.dart';
import '../../domain/scheduler/session_planner.dart';
import '../../domain/scoring/balance.dart';
import '../../domain/scoring/score.dart';
import '../../domain/srs/fsrs.dart';
import '../../domain/srs/memory_state.dart';
import '../local/app_database.dart';
import '../local/database_provider.dart';

/// Что стало со словом после ответа.
class WordUpdate {
  const WordUpdate({
    required this.before,
    required this.after,
    required this.fastStreak,
    required this.wasBurning,
  });

  final MemoryState before;
  final MemoryState after;

  /// Верных и быстрых подряд в продуктивных режимах.
  final int fastStreak;

  /// Слово горело до этого ответа.
  final bool wasBurning;

  bool get isBurning => ScoreRules.isBurning(fastStreak);

  /// Слово загорелось именно сейчас — единственный момент, когда об этом
  /// стоит сообщать игроку и аналитике.
  bool get justIgnited => isBurning && !wasBurning;

  /// Сколько люменов вернулось небу. Отрицательное значение — слово
  /// потускнело после ошибки.
  Lumens lumensGained(DateTime now) =>
      after.lumensAt(now) - before.lumensAt(now);
}

/// Мост между чистым FSRS и Drift.
///
/// Здесь и только здесь тройка `(difficulty, stability, lastReview)`
/// превращается в строку таблицы и обратно. Яркость пишется в `lmCached`,
/// но остаётся производной: при расхождении верна тройка.
class WordStateRepository {
  const WordStateRepository(this._db, {this.fsrs = const Fsrs()});

  final AppDatabase _db;
  final Fsrs fsrs;

  /// Состояние памяти по слову; для незнакомого — [MemoryState.unseen].
  Future<MemoryState> load(String itemId) async {
    final row = await _db.loadWordState(itemId);
    return row == null ? MemoryState.unseen : _toMemory(row);
  }

  /// Кандидаты на показ. Яркость считается на момент [now], а не берётся из
  /// кеша: кеш нужен базе для сортировки, а игре — точное число.
  Future<List<StudyItem>> candidates(DateTime now) async {
    final rows = await _db.loadWordStates();
    return [
      for (final row in rows)
        StudyItem(
          itemId: row.itemId,
          tier: Tier.fromCode(row.tier),
          lumens: _toMemory(row).lumensAt(now),
          due: row.due,
        ),
    ];
  }

  /// Применяет один ответ: обновляет память, пишет журнал и возвращает всё,
  /// что об этом ответе нужно знать вызывающему.
  ///
  /// Возвращается именно [WordUpdate], а не одно состояние: серия быстрых
  /// ответов и прирост яркости считаются здесь, где есть и «до», и «после».
  /// Пересчитывать их снаружи означало бы считать их неправильно.
  ///
  /// [tier] нужен только при первом появлении слова — дальше он уже в строке.
  /// [slots] — сколько размещений потребовал ответ: у круга один, у фразы
  /// столько, сколько пропусков. См. `ScoreRules.paceFor`.
  Future<WordUpdate> applyAnswer({
    required String itemId,
    required Tier tier,
    required GameMode mode,
    required bool correct,
    required Duration latency,
    required DateTime now,
    int slots = 1,
  }) async {
    final existing = await _db.loadWordState(itemId);
    final before = existing == null ? MemoryState.unseen : _toMemory(existing);

    // Оценка и серия считаются по времени **на одно размещение**, а запись
    // отзыва хранит исходное: судить по нему нельзя, а знать полезно.
    final pace = ScoreRules.paceFor(latency, slots: slots);
    final grade = gradeFromLatency(pace, correct: correct);
    final after = fsrs.review(before, grade, now);

    final fastStreak = ScoreRules.nextFastStreak(
      current: existing?.fastStreak ?? 0,
      correct: correct,
      latency: pace,
      mode: mode,
    );

    await _db.recordReview(
      state: WordStatesCompanion(
        itemId: Value(itemId),
        tier: Value(existing?.tier ?? tier.code),
        difficulty: Value(after.difficulty),
        stability: Value(after.stability),
        lastReview: Value(after.lastReview),
        due: Value(after.dueAt()),
        lmCached: Value(after.lumensAt(now)),
        fastStreak: Value(fastStreak),
        burning: Value(ScoreRules.isBurning(fastStreak)),
        reps: Value(after.reps),
        lapses: Value(after.lapses),
      ),
      review: ReviewsCompanion.insert(
        itemId: itemId,
        at: now,
        latencyMs: latency.inMilliseconds,
        mode: mode.code,
        correct: correct,
        grade: grade.value,
      ),
    );

    return WordUpdate(
      before: before,
      after: after,
      fastStreak: fastStreak,
      wasBurning: existing?.burning ?? false,
    );
  }

  /// Засев памяти после калибровки: подтверждённые слова стартуют с заданной
  /// яркости и сразу попадают в очередь повторений — не с нуля (M3).
  Future<void> seed({
    required Map<String, Tier> confirmed,
    required Lumens lumens,
    required DateTime now,
  }) async {
    for (final entry in confirmed.entries) {
      final state = seedMemory(lumens: lumens, at: now);
      await _db.into(_db.wordStates).insertOnConflictUpdate(
            WordStatesCompanion(
              itemId: Value(entry.key),
              tier: Value(entry.value.code),
              difficulty: Value(state.difficulty),
              stability: Value(state.stability),
              lastReview: Value(state.lastReview),
              due: Value(state.dueAt()),
              lmCached: Value(state.lumensAt(now)),
              reps: Value(state.reps),
            ),
          );
    }
  }

  /// Пересчитывает кеш яркости. Вызывается при старте сессии: между
  /// запусками звёзды тускнеют, а база об этом не знает.
  Future<void> refreshLumens(DateTime now) async {
    final rows = await _db.loadWordStates();
    await _db.refreshCachedLumens({
      for (final row in rows) row.itemId: _toMemory(row).lumensAt(now),
    });
  }

  Future<int> burningCount() => _db.countBurning();

  MemoryState _toMemory(WordStateRow row) => MemoryState(
        difficulty: row.difficulty,
        stability: row.stability,
        lastReview: row.lastReview,
        reps: row.reps,
        lapses: row.lapses,
      );
}

final wordStateRepositoryProvider = Provider<WordStateRepository>(
  (ref) => WordStateRepository(ref.watch(appDatabaseProvider)),
);
