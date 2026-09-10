import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

// `tool/` — отдельная программа и не лежит в `lib/`, поэтому импорт по
// относительному пути. Именно этот шов и проверяется: DDL сборщика обязан
// совпадать с тем, что генерирует Drift.
import '../../tool/content_schema.dart';

/// Самое опасное место двух баз: `tool/build_content.dart` пишет `content.db`
/// голым SQL, а приложение читает её через Drift. Разъехались имена таблиц или
/// колонок — приложение откроет ассет и упадёт на первом запросе, причём уже
/// у игрока, а не в CI.
///
/// Тест воспроизводит продакшен-последовательность: база создаётся снаружи
/// Drift (как это делает сборщик, вместе с `PRAGMA user_version`), и только
/// потом открывается приложением.
///
/// Схема v5 — разговорник: пять таблиц вместо одиннадцати. Проверки, которые
/// сверяли `concepts`, `lexemes` и `distractors`, перенесены на `phrases` и
/// `phrase_translations`; проверки `phrase_slots` и `phrase_orders` удалены
/// вместе с механикой вставки слова в пропуск — у фразы больше нет ни
/// пропусков, ни списка верных сборок.
void main() {
  late raw.Database source;
  late ContentDatabase db;

  /// Собирает базу так же, как `tool/build_content.dart`, и открывает её
  /// приложением.
  void buildAndOpen({List<String> seed = const []}) {
    source = raw.sqlite3.openInMemory();
    for (final ddl in contentSchemaDdl) {
      source.execute(ddl);
    }
    for (final statement in seed) {
      source.execute(statement);
    }
    // Без этого Drift решит, что база пустая, и полезет в миграции.
    source.execute('PRAGMA user_version = $contentSchemaVersion');
    db = ContentDatabase(NativeDatabase.opened(source));
  }

  tearDown(() async => db.close());

  test('версия схемы инструмента совпадает с версией приложения', () {
    buildAndOpen();
    expect(contentSchemaVersion, db.schemaVersion);
  });

  test('Drift читает все пять таблиц, созданных DDL инструмента', () async {
    // Строки написаны так же, как их пишет сборщик: именами колонок SQL.
    // У фразы колонка называется `text`, а геттер Drift — `sentence`, потому
    // что `text()` в Drift это билдер колонки и `TextColumn get text =>
    // text()()` вернул бы сам себя. Такое переименование — ровно тот случай,
    // когда база и приложение расходятся молча, поэтому оба текста читаются
    // здесь через Drift-геттеры.
    //
    // `kind` (вид фразы, v7) назван в SQL и в Dart одинаково — билдера с таким
    // именем в Drift нет, — но читается всё равно через геттер, потому что
    // расходятся молча не только переименованные колонки. Значение в строке
    // указано явно: `DEFAULT` у колонки нет, умолчание живёт в чтении YAML
    // (`defaultPhraseKind`), а сборка пишет код у каждой фразы.
    buildAndOpen(seed: [
      "INSERT INTO languages (code, role, status, name, phrases) "
          "VALUES ('uk', 'native', 'launched', 'Українська', 1)",
      "INSERT INTO phrases "
          "(id, lang, tier, constellation, idx, text, register, kind)"
          " VALUES ('food_a1_bill', 'de', 'a1', 'food', 0, "
          "'Die Rechnung, bitte.', 'formal', 'phrase')",
      "INSERT INTO phrase_translations (phrase_id, lang, text) "
          "VALUES ('food_a1_bill', 'uk', 'Рахунок, будь ласка.')",
      "INSERT INTO calibration_items (id, tier, phrase_id, kind) "
          "VALUES ('cal_a1_1', 'a1', 'food_a1_bill', 'phrase')",
      "INSERT INTO content_meta (key, value) VALUES ('lang', 'de')",
    ]);

    expect(await db.countPhrases(), 1);
    expect(await db.loadMeta(), {'lang': 'de'});

    final phrase = await db.phrase('food_a1_bill');
    expect(phrase?.sentence, 'Die Rechnung, bitte.');
    expect(phrase?.register, 'formal');
    expect(phrase?.kind, 'phrase');

    expect(await db.translation('food_a1_bill', 'uk'), 'Рахунок, будь ласка.');
    expect((await db.calibrationFor(Tier.a1)).single.phraseId, 'food_a1_bill');
    expect((await db.allLanguages()).single.name, 'Українська');
  });

  test('выборка фраз включает нижние ярусы, а не только текущий', () async {
    buildAndOpen(seed: [
      "INSERT INTO phrases (id, lang, tier, constellation, idx, text, kind) "
          "VALUES "
          "('a', 'de', 'a0', 'health', 0, 'Ich bin krank.', 'phrase'), "
          "('b', 'de', 'a1', 'health', 0, 'Ich habe Fieber.', 'phrase'), "
          "('c', 'de', 'b2', 'health', 0, 'Die Diagnose steht fest.', "
          "'phrase'), "
          "('d', 'de', 'a0', 'home', 0, 'Ich wohne hier.', 'phrase')",
    ]);

    // Небо уплотняется, а не переписывается: на A1 фразы A0 остаются
    // в ротации повторений.
    expect((await db.phrasesFor('health', Tier.a1)).map((p) => p.id),
        ['a', 'b']);
    expect((await db.phrasesFor('health', Tier.a0)).map((p) => p.id), ['a']);
    // Соседнее созвездие в выборку не попадает.
    expect((await db.phrasesFor('home', Tier.b2)).map((p) => p.id), ['d']);
  });

  test('фразы яруса приходят в авторском порядке, а не в порядке вставки',
      () async {
    // Порядок знакомства задаёт автор — полем `idx`, то есть порядком строк
    // в файле. Прежнюю последовательность задавала частотность слова
    // (`concepts.freq_rank`), и у фразы её нет: «Zum Frühstück esse ich Brot»
    // не встречается в корпусе ни разу. Если запрос забудет `ORDER BY idx`,
    // знакомство пойдёт в порядке, которым никто не управляет.
    buildAndOpen(seed: [
      "INSERT INTO phrases (id, lang, tier, constellation, idx, text, kind) "
          "VALUES "
          "('third', 'de', 'a0', 'food', 2, 'Ich habe Hunger.', 'phrase'), "
          "('first', 'de', 'a0', 'food', 0, 'Ich esse Brot.', 'phrase'), "
          "('second', 'de', 'a0', 'food', 1, 'Ich trinke Wasser.', 'phrase')",
    ]);

    expect((await db.phrasesFor('food', Tier.a0)).map((p) => p.id),
        ['first', 'second', 'third']);
    expect((await db.phrasesOn(Tier.a0)).map((p) => p.id),
        ['first', 'second', 'third']);
  });

  test('каждая колонка, которую ждёт Drift, есть в DDL инструмента', () async {
    buildAndOpen();

    for (final table in db.allTables) {
      final columns = await db
          .customSelect("PRAGMA table_info('${table.actualTableName}')")
          .get();
      final actual = columns.map((r) => r.read<String>('name')).toSet();
      final expected = table.$columns.map((c) => c.name).toSet();

      expect(actual, isNotEmpty,
          reason: 'таблицы ${table.actualTableName} нет в DDL инструмента');
      expect(actual, containsAll(expected),
          reason: 'в ${table.actualTableName} не хватает колонок: '
              '${expected.difference(actual)}');
    }
  });

  test('миграция контентной базы падает, а не правит ассет', () async {
    // Ассет не той версии — ошибка сборки, а не ситуация для рантайма.
    source = raw.sqlite3.openInMemory();
    db = ContentDatabase(NativeDatabase.opened(source));

    expect(
      () => db.countPhrases(),
      throwsA(isA<StateError>()),
    );
  });
}
