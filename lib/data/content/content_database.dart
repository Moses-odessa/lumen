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

  /// Частотный ранг: чем меньше, тем раньше слово вводится.
  ///
  /// Может отсутствовать, и это не пробел в данных: редакторский словник на
  /// 6000 лемм частотности не несёт, а выдумать её значило бы записать
  /// вымысел в поле, которое читается как измерение. Поэтому все запросы
  /// сортируют «сначала с рангом, потом без»: NULL в SQLite сортируется
  /// первым, и без этого правила слово без частотности вводилось бы раньше
  /// самого частотного.
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
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {conceptId, lang};
}

/// Язык базы: что он о себе объявил и сколько покрывает.
///
/// Таблица нужна затем, чтобы приложение не носило список языков в коде.
/// Раньше `language_screen.dart` держал три карты кодов и названий, и добавить
/// язык означало правку Dart в четырёх местах. Теперь язык — это файл, а
/// экран читает то, что в базе.
@DataClassName('LanguageRow')
class Languages extends Table {
  TextColumn get code => text()();

  /// `native`, `target` или `both`.
  TextColumn get role => text()();

  /// `draft` или `launched`.
  TextColumn get status => text()();

  /// Самоназвание: «Українська», «Deutsch».
  TextColumn get name => text()();

  /// Сколько концептов и фраз язык покрывает. Считается при сборке.
  IntColumn get concepts => integer()();
  IntColumn get phrases => integer()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Фраза: шаблон с одним или несколькими пропусками.
///
/// Ответы уехали в [PhraseSlots]: пропусков может быть больше одного, и это
/// разница между «вставь слово» и «собери грамматику предложения».
@DataClassName('PhraseRow')
class Phrases extends Table {
  TextColumn get id => text()();
  TextColumn get lang => text()();
  TextColumn get tier => text()();
  TextColumn get constellation => text()();
  TextColumn get template => text()();
  TextColumn get register => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Пропуски фразы по порядку слева направо.
@DataClassName('PhraseSlotRow')
class PhraseSlots extends Table {
  TextColumn get phraseId => text()();
  IntColumn get idx => integer()();
  TextColumn get answer => text()();

  @override
  Set<Column> get primaryKey => {phraseId, idx};
}

/// Неверные слова для конкретного пропуска.
///
/// Необязательны: когда их нет, варианты добираются соседями по созвездию.
/// Когда есть — вытесняют добор, потому что подобранное под пропуск всегда
/// лучше подобранного под тему.
@DataClassName('PhraseOptionRow')
class PhraseOptions extends Table {
  TextColumn get phraseId => text()();
  IntColumn get idx => integer()();
  TextColumn get form => text()();

  @override
  Set<Column> get primaryKey => {phraseId, idx, form};
}

/// Перевод фразы целиком на родной язык.
///
/// Проявляется после того, как все пропуски заполнены. Пропуск, заполненный
/// верно, но так и не объяснённый, учит подбору формы и ничему больше.
@DataClassName('PhraseTranslationRow')
class PhraseTranslations extends Table {
  TextColumn get phraseId => text()();
  TextColumn get lang => text()();

  /// В базе колонка называется `text`; в Dart так нельзя — `text()` это
  /// собственный построитель колонок Drift, и совпадение имён ломает
  /// кодогенерацию молча.
  TextColumn get translation => text().named('text')();

  @override
  Set<Column> get primaryKey => {phraseId, lang};
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
  Languages,
  Phrases,
  PhraseSlots,
  PhraseOptions,
  PhraseTranslations,
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
  ///
  /// v2 убрала `audio_id`: озвучка перешла на синтез устройства и произносит
  /// текст лексемы. Идентификатор записанного файла стал не нужен.
  ///
  /// v3 сделала у фразы несколько пропусков и добавила таблицу языков. Первое
  /// нужно механикам «заполни пропуски» и «собери предложение», второе — тому,
  /// чтобы язык добавлялся файлом, а не правкой Dart.
  @override
  int get schemaVersion => 3;

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

  /// Ярусы, вычитанные и разрешённые к игре.
  ///
  /// Правило «язык не запускается, пока его ярусы не вычитаны человеком»
  /// действует и в рантайме: приложение не предлагает подняться туда, где
  /// контент ещё черновой. Пустой список означает старую сборку без этого
  /// поля — тогда разрешаем всё, иначе обновление ассета сломало бы игру.
  Future<Set<Tier>> launchedTiers() async {
    final raw = (await loadMeta())['launched_tiers'];
    if (raw == null || raw.isEmpty) return Tier.values.toSet();
    return raw.split(',').map(Tier.fromCode).toSet();
  }

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
          ..orderBy([
            (t) => OrderingTerm(expression: t.freqRank.isNull()),
            (t) => OrderingTerm(expression: t.freqRank),
          ]))
        .get();
  }

  /// Лексема концепта на языке: форма, артикль, род, число, пометка.
  Future<LexemeRow?> lexeme(String conceptId, String lang) =>
      (select(lexemes)
            ..where((t) => t.conceptId.equals(conceptId) & t.lang.equals(lang)))
          .getSingleOrNull();

  /// Все лексемы языка одним запросом: concept_id → лексема.
  ///
  /// Нужно экранам, которые показывают список: словарь читал по лексеме на
  /// концепт в цикле, то есть два запроса на слово. На 864 концептах это 1728
  /// последовательных ожиданий и заметная пауза; на 6299 — почти тринадцать
  /// тысяч, то есть экран, который не открывается.
  ///
  /// Индекс `lexemes_lang` заведён ровно под этот запрос.
  Future<Map<String, LexemeRow>> lexemesFor(String lang) async {
    final rows =
        await (select(lexemes)..where((t) => t.lang.equals(lang))).get();
    return {for (final row in rows) row.conceptId: row};
  }

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

  /// Сколько концептов на ярусе и ниже.
  ///
  /// Нужно экрану результата калибровки: он говорит игроку, сколькими словами
  /// курса тот примерно уже владеет, и это число обязано приходить из базы.
  Future<int> countConceptsUpTo(Tier upTo) async {
    final codes = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();
    final count = concepts.id.count();
    final row = await (selectOnly(concepts)
          ..addColumns([count])
          ..where(concepts.tier.isIn(codes)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Все концепты яруса и ниже — из них планировщик берёт новые слова.
  Future<List<ConceptRow>> conceptsUpTo(Tier upTo) {
    final tiers = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();
    return (select(concepts)
          ..where((t) => t.tier.isIn(tiers))
          ..orderBy([
            (t) => OrderingTerm(expression: t.freqRank.isNull()),
            (t) => OrderingTerm(expression: t.freqRank),
          ]))
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
  ///
  /// **Порядок не задан, и полагаться на него нельзя.** В созвездии ровно
  /// двенадцать концептов при `limit: 12`, поэтому база отдаёт один и тот же
  /// список в одном и том же порядке всегда. Кто берёт из него меньше, чем
  /// он вернул, обязан сначала перемешать — иначе получит фиксированную
  /// четвёрку соседей навсегда. Так и было: на родном языке своих
  /// дистракторов почти ни у кого нет, и восемь концептов из двенадцати
  /// показывали одни и те же неверные варианты в каждой сессии.
  ///
  /// `ORDER BY` здесь не добавлен намеренно: случайность нужна на каждый
  /// вопрос, а не одна на сборку, и живёт она в `QuestionBuilder`, где есть
  /// свой `Random` с зерном для тестов.
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
  ///
  /// Фильтр по языку обязателен, хотя сегодня в базе один язык изучения:
  /// раньше его не было, и это работало по совпадению. Как только языки
  /// стали находиться перебором каталога, отсутствие фильтра превратилось в
  /// живую ошибку — немецкая фраза попала бы в французскую сборку.
  Future<List<PhraseRow>> phrasesFor(
    String constellation,
    Tier upTo, {
    required String lang,
  }) {
    final tiers = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();
    return (select(phrases)
          ..where((t) =>
              t.constellation.equals(constellation) &
              t.tier.isIn(tiers) &
              t.lang.equals(lang)))
        .get();
  }

  /// Концепты, на которых держится фраза.
  Future<List<String>> phraseConceptIds(String phraseId) async {
    final rows = await (select(phraseConcepts)
          ..where((t) => t.phraseId.equals(phraseId)))
        .get();
    return rows.map((r) => r.conceptId).toList();
  }

  /// Идентификаторы всех фраз базы.
  ///
  /// Нужны чистке `user.db`: фраза — такая же единица памяти, как слово, и
  /// её строку нельзя счесть мусором только потому, что среди концептов
  /// такого id нет.
  Future<Set<String>> allPhraseIds() async {
    final rows = await (selectOnly(phrases)..addColumns([phrases.id])).get();
    return rows.map((r) => r.read(phrases.id)!).toSet();
  }

  /// Ответы фразы по порядку пропусков.
  Future<List<String>> phraseAnswers(String phraseId) async {
    final rows = await (select(phraseSlots)
          ..where((t) => t.phraseId.equals(phraseId))
          ..orderBy([(t) => OrderingTerm(expression: t.idx)]))
        .get();
    return rows.map((r) => r.answer).toList();
  }

  /// Неверные слова по пропускам: индекс слота → формы.
  ///
  /// **Порядок здесь не тот, в котором их написали.** Первичный ключ таблицы
  /// — `(phrase_id, idx, form)`, и SQLite отдаёт строки по нему, то есть по
  /// алфавиту, заглавные раньше строчных. Порядок автора теряется молча.
  ///
  /// Это стоило дефекта, который не видно в исходниках: сборщик берёт из
  /// списка только первые `optionsMax - 1` слов, и при семи вариантах пять
  /// заглавных существительных вытесняли оба строчных прилагательных. В двух
  /// фразах A0 («Das ist zu \_\_\_», «Ich bin sehr \_\_\_») ответ оставался
  /// единственным строчным словом на экране — то есть находился без знания
  /// немецкого, по одной заглавной букве.
  ///
  /// Поэтому порядку этого списка нельзя доверять, и `_fillGaps` его
  /// перемешивает. Восстанавливать авторский порядок отдельной колонкой не
  /// стали намеренно: перемешивание убирает не одну ошибку, а весь класс —
  /// систематическое предпочтение одних слов другим при обрезке, — и заодно
  /// меняет набор от показа к показу.
  Future<Map<int, List<String>>> phraseOptionsFor(String phraseId) async {
    final rows = await (select(phraseOptions)
          ..where((t) => t.phraseId.equals(phraseId))
          ..orderBy([(t) => OrderingTerm(expression: t.idx)]))
        .get();
    final result = <int, List<String>>{};
    for (final row in rows) {
      result.putIfAbsent(row.idx, () => []).add(row.form);
    }
    return result;
  }

  /// Перевод фразы на родной язык; `null`, если его ещё нет.
  Future<String?> phraseTranslation(String phraseId, String lang) async {
    final row = await (select(phraseTranslations)
          ..where((t) => t.phraseId.equals(phraseId) & t.lang.equals(lang)))
        .getSingleOrNull();
    return row?.translation;
  }

  /// Языки базы: код, роль, готовность, самоназвание, покрытие.
  Future<List<LanguageRow>> allLanguages() =>
      (select(languages)..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .get();

  /// Языки, которыми можно подсказывать: `native` или `both`, объявленные
  /// готовыми.
  Future<List<LanguageRow>> nativeLanguages() async {
    final rows = await allLanguages();
    return rows
        .where((l) => l.role == 'native' || l.role == 'both')
        .where((l) => l.status == 'launched')
        .toList();
  }

  /// Языки, на которых можно учить.
  Future<List<LanguageRow>> targetLanguages() async {
    final rows = await allLanguages();
    return rows
        .where((l) => l.role == 'target' || l.role == 'both')
        .where((l) => l.status == 'launched')
        .toList();
  }

  /// Концепты яруса и ниже, у которых есть форма **в обоих** языках пары.
  ///
  /// Это тот запрос, который делает неполный язык безопасным. Раньше нехватку
  /// закрывал английский, и украинский игрок получал в круге английское
  /// слово; это не мягкая деградация, а другой вопрос вместо заданного.
  /// Теперь неполнота означает меньше слов, а не чужие.
  Future<List<ConceptRow>> playableConcepts({
    required String targetLang,
    required String nativeLang,
    required Tier upTo,
  }) async {
    final codes = Tier.values
        .where((t) => t.index <= upTo.index)
        .map((t) => t.code)
        .toList();

    final target = alias(lexemes, 'lt');
    final native = alias(lexemes, 'ln');

    final query = select(concepts).join([
      innerJoin(target, target.conceptId.equalsExp(concepts.id) &
          target.lang.equals(targetLang)),
      innerJoin(native, native.conceptId.equalsExp(concepts.id) &
          native.lang.equals(nativeLang)),
    ])
      ..where(concepts.tier.isIn(codes))
      ..orderBy([
        OrderingTerm(expression: concepts.freqRank.isNull()),
        OrderingTerm(expression: concepts.freqRank),
      ]);

    final rows = await query.get();
    return rows.map((r) => r.readTable(concepts)).toList();
  }
}
