import 'package:drift/drift.dart';

import '../../domain/entities/tier.dart';
import 'content_executor.dart';

part 'content_database.g.dart';

/// Концепт: смысл, не привязанный ни к одному языку. Мультиязычность стоит
/// O(N), а не O(N²), именно потому, что хранится граф концептов, а не пары
/// переводов (README «Контент и мультиязычность»).
@DataClassName('ConceptRow')
class Concepts extends Table {
  TextColumn get id => text()();
  TextColumn get tier => text()();
  TextColumn get constellation => text()();
  TextColumn get pos => text()();
  IntColumn get freqRank => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Лексема: как концепт выглядит в конкретном языке.
@DataClassName('LexemeRow')
class Lexemes extends Table {
  TextColumn get conceptId => text()();
  TextColumn get lang => text()();
  TextColumn get form => text()();
  TextColumn get article => text().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get plural => text().nullable()();
  TextColumn get audioId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {conceptId, lang};
}

/// Фраза: шаблон со слотами, связывает несколько концептов.
@DataClassName('PhraseRow')
class Phrases extends Table {
  TextColumn get id => text()();
  TextColumn get lang => text()();
  TextColumn get tier => text()();
  TextColumn get constellation => text()();
  TextColumn get template => text()();
  TextColumn get answer => text()();
  TextColumn get register => text().nullable()();
  TextColumn get audioId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhraseConceptRow')
class PhraseConcepts extends Table {
  TextColumn get phraseId => text()();
  TextColumn get conceptId => text()();

  @override
  Set<Column> get primaryKey => {phraseId, conceptId};
}

/// Дистракторы лежат в контенте, а не считаются на лету: качество круга
/// целиком определяется вариантами вокруг, а «созвучные» подбираются по
/// фонетике с человеческой вычиткой (docs/DATA_MODEL.md).
@DataClassName('DistractorRow')
class Distractors extends Table {
  TextColumn get conceptId => text()();
  TextColumn get lang => text()();
  TextColumn get kind => text()();
  TextColumn get form => text()();

  @override
  Set<Column> get primaryKey => {conceptId, lang, form};
}

/// Набор для калибровки: откалиброванные круги по ярусам.
@DataClassName('CalibrationItemRow')
class CalibrationItems extends Table {
  TextColumn get id => text()();
  TextColumn get tier => text()();
  TextColumn get conceptId => text().nullable()();
  TextColumn get phraseId => text().nullable()();
  TextColumn get kind => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Метаданные сборки: язык, версия схемы контента, когда собрано, каким
/// ревизией исходников. Нужны, чтобы приложение могло честно сказать, на
/// каком контенте оно играет, и чтобы валидатор мог отличить старый ассет.
@DataClassName('ContentMetaRow')
class ContentMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Контентная база: **read-only**. Поставляется собранной в ассетах, на
/// устройстве никогда не мигрируется и при обновлении заменяется целиком.
///
/// Поэтому у класса нет ни одного метода записи, а [migration] намеренно
/// падает: если Drift решил, что нужна миграция, значит в ассеты попала база
/// не той версии — это ошибка сборки, а не ситуация, которую надо лечить в
/// рантайме.
@DriftDatabase(tables: [
  Concepts,
  Lexemes,
  Phrases,
  PhraseConcepts,
  Distractors,
  CalibrationItems,
  ContentMeta,
])
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.executor);

  /// Открывает `assets/content/<lang>.db`, скопировав его в
  /// support-директорию при первом запуске.
  ContentDatabase.forLanguage(String lang)
      : super(openContentExecutor(lang));

  /// Версия схемы контента. Меняется вместе с `tool/build_content.dart` и
  /// записывается в `PRAGMA user_version` при сборке.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) => throw StateError(
          'content.db read-only: пустая база означает, что ассет не собран — '
          'запустите dart run tool/build_content.dart',
        ),
        onUpgrade: (_, from, to) => throw StateError(
          'content.db read-only: ассет схемы v$from, приложение ждёт v$to — '
          'пересоберите контент',
        ),
      );

  /// Значения из таблицы метаданных сборки.
  Future<Map<String, String>> loadMeta() async {
    final rows = await select(contentMeta).get();
    return {for (final r in rows) r.key: r.value};
  }

  /// Сколько концептов в базе — самый дешёвый способ убедиться, что ассет
  /// открылся и не пуст (смоук-тест M0).
  Future<int> countConcepts() async {
    final count = concepts.id.count();
    final row = await (selectOnly(concepts)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Концепты созвездия на ярусе и ниже: небо уплотняется, а не
  /// переписывается, поэтому старые звёзды остаются в выборке.
  Future<List<ConceptRow>> conceptsFor(
    String constellation,
    Tier upTo,
  ) {
    final tiers = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();
    return (select(concepts)
          ..where((t) => t.constellation.equals(constellation) & t.tier.isIn(tiers))
          ..orderBy([(t) => OrderingTerm(expression: t.freqRank)]))
        .get();
  }

  /// Лексема концепта на языке — из неё берётся и форма, и `audioId`.
  Future<LexemeRow?> lexeme(String conceptId, String lang) =>
      (select(lexemes)
            ..where((t) => t.conceptId.equals(conceptId) & t.lang.equals(lang)))
          .getSingleOrNull();

  /// Дистракторы концепта нужного типа: `far` — тема, `near` — созвучные.
  Future<List<DistractorRow>> distractorsFor(
    String conceptId,
    String lang,
    String kind,
  ) =>
      (select(distractors)
            ..where((t) =>
                t.conceptId.equals(conceptId) &
                t.lang.equals(lang) &
                t.kind.equals(kind)))
          .get();

  /// Позиции калибровки на ярусе.
  Future<List<CalibrationItemRow>> calibrationFor(Tier tier) =>
      (select(calibrationItems)..where((t) => t.tier.equals(tier.code))).get();

  Future<ConceptRow?> concept(String id) =>
      (select(concepts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Все концепты яруса и ниже — из них планировщик берёт новые слова.
  Future<List<ConceptRow>> conceptsUpTo(Tier upTo) {
    final tiers = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();
    return (select(concepts)
          ..where((t) => t.tier.isIn(tiers))
          ..orderBy([(t) => OrderingTerm(expression: t.freqRank)]))
        .get();
  }

  /// Список созвездий, встречающихся в базе.
  Future<List<String>> constellations() async {
    final rows = await (selectOnly(concepts, distinct: true)
          ..addColumns([concepts.constellation]))
        .get();
    return rows.map((r) => r.read(concepts.constellation)!).toList();
  }

  /// Формы слов-соседей по созвездию и ярусу.
  ///
  /// Резерв на случай, когда у концепта не хватает вычитанных дистракторов:
  /// сосед по теме — вариант заведомо худший, чем подобранный человеком, но
  /// заведомо лучший, чем случайное слово из другого конца словаря.
  Future<List<String>> siblingForms({
    required String constellation,
    required String tier,
    required String lang,
    required String excludeConceptId,
    int limit = 12,
  }) async {
    final query = select(lexemes).join([
      innerJoin(concepts, concepts.id.equalsExp(lexemes.conceptId)),
    ])
      ..where(concepts.constellation.equals(constellation) &
          concepts.tier.equals(tier) &
          lexemes.lang.equals(lang) &
          lexemes.conceptId.equals(excludeConceptId).not())
      ..limit(limit);

    final rows = await query.get();
    return rows.map((r) => r.readTable(lexemes).form).toList();
  }

  /// Фразы созвездия на ярусе и ниже — из них берётся босс уровня.
  Future<List<PhraseRow>> phrasesFor(String constellation, Tier upTo) {
    final tiers = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();
    return (select(phrases)
          ..where((t) =>
              t.constellation.equals(constellation) & t.tier.isIn(tiers)))
        .get();
  }

  /// Концепты, на которых держится фраза.
  Future<List<String>> phraseConceptIds(String phraseId) async {
    final rows = await (select(phraseConcepts)
          ..where((t) => t.phraseId.equals(phraseId)))
        .get();
    return rows.map((r) => r.conceptId).toList();
  }
}
