// Сборка read-only контентной БД из YAML-исходников.
//
//   dart run tool/build_content.dart --lang de
//
// Правило пайплайна: сборка полностью воспроизводима из текстовых исходников
// в репозитории. Никаких «я поправил в базе руками» — база всегда пересоздаётся
// с нуля (docs/CONTENT_PIPELINE.md).
//
// ── Про пометку «черновое» ────────────────────────────────────────────────
//
// Раньше здесь стоял фильтр: концепт с `draft: true` в базу не попадал, и
// вместе с ним уезжала фраза, привязанная к такому концепту. Фильтр был
// нужен потому, что импорт словника кладёт тысячи невычитанных слов на
// ярусы, часть которых уже запущена, — а до M14 пометку уважал один
// валидатор, и сборка отгружала черновик наравне с вычитанным.
//
// У фразы такой пометки в исходниках нет ни одной: фразы пишутся руками, по
// одной, и их готовность объявляется ярусом в `content/launch.yaml`, а не
// полем у каждой строки. Поэтому фильтра здесь больше нет. Если пометка у
// фразы появится, уважать её обязана **сборка**, а не только валидатор:
// именно этой разницей проект однажды и заплатил.

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

  stdout.writeln(
    '  созвездий: ${sources.constellations.length}, '
    'фраз: ${sources.phrases.length}',
  );
  for (final l in sources.languages.values) {
    // Покрытие печатается всегда: язык, который покрывает половину, должен
    // быть виден при сборке, а не обнаружиться в игре фразами без перевода.
    stdout.writeln(
      '  ${l.code}: ${l.role}/${l.status}, '
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
    // это создание и удаление файла журнала рядом с базой. На Windows с
    // работающим антивирусом сборка из-за этого шла не секунды, а десятки
    // минут: проверялся каждый созданный файл. Режим журнала менять не стали
    // — он выбран ради того, чтобы рядом с воспроизводимым ассетом не
    // оставалось `-wal`.
    db.execute('BEGIN');
    _insertLanguages(db, sources);
    final shippedPhrases = _insertPhrases(db, sources, lang);
    _insertPhraseTranslations(db, sources, shippedPhrases);
    _insertCalibration(db, sources, lang, shippedPhrases);
    _insertMeta(db, sources, lang, sources.hash);
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

void _insertLanguages(Database db, ContentSources sources) {
  final stmt = db.prepare(
    'INSERT INTO languages (code, role, status, name, phrases) '
    'VALUES (?, ?, ?, ?, ?)',
  );
  try {
    for (final l in sources.languages.values) {
      stmt.execute([
        l.code,
        l.role,
        l.status,
        l.name,
        // Покрытие языка — это число переведённых фраз. Считается, а не
        // объявляется в файле: объявленное разошлось бы с содержимым при
        // первой же правке. У языка изучения переводов нет, и ноль здесь
        // правдив — переводить фразу на её же язык незачем.
        l.phraseTranslations.length,
      ]);
    }
  } finally {
    stmt.close();
  }
}

/// Возвращает идентификаторы отгруженных фраз: по этому списку сверяются
/// переводы и калибровка — ссылка на фразу, которой в базе нет, оставила бы
/// висячий вопрос без задания.
Set<String> _insertPhrases(
  Database db,
  ContentSources sources,
  String lang,
) {
  final shipped = <String>{};

  final stmt = db.prepare(
    'INSERT INTO phrases '
    '(id, lang, tier, constellation, idx, text, register) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
  );
  try {
    for (final p in sources.phrases) {
      shipped.add(p.id);
      stmt.execute([
        p.id,
        lang,
        p.tier,
        p.constellation,
        p.idx,
        p.text,
        p.register,
      ]);
    }
  } finally {
    stmt.close();
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

void _insertCalibration(
  Database db,
  ContentSources sources,
  String lang,
  Set<String> known,
) {
  final items = sources.calibration[lang];
  if (items == null) return;

  final stmt = db.prepare(
    'INSERT INTO calibration_items (id, tier, phrase_id, kind) '
    'VALUES (?, ?, ?, ?)',
  );
  try {
    for (final item in items) {
      // Позиция, ссылающаяся на фразу не из этой сборки, в базу не идёт:
      // `phrase_id` объявлен NOT NULL, а вопрос без текста не задать.
      // Расхождение при этом видно валидатору — он сверяет набор целиком.
      if (!known.contains(item.phraseId)) continue;
      stmt.execute([item.id, item.tier, item.phraseId, item.kind]);
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
) {
  // Метки времени в метаданных сознательно нет: она сделала бы каждую
  // пересборку новым файлом и сломала бы правило «сборка воспроизводима».
  // Когда собрано — знает git; из чего собрано — говорят хеш и ревизия.
  final meta = <String, String>{
    'lang': lang,
    'schema_version': '$contentSchemaVersion',
    'phrases': '${sources.phrases.length}',
    // Созвездия в порядке файлов. Раньше здесь отсеивались темы, у которых
    // все концепты черновые; теперь отсеивать нечего — список приходит из
    // файлов фраз, а тема без фраз в нём не появляется вовсе.
    'constellations': sources.constellations.join(','),
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
