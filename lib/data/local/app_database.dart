import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/player.dart';
import '../../domain/entities/tier.dart';

part 'app_database.g.dart';

/// Игрок — одна строка (id = 1). Схема — docs/DATA_MODEL.md.
///
/// Строка называется `PlayerRow`, чтобы не столкнуться с доменным [Player]:
/// в домене живёт смысл, в строке — представление в SQLite.
@DataClassName('PlayerRow')
class Players extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get targetLang => text()();
  TextColumn get nativeLang => text()();
  TextColumn get uiLang => text().nullable()();
  TextColumn get tier => text()();
  BoolColumn get calibrated => boolean().withDefault(const Constant(false))();
  IntColumn get orbit => integer().withDefault(const Constant(0))();
  IntColumn get sparks => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn get missedInRow => integer().withDefault(const Constant(0))();
  BoolColumn get freePace => boolean().withDefault(const Constant(false))();
  BoolColumn get soundEnabled =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Состояние одного слова. Источник правды по памяти — тройка FSRS
/// `(difficulty, stability, lastReview)`; `lmCached` — производная величина,
/// нужная только чтобы сортировать «самые тусклые» индексом.
///
/// Индекс по `(due, lmCached)` обслуживает главный запрос планировщика:
/// `WHERE due <= now ORDER BY lm_cached ASC LIMIT 40`.
@TableIndex(name: 'word_states_due_lm', columns: {#due, #lmCached})
@DataClassName('WordStateRow')
class WordStates extends Table {
  TextColumn get conceptId => text()();
  TextColumn get tier => text()();
  RealColumn get difficulty => real()();
  RealColumn get stability => real()();
  DateTimeColumn get lastReview => dateTime().nullable()();
  DateTimeColumn get due => dateTime().nullable()();
  IntColumn get lmCached => integer().withDefault(const Constant(0))();
  IntColumn get fastStreak => integer().withDefault(const Constant(0))();
  BoolColumn get burning => boolean().withDefault(const Constant(false))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {conceptId};
}

/// Журнал ответов: нужен и для дообучения параметров FSRS, и для аналитики.
/// Растёт неограниченно — старше полугода схлопывается в агрегаты (M5).
@TableIndex(name: 'reviews_at', columns: {#at})
@DataClassName('ReviewRow')
class Reviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get conceptId => text()();
  DateTimeColumn get at => dateTime()();
  IntColumn get latencyMs => integer()();
  TextColumn get mode => text()();
  BoolColumn get correct => boolean()();
  IntColumn get grade => integer()();
}

/// Прогресс по созвездию на конкретном ярусе.
@DataClassName('ConstellationProgressRow')
class ConstellationProgress extends Table {
  TextColumn get constellation => text()();
  TextColumn get tier => text()();
  BoolColumn get unlocked => boolean().withDefault(const Constant(false))();
  BoolColumn get lit => boolean().withDefault(const Constant(false))();
  IntColumn get levelsDone => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {constellation, tier};
}

/// Сессии — для ритуала, орбиты и метрик. `lmGained` — прирост яркости,
/// основа рейтинга лиг (M6): фармить повтором лёгкого его нельзя.
@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMs => integer()();
  IntColumn get lmGained => integer()();
  IntColumn get score => integer()();
  IntColumn get newWords => integer()();
}

/// Результат ночного вызова: один заход в день, поэтому день — ключ.
@DataClassName('DailyChallengeResultRow')
class DailyChallengeResults extends Table {
  TextColumn get day => text()();
  IntColumn get correct => integer()();
  IntColumn get total => integer()();
  IntColumn get timeMs => integer()();

  @override
  Set<Column> get primaryKey => {day};
}

/// Свои слова: личное созвездие произвольного размера (M5).
@DataClassName('CustomConceptRow')
class CustomConcepts extends Table {
  TextColumn get id => text()();
  TextColumn get target => text()();
  TextColumn get native => text()();
  TextColumn get deck => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Пользовательская база. Единственная в проекте, которая мигрирует:
/// контент лежит в отдельной read-only `content.db` и заменяется целиком.
@DriftDatabase(tables: [
  Players,
  WordStates,
  Reviews,
  ConstellationProgress,
  Sessions,
  DailyChallengeResults,
  CustomConcepts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'lumen_user'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );

  // ── Игрок ───────────────────────────────────────────────────────────────

  Future<Player?> loadPlayer() async {
    final row =
        await (select(players)..where((t) => t.id.equals(1))).getSingleOrNull();
    return row == null ? null : _toPlayer(row);
  }

  Future<void> savePlayer(Player player) =>
      into(players).insertOnConflictUpdate(_toPlayerRow(player));

  /// Полное удаление данных (настройка приватности, M5).
  Future<void> wipe() => transaction(() async {
        await delete(players).go();
        await delete(wordStates).go();
        await delete(reviews).go();
        await delete(constellationProgress).go();
        await delete(sessions).go();
        await delete(dailyChallengeResults).go();
        await delete(customConcepts).go();
      });

  Player _toPlayer(PlayerRow row) => Player(
        targetLang: row.targetLang,
        nativeLang: row.nativeLang,
        uiLang: row.uiLang,
        tier: Tier.fromCode(row.tier),
        calibrated: row.calibrated,
        orbit: row.orbit,
        sparks: row.sparks,
        lastPlayedAt: row.lastPlayedAt,
        missedInRow: row.missedInRow,
        freePace: row.freePace,
        soundEnabled: row.soundEnabled,
      );

  PlayersCompanion _toPlayerRow(Player p) => PlayersCompanion(
        id: const Value(1),
        targetLang: Value(p.targetLang),
        nativeLang: Value(p.nativeLang),
        uiLang: Value(p.uiLang),
        tier: Value(p.tier.code),
        calibrated: Value(p.calibrated),
        orbit: Value(p.orbit),
        sparks: Value(p.sparks),
        lastPlayedAt: Value(p.lastPlayedAt),
        missedInRow: Value(p.missedInRow),
        freePace: Value(p.freePace),
        soundEnabled: Value(p.soundEnabled),
      );
}
