import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/player.dart';
import '../../domain/entities/tier.dart';
import '../../domain/scoring/records.dart';

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

  /// Затмение: до какого дня пропуски не считаются (M5).
  DateTimeColumn get eclipseUntil => dateTime().nullable()();

  /// Час, в который игрок обычно играет. По нему подстраивается время
  /// напоминания — «удобно ему», а не «удобно нам».
  IntColumn get preferredHour => integer().nullable()();

  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();

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
  /// Идентификатор того, что учат: концепт или фраза. Раньше здесь мог быть
  /// только концепт — фразы памяти не имели вовсе и показывались по одному
  /// разу, без повторений. Для разговорника это означало, что заучить фразу
  /// невозможно в принципе.
  TextColumn get itemId => text()();

  /// Слово или фраза. Значение по умолчанию делает миграцию бесшовной:
  /// всё, что уже лежит в базе, — слова.
  TextColumn get kind => text().withDefault(const Constant('word'))();

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
  Set<Column> get primaryKey => {itemId};
}

/// Журнал ответов: нужен и для дообучения параметров FSRS, и для аналитики.
/// Растёт неограниченно — старше полугода схлопывается в агрегаты (M5).
@TableIndex(name: 'reviews_at', columns: {#at})
@DataClassName('ReviewRow')
class Reviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text()();
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

  /// Заход, в котором сыграна сессия, и его уровень.
  ///
  /// Заход хранится идентификатором, а не вычисляется по перерывам между
  /// записями: правило «полчаса без игры закрывают заход» применяется один
  /// раз, в момент игры. Восстанавливать его потом из таймстампов значило бы
  /// применять то же правило второй раз — и получать другой ответ после
  /// каждой правки константы.
  ///
  /// `null` у записей, сделанных до появления заходов. Их очки настоящие и в
  /// рекорды часа и дня идут, а в рекорд захода — нет: сливать историю без
  /// заходов в один гигантский заход было бы ложью.
  TextColumn get climbId => text().nullable()();
  IntColumn get climbLevel => integer().nullable()();
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

/// Отложенное обслуживание базы: что миграция попросила сделать, но сделать
/// в момент миграции не могла.
///
/// Таблица на две колонки нужна ровно потому, что миграции `user.db` не
/// видно `content.db`: базы отдельные, контентную открывают по языку изучения
/// и копируют из ассетов уже после старта. Помеченная работа выполняется
/// первым же запуском, когда оба файла открыты, и метка снимается.
@DataClassName('MaintenanceRow')
class Maintenance extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Метка «нужно вычистить единицы памяти, которых нет в контенте».
const String pendingItemSweep = 'pending_item_sweep';

/// Пользовательская база. Единственная в проекте, которая мигрирует:
/// контент лежит в отдельной read-only `content.db` и заменяется целиком.
@DriftDatabase(tables: [
  Players,
  WordStates,
  Reviews,
  ConstellationProgress,
  Sessions,
  CustomConcepts,
  Maintenance,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'lumen_user'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // M5: затмения, время напоминания и сами напоминания.
            await m.addColumn(players, players.eclipseUntil);
            await m.addColumn(players, players.preferredHour);
            await m.addColumn(players, players.notificationsEnabled);
          }
          if (from < 3) {
            // Ночной вызов убран вместе с хостингом: он требовал файла на
            // CDN, а держать таблицу под фичу, которой нет, — это мусор,
            // который однажды примут за рабочие данные.
            await m.deleteTable('daily_challenge_results');
          }
          if (from < 4) {
            // Фразы становятся такими же единицами памяти, как слова:
            // своё состояние FSRS, своя яркость, своё место в очереди
            // повторений. Колонка переименована, потому что хранит уже не
            // только концепты, а имя, которое лжёт, хуже отсутствующего.
            await m.alterTable(
              TableMigration(
                wordStates,
                columnTransformer: {
                  wordStates.itemId:
                      const CustomExpression<String>('concept_id'),
                },
                newColumns: [wordStates.kind],
              ),
            );
            await m.alterTable(
              TableMigration(
                reviews,
                columnTransformer: {
                  reviews.itemId: const CustomExpression<String>('concept_id'),
                },
              ),
            );
          }
          if (from < 5) {
            // Аркадные заходы: сессия помнит, в каком заходе и на каком его
            // уровне сыграна. Старые записи остаются с null — и это не
            // пробел в данных, а честное «тогда заходов не было».
            await m.addColumn(sessions, sessions.climbId);
            await m.addColumn(sessions, sessions.climbLevel);
          }
          if (from < 6) {
            // Контент переехал: концепты живут в content/concepts/, часть
            // идентификаторов сменилась. Строки памяти о словах, которых в
            // контенте больше нет, — это не прогресс, а очередь повторений
            // на пустоту.
            //
            // Сама чистка здесь не выполняется, и не может: `user.db` и
            // `content.db` — две отдельные базы с отдельными исполнителями,
            // а контентную ещё и открывают по языку изучения, скопировав из
            // ассетов уже после старта. Узнать отсюда, существует ли
            // `item_id`, нечем. Поэтому миграция только помечает, что
            // чистка нужна, а делает её [sweepUnknownItems] после того, как
            // контентная база открыта.
            await m.createTable(maintenance);
            await into(maintenance).insertOnConflictUpdate(
              MaintenanceCompanion.insert(
                key: pendingItemSweep,
                value: 'v6',
              ),
            );
          }
        },
      );

  // ── Обслуживание ────────────────────────────────────────────────────────

  /// Ждёт ли база чистки единиц памяти.
  Future<bool> needsItemSweep() async {
    final row = await (select(maintenance)
          ..where((t) => t.key.equals(pendingItemSweep)))
        .getSingleOrNull();
    return row != null;
  }

  /// Убирает память о словах и фразах, которых в контенте больше нет.
  ///
  /// [known] — идентификаторы, существующие в контентной базе: концепты плюс
  /// фразы. Проверять по `word_states.kind` нельзя: колонка добавлена для
  /// фраз, но её никто не пишет — все строки лежат со значением по умолчанию
  /// `word`, включая те, чей `item_id` на самом деле идентификатор фразы.
  /// Поэтому принадлежность определяется членством в объединении, а не типом.
  ///
  /// Возвращает, сколько строк убрано. Ноль — нормальный результат: у игрока,
  /// который начал играть после переезда контента, чистить нечего.
  ///
  /// Пустой [known] игнорируется: это означает, что контентная база не
  /// открылась, а не что контент опустел. Снести всю память игрока из-за
  /// неудачного чтения ассета — цена, несопоставимая с задачей.
  Future<int> sweepUnknownItems(Set<String> known) async {
    if (known.isEmpty) return 0;

    final stale = (await select(wordStates).get())
        .map((r) => r.itemId)
        .where((id) => !known.contains(id))
        .toSet();

    await transaction(() async {
      if (stale.isNotEmpty) {
        await (delete(wordStates)..where((t) => t.itemId.isIn(stale))).go();
        await (delete(reviews)..where((t) => t.itemId.isIn(stale))).go();
      }
      await (delete(maintenance)
            ..where((t) => t.key.equals(pendingItemSweep)))
          .go();
    });
    return stale.length;
  }

  // ── Игрок ───────────────────────────────────────────────────────────────

  Future<Player?> loadPlayer() async {
    final row =
        await (select(players)..where((t) => t.id.equals(1))).getSingleOrNull();
    return row == null ? null : _toPlayer(row);
  }

  Future<void> savePlayer(Player player) =>
      into(players).insertOnConflictUpdate(_toPlayerRow(player));

  // ── Память по словам ────────────────────────────────────────────────────

  /// Все известные состояния слов. У активного игрока это несколько тысяч
  /// строк — читается целиком один раз за сессию, а не по слову на круг.
  Future<List<WordStateRow>> loadWordStates() => select(wordStates).get();

  /// Состояние одной единицы памяти — слова или фразы.
  Future<WordStateRow?> loadWordState(String itemId) =>
      (select(wordStates)..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();

  /// Слова к повторению: тот самый запрос, ради которого заведён индекс
  /// `(due, lm_cached)`.
  Future<List<WordStateRow>> loadDueWords(DateTime now, {int limit = 40}) =>
      (select(wordStates)
            ..where((t) => t.due.isSmallerOrEqualValue(now))
            ..orderBy([(t) => OrderingTerm(expression: t.lmCached)])
            ..limit(limit))
          .get();

  /// Записывает новое состояние слова и строку журнала одной транзакцией:
  /// расхождение между памятью и журналом сломало бы дообучение FSRS.
  Future<void> recordReview({
    required WordStatesCompanion state,
    required ReviewsCompanion review,
  }) =>
      transaction(() async {
        await into(wordStates).insertOnConflictUpdate(state);
        await into(reviews).insert(review);
      });

  /// Пересчитанная яркость — производная величина, поэтому обновляется
  /// пачкой и отдельно от самих ответов.
  Future<void> refreshCachedLumens(Map<String, int> byItemId) =>
      batch((b) {
        for (final entry in byItemId.entries) {
          b.update(
            wordStates,
            WordStatesCompanion(lmCached: Value(entry.value)),
            where: (t) => t.itemId.equals(entry.key),
          );
        }
      });

  /// Сколько слов сейчас горит — главная цифра в профиле.
  Future<int> countBurning() async {
    final count = wordStates.itemId.count();
    final row = await (selectOnly(wordStates)
          ..addColumns([count])
          ..where(wordStates.burning.equals(true)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ── Сессии ──────────────────────────────────────────────────────────────

  Future<void> saveSession(SessionsCompanion session) =>
      into(sessions).insert(session);

  Future<List<SessionRow>> loadSessions({int limit = 90}) =>
      (select(sessions)
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.startedAt,
                    mode: OrderingMode.desc,
                  ),
            ])
            ..limit(limit))
          .get();

  /// Сыгранные уровни для стены рекордов: когда, на сколько, в каком заходе.
  ///
  /// Читается вся история, а не последние N: рекорд месяца по девяноста
  /// записям посчитать нельзя, а «лучший заход за всё время» тем более.
  /// Строк здесь единицы тысяч за годы игры, и читаются они на экране
  /// профиля, а не в забеге.
  Future<List<ScoredLevel>> loadScoredLevels() async {
    final rows = await (selectOnly(sessions)
          ..addColumns([sessions.startedAt, sessions.score, sessions.climbId])
          ..where(sessions.score.isBiggerThanValue(0)))
        .get();
    return [
      for (final row in rows)
        ScoredLevel(
          at: row.read(sessions.startedAt)!,
          score: row.read(sessions.score)!,
          climbId: row.read(sessions.climbId),
        ),
    ];
  }

  /// Когда игрок закончил играть в последний раз и в каком заходе.
  ///
  /// Нужно, чтобы решить, продолжается ли заход: правило про полчаса
  /// применяется к этой паре.
  Future<({DateTime at, String? climbId, int level})?> lastPlayed() async {
    final row = await (select(sessions)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return (
      at: row.startedAt,
      climbId: row.climbId,
      level: row.climbLevel ?? 1,
    );
  }

  /// Последние ответы — из них считается медианный отклик.
  Future<List<ReviewRow>> recentReviews({int limit = 500}) =>
      (select(reviews)
            ..orderBy([
              (t) => OrderingTerm(expression: t.at, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .get();

  /// Схлопывает журнал старше [keep]: `Reviews` растёт неограниченно, и у
  /// активного игрока за год он перевалит за сотню тысяч строк
  /// (docs/DATA_MODEL.md).
  ///
  /// Агрегаты не пишем: всё, что нужно для дообучения FSRS, — свежий хвост,
  /// а история годовой давности не влияет ни на интервалы, ни на метрики.
  Future<int> pruneReviews(DateTime now, {Duration keep = const Duration(days: 180)}) =>
      (delete(reviews)..where((t) => t.at.isSmallerThanValue(now.subtract(keep))))
          .go();

  // ── Свои слова ──────────────────────────────────────────────────────────

  Future<List<CustomConceptRow>> loadCustomConcepts() =>
      (select(customConcepts)..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();

  Future<void> replaceCustomConcepts(
    List<CustomConceptsCompanion> items,
  ) =>
      batch((b) {
        b.deleteWhere(customConcepts, (_) => const Constant(true));
        b.insertAll(customConcepts, items);
      });

  /// Полное удаление данных (настройка приватности, M5).
  Future<void> wipe() => transaction(() async {
        await delete(players).go();
        await delete(wordStates).go();
        await delete(reviews).go();
        await delete(constellationProgress).go();
        await delete(sessions).go();
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
        eclipseUntil: row.eclipseUntil,
        preferredHour: row.preferredHour,
        notificationsEnabled: row.notificationsEnabled,
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
        eclipseUntil: Value(p.eclipseUntil),
        preferredHour: Value(p.preferredHour),
        notificationsEnabled: Value(p.notificationsEnabled),
      );
}
