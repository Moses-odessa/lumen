// Сборка read-only контентной БД из YAML-исходников.
//
//   dart run tool/build_content.dart --lang de
//
// Правило пайплайна: сборка полностью воспроизводима из текстовых исходников
// в репозитории. Никаких «я поправил в базе руками» — база всегда пересоздаётся
// с нуля (docs/CONTENT_PIPELINE.md).

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'content_schema.dart';
import 'content_sources.dart';

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? defaultTargetLang;
  final root = Directory.current;
  final outPath = '${root.path}/assets/content/$lang.db';

  stdout.writeln('Сборка content.db для языка $lang');

  final ContentSources sources;
  try {
    sources = ContentSources.load(
      Directory('${root.path}/content'),
      lang: lang,
    );
  } on ContentSourceException catch (e) {
    stderr.writeln('Ошибка в исходниках: ${e.message}');
    exitCode = 1;
    return;
  }

  // Черновые концепты в базу не попадают вовсе.
  //
  // Пометка `draft` обещает «в игру не идёт», и до сих пор это обещание
  // держал только валидатор: сборка отгружала черновик наравне с вычитанным.
  // Пока черновиков было ноль, разницы не было; импорт словника кладёт их
  // тысячами на ярусы, часть которых уже запущена, — и первый же прогон
  // отправил бы игроку невычитанные слова под видом вычитанных.
  final drafted = {
    for (final c in sources.concepts.values)
      if (c.draft) c.id,
  };
  final shipped = sources.concepts.values.where((c) => !drafted.contains(c.id));

  final shippedNames =
      shipped.map((c) => c.constellation).toSet();
  stdout.writeln(
    '  созвездий: ${shippedNames.length} из ${sources.constellations.length}, '
    'концептов: ${shipped.length}, '
    'фраз: ${sources.phrases.length}',
  );
  if (drafted.isNotEmpty) {
    stdout.writeln(
      '  черновых пропущено: ${drafted.length} концептов, '
      '${sources.constellations.length - shippedNames.length} созвездий '
      'целиком (написаны, но не вычитаны — в базу не идут)',
    );
  }
  for (final l in sources.languages.values) {
    // Покрытие печатается всегда: язык, который покрывает половину, должен
    // быть виден при сборке, а не обнаружиться в игре пропущенными словами.
    final covered =
        l.lexemes.keys.where((id) => !drafted.contains(id)).length;
    stdout.writeln(
      '  ${l.code}: ${l.role}/${l.status}, '
      'лексем $covered/${shipped.length}, '
      'переводов фраз ${l.phraseTranslations.length}/${sources.phrases.length}',
    );
  }

  await File(outPath).parent.create(recursive: true);
  // База пересоздаётся целиком: на устройстве она не мигрируется, а
  // заменяется вместе с обновлением приложения.
  final outFile = File(outPath);
  if (outFile.existsSync()) outFile.deleteSync();

  final db = sqlite3.open(outPath);
  try {
    db.execute('PRAGMA journal_mode = DELETE');
    for (final ddl in contentSchemaDdl) {
      db.execute(ddl);
    }

    // Все вставки одной транзакцией.
    //
    // Без неё каждая строка — своя транзакция, а при `journal_mode = DELETE`
    // это создание и удаление файла журнала рядом с базой. Строк около
    // двадцати двух тысяч, и на Windows с работающим антивирусом сборка из-за
    // этого шла не секунды, а десятки минут: проверялся каждый созданный
    // файл. Режим журнала менять не стали — он выбран ради того, чтобы рядом
    // с воспроизводимым ассетом не оставалось `-wal`.
    db.execute('BEGIN');
    _insertConcepts(db, sources, drafted);
    _insertLanguages(db, sources, drafted);
    _insertLexemes(db, sources, drafted);
    final shippedPhrases = _insertPhrases(db, sources, lang, drafted);
    _insertPhraseTranslations(db, sources, shippedPhrases);
    _insertDistractors(db, sources, lang, drafted);
    _insertCalibration(db, sources, lang, drafted);
    _insertMeta(db, sources, lang, sources.hash, drafted);
    db.execute('COMMIT');

    // Drift сверяет `user_version` со своим `schemaVersion`: без этого он
    // решит, что база пустая, и попытается прогнать миграцию по read-only
    // ассету.
    db.execute('PRAGMA user_version = $contentSchemaVersion');
    db.execute('VACUUM');
  } finally {
    db.close();
  }

  final sizeKb = (outFile.lengthSync() / 1024).toStringAsFixed(1);
  stdout.writeln('  → $outPath ($sizeKb КБ)');
}

void _insertConcepts(
  Database db,
  ContentSources sources,
  Set<String> drafted,
) {
  final stmt = db.prepare(
    'INSERT INTO concepts (id, tier, constellation, pos, freq_rank) '
    'VALUES (?, ?, ?, ?, ?)',
  );
  try {
    for (final c in sources.concepts.values) {
      if (drafted.contains(c.id)) continue;
      stmt.execute([c.id, c.tier, c.constellation, c.pos, c.freqRank]);
    }
  } finally {
    stmt.close();
  }
}

void _insertLexemes(
  Database db,
  ContentSources sources,
  Set<String> drafted,
) {
  final stmt = db.prepare(
    'INSERT INTO lexemes '
    '(concept_id, lang, form, article, gender, plural, note) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
  );
  try {
    for (final entry in sources.lexemes.entries) {
      final lexLang = entry.key;
      for (final lex in entry.value.values) {
        if (drafted.contains(lex.conceptId)) continue;
        stmt.execute([
          lex.conceptId,
          lexLang,
          lex.form,
          lex.article,
          lex.gender,
          lex.plural,
          lex.note,
        ]);
      }
    }
  } finally {
    stmt.close();
  }
}

void _insertLanguages(
  Database db,
  ContentSources sources,
  Set<String> drafted,
) {
  final stmt = db.prepare(
    'INSERT INTO languages (code, role, status, name, concepts, phrases) '
    'VALUES (?, ?, ?, ?, ?, ?)',
  );
  try {
    for (final l in sources.languages.values) {
      stmt.execute([
        l.code,
        l.role,
        l.status,
        l.name,
        // Считаются отгруженные, а не написанные: это число приложение
        // показывает как покрытие языка, и черновик в нём был бы обещанием
        // слов, которых в базе нет.
        l.lexemes.keys.where((id) => !drafted.contains(id)).length,
        l.phraseTranslations.length,
      ]);
    }
  } finally {
    stmt.close();
  }
}

/// Возвращает идентификаторы отгруженных фраз — переводам нужен именно этот
/// список, а не полный: перевод фразы, которой в базе нет, оставил бы висячую
/// ссылку.
Set<String> _insertPhrases(
  Database db,
  ContentSources sources,
  String lang,
  Set<String> drafted,
) {
  final shipped = <String>{};
  final phraseStmt = db.prepare(
    'INSERT INTO phrases '
    '(id, lang, tier, constellation, template, register) '
    'VALUES (?, ?, ?, ?, ?, ?)',
  );
  final slotStmt = db.prepare(
    'INSERT INTO phrase_slots (phrase_id, idx, answer) VALUES (?, ?, ?)',
  );
  final optionStmt = db.prepare(
    'INSERT OR IGNORE INTO phrase_options (phrase_id, idx, form) '
    'VALUES (?, ?, ?)',
  );
  final linkStmt = db.prepare(
    'INSERT INTO phrase_concepts (phrase_id, concept_id) VALUES (?, ?)',
  );
  try {
    for (final p in sources.phrases) {
      // Фраза с черновым словом уезжает целиком. Оставить её значило бы
      // показать невычитанное слово в пропуске — то есть ровно то, от чего
      // пометка защищает, только менее заметно.
      if (p.conceptIds.any(drafted.contains)) continue;
      shipped.add(p.id);
      phraseStmt.execute([
        p.id,
        lang,
        p.tier,
        p.constellation,
        p.template,
        p.register,
      ]);
      for (var i = 0; i < p.answers.length; i++) {
        slotStmt.execute([p.id, i, p.answers[i]]);
        for (final form in p.optionsFor(i)) {
          optionStmt.execute([p.id, i, form]);
        }
      }
      for (final conceptId in p.conceptIds) {
        linkStmt.execute([p.id, conceptId]);
      }
    }
  } finally {
    phraseStmt.close();
    slotStmt.close();
    optionStmt.close();
    linkStmt.close();
  }
  return shipped;
}

/// Переводы фраз: они приходят из языковых файлов, а не из файла фраз.
///
/// Фраза — предложение на языке изучения, её перевод — вклад родного языка.
/// Держать их вместе значило бы, что добавление родного языка правит файл
/// чужого.
void _insertPhraseTranslations(
  Database db,
  ContentSources sources,
  Set<String> known,
) {
  final stmt = db.prepare(
    'INSERT OR IGNORE INTO phrase_translations (phrase_id, lang, text) '
    'VALUES (?, ?, ?)',
  );
  try {
    for (final l in sources.languages.values) {
      for (final e in l.phraseTranslations.entries) {
        // Перевод фразы, которой нет в этой сборке, молча пропускаем: базы
        // собираются по одному языку изучения, и перевод немецкой фразы в
        // французской сборке — не ошибка, а просто не про неё.
        if (!known.contains(e.key)) continue;
        stmt.execute([e.key, l.code, e.value]);
      }
    }
  } finally {
    stmt.close();
  }
}

void _insertDistractors(
  Database db,
  ContentSources sources,
  String lang,
  Set<String> drafted,
) {
  final stmt = db.prepare(
    'INSERT OR IGNORE INTO distractors (concept_id, lang, kind, form) '
    'VALUES (?, ?, ?, ?)',
  );
  try {
    for (final entry in sources.lexemes.entries) {
      final lexLang = entry.key;
      for (final lex in entry.value.values) {
        if (drafted.contains(lex.conceptId)) continue;
        for (final form in lex.farDistractors) {
          stmt.execute([lex.conceptId, lexLang, 'far', form]);
        }
        for (final form in lex.nearDistractors) {
          stmt.execute([lex.conceptId, lexLang, 'near', form]);
        }
      }
    }
  } finally {
    stmt.close();
  }
}

void _insertCalibration(
  Database db,
  ContentSources sources,
  String lang,
  Set<String> drafted,
) {
  final items = sources.calibration[lang];
  if (items == null) return;

  final stmt = db.prepare(
    'INSERT INTO calibration_items (id, tier, concept_id, phrase_id, kind) '
    'VALUES (?, ?, ?, ?, ?)',
  );
  try {
    for (final item in items) {
      final conceptId = item.conceptId;
      if (conceptId != null && drafted.contains(conceptId)) continue;
      stmt.execute([
        item.id,
        item.tier,
        item.conceptId,
        item.phraseId,
        item.kind,
      ]);
    }
  } finally {
    stmt.close();
  }
}

void _insertMeta(
  Database db,
  ContentSources sources,
  String lang,
  String sourceHash,
  Set<String> drafted,
) {
  // Метки времени в метаданных сознательно нет: она сделала бы каждую
  // пересборку новым файлом и сломала бы правило «сборка воспроизводима».
  // Когда собрано — знает git; из чего собрано — говорят хеш и ревизия.
  final meta = <String, String>{
    'lang': lang,
    'schema_version': '$contentSchemaVersion',
    // Отгруженные, а не написанные: метаданные описывают эту базу, а не
    // каталог исходников. Сколько написано, знает валидатор.
    'concepts': '${sources.concepts.length - drafted.length}',
    'phrases': '${sources.phrases.where((p) => !p.conceptIds.any(drafted.contains)).length}',
    'drafted_concepts': '${drafted.length}',
    // Только созвездия, у которых в базе есть хоть одна звезда. Целиком
    // черновая тема в метаданных выглядела бы готовой, а приложение берёт
    // список созвездий из таблицы `concepts` и её не увидит.
    'constellations': sources.constellations
        .where((name) => sources.concepts.values
            .any((c) => c.constellation == name && !drafted.contains(c.id)))
        .join(','),
    // Языки перечислены и в таблице `languages`, но в метаданных они нужны
    // затем же, зачем `launched_tiers`: по собранному ассету должно быть
    // видно, что в нём лежит, без обхода таблиц.
    'languages': (sources.languages.keys.toList()..sort()).join(','),
    // Запущенные ярусы: приложение не предлагает подниматься выше того,
    // что вычитано.
    'launched_tiers': (sources.launch.launched.toList()..sort()).join(','),
    'source_hash': sourceHash,
    'source_revision': _gitRevision(),
  };

  final stmt =
      db.prepare('INSERT INTO content_meta (key, value) VALUES (?, ?)');
  try {
    for (final e in meta.entries) {
      stmt.execute([e.key, e.value]);
    }
  } finally {
    stmt.close();
  }
}

/// Ревизия исходников, чтобы по собранному ассету можно было понять, из чего
/// он собран. Без git — пустая строка, сборка от этого не падает.
String _gitRevision() {
  try {
    final r = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
    return r.exitCode == 0 ? (r.stdout as String).trim() : '';
  } catch (_) {
    return '';
  }
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  final prefixed = args.firstWhere(
    (a) => a.startsWith('$name='),
    orElse: () => '',
  );
  return prefixed.isEmpty ? null : prefixed.substring(name.length + 1);
}
