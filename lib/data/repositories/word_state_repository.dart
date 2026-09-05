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
  Future<MemoryState> load(String conceptId) async {
    final row = await _db.loadWordState(conceptId);
    return row == null ? MemoryState.unseen : _toMemory(row);
  }

  /// Кандидаты на показ. Яркость считается на момент [now], а не берётся из
  /// кеша: кеш нужен базе для сортировки, а игре — точное число.
  Future<List<WordCandidate>> candidates(DateTime now) async {
    final rows = await _db.loadWordStates();
    return [
      for (final row in rows)
        WordCandidate(
          conceptId: row.conceptId,
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
  Future<WordUpdate> applyAnswer({
    required String conceptId,
    required Tier tier,
    required GameMode mode,
    required bool correct,
    required Duration latency,
    required DateTime now,
  }) async {
    final existing = await _db.loadWordState(conceptId);
    final before = existing == null ? MemoryState.unseen : _toMemory(existing);

    final grade = gradeFromLatency(latency, correct: correct);
    final after = fsrs.review(before, grade, now);

    final fastStreak = ScoreRules.nextFastStreak(
      current: existing?.fastStreak ?? 0,
      correct: correct,
      latency: latency,
      mode: mode,
    );

    await _db.recordReview(
      state: WordStatesCompanion(
        conceptId: Value(conceptId),
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
        conceptId: conceptId,
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
              conceptId: Value(entry.key),
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
      for (final row in rows) row.conceptId: _toMemory(row).lumensAt(now),
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
