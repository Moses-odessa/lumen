import 'package:drift/drift.dart';

import '../../domain/entities/tier.dart';
import 'content_executor.dart';

part 'content_database.g.dart';

/// Языки базы: код, роль, готовность, самоназвание и покрытие.
///
/// Язык объявляет о себе сам — списка языков в коде нет. Покрытие
/// **считается** при сборке, а не объявляется в файле: объявленное число
/// разошлось бы с содержимым при первой же правке.
@DataClassName('LanguageRow')
class Languages extends Table {
  TextColumn get code => text()();

  /// `native` — на нём подсказки, `target` — его учат, `both` — и то и то.
  TextColumn get role => text()();

  /// `draft` или `launched`. Черновой язык лежит в репозитории, но игроку
  /// не предлагается.
  TextColumn get status => text()();

  /// Самоназвание: «Українська», «Deutsch». На языке самого языка.
  TextColumn get name => text()();

  /// Сколько фраз язык покрывает.
  IntColumn get phrases => integer()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Фраза — единица изучения.
///
/// Разговорник: игрок заучивает фразу целиком, а не слово. Поэтому у фразы
/// нет ни пропусков, ни разбора на слова — есть готовый к показу [text],
/// ярус, созвездие и перевод в [PhraseTranslations].
@DataClassName('PhraseRow')
class Phrases extends Table {
  TextColumn get id => text()();

  /// Язык изучения, на котором написана фраза.
  TextColumn get lang => text()();

  TextColumn get tier => text()();
  TextColumn get constellation => text()();

  /// Порядок внутри созвездия и яруса, как в файле контента.
  ///
  /// Прежнюю последовательность знакомства задавала частотность слова, а у
  /// фразы частотности нет: порядок решает автор, и он же решает, с чего
  /// начинается тема.
  IntColumn get idx => integer()();

  /// Готовая к показу фраза.
  ///
  /// Геттер называется не `text`, и это не вкус: `text()` — билдер колонки в
  /// Drift, и `TextColumn get text => text()()` рекурсивно возвращает сам
  /// себя. Имя колонки в SQL при этом остаётся `text`.
  TextColumn get sentence => text().named('text')();

  /// Регистр: `casual` или `formal`. Код, а не текст — строку даёт
  /// локализация на языке интерфейса.
  TextColumn get register => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Перевод фразы на родной язык. Живёт в языковом файле, а не рядом с
/// фразой: язык добавляется одним файлом.
@DataClassName('PhraseTranslationRow')
class PhraseTranslations extends Table {
  TextColumn get phraseId => text()();
  TextColumn get lang => text()();

  /// Имя колонки в SQL — `text`; геттер другой, потому что `text()` в Drift
  /// это билдер колонки.
  TextColumn get sentence => text().named('text')();

  @override
  Set<Column> get primaryKey => {phraseId, lang};
}

/// Отобранные фразы для калибровки: по кругу через созвездия, по несколько
/// на ярус.
@DataClassName('CalibrationItemRow')
class CalibrationItems extends Table {
  TextColumn get id => text()();
  TextColumn get tier => text()();
  TextColumn get phraseId => text()();

  /// Вид шага теста — гребёнка, поиск, подтверждение.
  TextColumn get kind => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Метаданные сборки: язык, версия схемы, отпечаток исходников, запущенные
/// ярусы. Метки времени здесь нет намеренно — сборка обязана быть
/// воспроизводимой байт-в-байт.
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
  Languages,
  Phrases,
  PhraseTranslations,
  CalibrationItems,
  ContentMeta,
])
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.executor);

  /// Открывает `assets/content/<lang>.db`, скопировав его в
  /// support-директорию при первом запуске.
  ContentDatabase.forLanguage(String lang) : super(openContentExecutor(lang));

  /// Версия схемы контента. Меняется вместе с `tool/build_content.dart` и
  /// записывается в `PRAGMA user_version` при сборке.
  ///
  /// v2 убрала `audio_id`: озвучка перешла на синтез устройства.
  ///
  /// v3 сделала у фразы несколько пропусков и добавила таблицу языков.
  ///
  /// v4 сменила устройство фразовой механики: `phrase_options` уехала, на её
  /// место встала `phrase_orders`.
  ///
  /// **v5 — разговорник.** Единицей изучения стала фраза, и вместе с
  /// отдельным словом ушли шесть таблиц: `concepts`, `lexemes`,
  /// `distractors`, `phrase_slots`, `phrase_orders`, `phrase_concepts`.
  /// Осталось пять.
  @override
  int get schemaVersion => 5;

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
  /// Правило «язык не запускается, пока его ярусы не вычитаны» действует и в
  /// рантайме: приложение не предлагает подняться туда, где контент ещё
  /// черновой. Пустое поле означает старую сборку — тогда разрешаем всё,
  /// иначе обновление ассета сломало бы игру.
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

  /// Сколько фраз в базе — самый дешёвый способ убедиться, что ассет
  /// открылся и не пуст.
  Future<int> countPhrases() async {
    final count = phrases.id.count();
    final row = await (selectOnly(phrases)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  List<String> _tiersUpTo(Tier upTo) => Tier.values
      .where((t) => t.index <= upTo.index)
      .map((t) => t.code)
      .toList();

  /// Фразы созвездия на ярусе и ниже: небо уплотняется, а не переписывается,
  /// поэтому старые фразы остаются в выборке.
  Future<List<PhraseRow>> phrasesFor(String constellation, Tier upTo) =>
      (select(phrases)
            ..where((p) => p.constellation.equals(constellation))
            ..where((p) => p.tier.isIn(_tiersUpTo(upTo)))
            ..orderBy([
              (p) => OrderingTerm(expression: p.tier),
              (p) => OrderingTerm(expression: p.idx),
            ]))
          .get();

  /// Все фразы яруса и ниже, в порядке яруса и авторской последовательности.
  ///
  /// Порядок задан явно, и это важно: по нему идёт знакомство. Прежний
  /// запрос по концептам сортировал по частотности слова — у фразы её нет.
  Future<List<PhraseRow>> phrasesUpTo(Tier upTo) => (select(phrases)
        ..where((p) => p.tier.isIn(_tiersUpTo(upTo)))
        ..orderBy([
          (p) => OrderingTerm(expression: p.tier),
          (p) => OrderingTerm(expression: p.constellation),
          (p) => OrderingTerm(expression: p.idx),
        ]))
      .get();

  /// Фразы **ровно** этого яруса, в авторском порядке.
  ///
  /// Нужны калибровке: она мерит ярус, а не всё, что ниже. Круг с фразой A0
  /// на пробе B1 ничего не измерил бы.
  Future<List<PhraseRow>> phrasesOn(Tier tier) => (select(phrases)
        ..where((p) => p.tier.equals(tier.code))
        ..orderBy([
          (p) => OrderingTerm(expression: p.constellation),
          (p) => OrderingTerm(expression: p.idx),
        ]))
      .get();

  Future<int> countPhrasesUpTo(Tier upTo) async {
    final count = phrases.id.count();
    final row = await (selectOnly(phrases)
          ..addColumns([count])
          ..where(phrases.tier.isIn(_tiersUpTo(upTo))))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Future<PhraseRow?> phrase(String id) =>
      (select(phrases)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Set<String>> allPhraseIds() async {
    final rows = await select(phrases).get();
    return rows.map((r) => r.id).toSet();
  }

  /// Созвездия в порядке появления: по ярусу первой фразы, потом по имени.
  Future<List<String>> constellations() async {
    final rows = await (select(phrases)
          ..orderBy([
            (p) => OrderingTerm(expression: p.tier),
            (p) => OrderingTerm(expression: p.constellation),
          ]))
        .get();
    final seen = <String>[];
    for (final row in rows) {
      if (!seen.contains(row.constellation)) seen.add(row.constellation);
    }
    return seen;
  }

  /// Перевод одной фразы.
  Future<String?> translation(String phraseId, String lang) async {
    final row = await (select(phraseTranslations)
          ..where((t) => t.phraseId.equals(phraseId))
          ..where((t) => t.lang.equals(lang)))
        .getSingleOrNull();
    return row?.sentence;
  }

  /// Переводы пачкой: `id → текст`.
  ///
  /// Круг требует шесть текстов сразу, и спрашивать их по одному значило бы
  /// шесть запросов на каждый круг забега.
  Future<Map<String, String>> translationsFor(
    Iterable<String> phraseIds,
    String lang,
  ) async {
    final ids = phraseIds.toList();
    if (ids.isEmpty) return const {};
    final rows = await (select(phraseTranslations)
          ..where((t) => t.phraseId.isIn(ids))
          ..where((t) => t.lang.equals(lang)))
        .get();
    return {for (final r in rows) r.phraseId: r.sentence};
  }

  Future<List<CalibrationItemRow>> calibrationFor(Tier tier) =>
      (select(calibrationItems)..where((c) => c.tier.equals(tier.code))).get();

  Future<List<LanguageRow>> allLanguages() =>
      (select(languages)..orderBy([(l) => OrderingTerm(expression: l.code)]))
          .get();

  /// Языки, на которых можно подсказывать: роль позволяет и статус запущен.
  Future<List<LanguageRow>> nativeLanguages() async {
    final rows = await allLanguages();
    return rows
        .where((l) => l.role != 'target' && l.status == 'launched')
        .toList();
  }

  /// Языки, которые можно учить.
  Future<List<LanguageRow>> targetLanguages() async {
    final rows = await allLanguages();
    return rows
        .where((l) => l.role != 'native' && l.status == 'launched')
        .toList();
  }
}
