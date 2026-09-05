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

  test('Drift читает базу, созданную DDL инструмента', () async {
    buildAndOpen(seed: [
      "INSERT INTO concepts (id, tier, constellation, pos, freq_rank) "
          "VALUES ('bill_restaurant', 'a1', 'restaurant', 'noun', 900)",
      "INSERT INTO lexemes "
          "(concept_id, lang, form, article, gender, audio_id) VALUES "
          "('bill_restaurant', 'de', 'Rechnung', 'die', 'f', 'de/rechnung')",
      "INSERT INTO distractors (concept_id, lang, kind, form) "
          "VALUES ('bill_restaurant', 'de', 'near', 'Richtung')",
      "INSERT INTO content_meta (key, value) VALUES ('lang', 'de')",
    ]);

    expect(await db.countConcepts(), 1);
    expect(await db.loadMeta(), {'lang': 'de'});

    final lexeme = await db.lexeme('bill_restaurant', 'de');
    expect(lexeme?.form, 'Rechnung');
    expect(lexeme?.article, 'die');
    expect(lexeme?.audioId, 'de/rechnung');

    final near = await db.distractorsFor('bill_restaurant', 'de', 'near');
    expect(near.map((d) => d.form), ['Richtung']);
  });

  test('выборка концептов включает нижние ярусы, а не только текущий',
      () async {
    buildAndOpen(seed: [
      "INSERT INTO concepts (id, tier, constellation, pos, freq_rank) VALUES "
          "('a', 'a0', 'doctor', 'noun', 1), "
          "('b', 'a1', 'doctor', 'noun', 2), "
          "('c', 'b2', 'doctor', 'noun', 3), "
          "('d', 'a0', 'rent', 'noun', 4)",
    ]);

    // Небо уплотняется, а не переписывается: на A1 звёзды A0 остаются
    // в ротации повторений.
    expect((await db.conceptsFor('doctor', Tier.a1)).map((c) => c.id),
        ['a', 'b']);
    expect((await db.conceptsFor('doctor', Tier.a0)).map((c) => c.id), ['a']);
    // Соседнее созвездие в выборку не попадает.
    expect((await db.conceptsFor('rent', Tier.b2)).map((c) => c.id), ['d']);
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
      () => db.countConcepts(),
      throwsA(isA<StateError>()),
    );
  });
}
