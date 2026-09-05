// Проверки полноты и качества контента. Запускается в CI, падение блокирует
// мерж (docs/CONTENT_PIPELINE.md).
//
//   dart run tool/validate_content.dart --lang de

import 'dart:convert';
import 'dart:io';

import 'content_schema.dart';
import 'content_sources.dart';

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? targetLang;
  final root = Directory.current;

  final ContentSources sources;
  try {
    sources = ContentSources.load(Directory('${root.path}/content'));
  } on ContentSourceException catch (e) {
    stderr.writeln('✗ исходники: ${e.message}');
    exitCode = 1;
    return;
  }

  final report = _Report();

  _checkLexemeCoverage(sources, report);
  _checkOrphanLexemes(sources, report);
  _checkDistractors(sources, lang, report);
  _checkNearSoundalike(sources, lang, report);
  _checkConstellationSizes(sources, report);
  _checkDuplicateForms(sources, lang, report);
  _checkPhrases(sources, report);
  _checkCalibration(sources, lang, report);
  _checkAudio(sources, lang, root, report);

  report.print(lang);
  if (report.errors.isNotEmpty) exitCode = 1;
}

/// У каждого концепта есть лексема на каждом языке проекта.
void _checkLexemeCoverage(ContentSources sources, _Report report) {
  for (final lang in projectLangs) {
    final byConcept = sources.lexemes[lang];
    if (byConcept == null) {
      report.error('нет файла content/lang/$lang.yaml');
      continue;
    }
    final missing = sources.concepts.keys
        .where((id) => !byConcept.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      report.error(
        'язык $lang: нет лексем для ${missing.length} концептов '
        '(${_head(missing)})',
      );
    }
  }
}

/// Лексема без концепта — обычно опечатка в id после переименования.
void _checkOrphanLexemes(ContentSources sources, _Report report) {
  for (final entry in sources.lexemes.entries) {
    final orphans = entry.value.keys
        .where((id) => !sources.concepts.containsKey(id))
        .toList();
    if (orphans.isNotEmpty) {
      report.error(
        'язык ${entry.key}: лексемы без концепта — ${_head(orphans)}',
      );
    }
  }
}

/// У каждого концепта минимум 2 дистрактора `far` и 3 `near` на языке
/// изучения, и ни один не совпадает с ответом.
void _checkDistractors(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    if (lex.farDistractors.length < minFarDistractors) {
      report.error(
        '${lex.conceptId}: дистракторов far ${lex.farDistractors.length}, '
        'нужно $minFarDistractors',
      );
    }
    if (lex.nearDistractors.length < minNearDistractors) {
      report.error(
        '${lex.conceptId}: дистракторов near ${lex.nearDistractors.length}, '
        'нужно $minNearDistractors',
      );
    }

    final all = [...lex.farDistractors, ...lex.nearDistractors];
    final clash = all.where(
      (d) => d.toLowerCase() == lex.form.toLowerCase() ||
          (lex.plural != null && d.toLowerCase() == lex.plural!.toLowerCase()),
    );
    for (final d in clash) {
      report.error('${lex.conceptId}: дистрактор "$d" совпадает с ответом');
    }

    if (all.toSet().length != all.length) {
      report.error('${lex.conceptId}: дистракторы дублируются');
    }
  }
}

/// `near`-дистракторы обязаны быть созвучны. Эвристика грубая и смотрит на
/// три вещи: общее начало, общее окончание и расстояние Левенштейна.
///
/// Окончание здесь не менее важно, чем начало: в немецком созвучие часто идёт
/// по суффиксу (Medikament / Instrument, Apotheke / Bibliothek,
/// Krankenhaus / Kaufhaus), и проверка только по префиксу такие пары
/// отбрасывает зря. Всё сомнительное выводится списком на ручную проверку,
/// а не молча пропускается.
void _checkNearSoundalike(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    for (final d in lex.nearDistractors) {
      final a = lex.form.toLowerCase();
      final b = d.toLowerCase();
      final sharedPrefix = _commonPrefix(a, b);
      final sharedSuffix = _commonSuffix(a, b);
      final distance = _levenshtein(a, b);
      final looksClose = sharedPrefix >= 3 ||
          sharedSuffix >= 4 ||
          distance <= 2 ||
          distance <= (a.length / 3).ceil();
      if (!looksClose) {
        report.review(
          '${lex.conceptId}: "$d" не выглядит созвучным с "${lex.form}" '
          '(общее начало $sharedPrefix, окончание $sharedSuffix, '
          'расстояние $distance)',
        );
      }
    }
  }
}

/// Размеры созвездий соответствуют ярусам. Размер накопительный: на A2 в
/// созвездии 48 звёзд, включая 24 с A1.
void _checkConstellationSizes(ContentSources sources, _Report report) {
  for (final name in sources.constellations) {
    final byTier = <String, int>{};
    for (final c in sources.concepts.values) {
      if (c.constellation != name) continue;
      byTier[c.tier] = (byTier[c.tier] ?? 0) + 1;
    }
    if (byTier.isEmpty) {
      report.error('созвездие $name: ни одного концепта');
      continue;
    }

    var cumulative = 0;
    for (final tier in tiers) {
      final added = byTier[tier];
      if (added == null) {
        // Ярус ещё не написан — это нормально, пока язык не запущен.
        continue;
      }
      cumulative += added;
      final expected = starsPerTier[tier]!;
      if (cumulative != expected) {
        report.error(
          'созвездие $name, ярус $tier: $cumulative звёзд, ожидается $expected',
        );
      }
    }
  }
}

/// Нет дублей форм внутри одного созвездия и яруса — иначе в круге появятся
/// два одинаковых варианта.
void _checkDuplicateForms(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  final seen = <String, String>{};
  for (final concept in sources.concepts.values) {
    final lex = byConcept[concept.id];
    if (lex == null) continue;
    final key = '${concept.constellation}/${concept.tier}/'
        '${lex.form.toLowerCase()}';
    final previous = seen[key];
    if (previous != null) {
      report.error(
        'форма "${lex.form}" повторяется в ${concept.constellation}/'
        '${concept.tier}: $previous и ${concept.id}',
      );
    }
    seen[key] = concept.id;
  }
}

/// Фразы ссылаются на существующие концепты, и ответ действительно
/// подставляется в шаблон.
void _checkPhrases(ContentSources sources, _Report report) {
  final ids = <String>{};
  for (final p in sources.phrases) {
    if (!ids.add(p.id)) report.error('фраза ${p.id}: дублирующийся id');

    for (final conceptId in p.conceptIds) {
      if (!sources.concepts.containsKey(conceptId)) {
        report.error('фраза ${p.id}: нет концепта $conceptId');
      }
    }
    if (!p.template.contains('{')) {
      report.error('фраза ${p.id}: в шаблоне нет слота {…}');
    }
  }
}

/// Набор калибровки покрывает все пять ярусов минимум по 30 позиций.
void _checkCalibration(ContentSources sources, String lang, _Report report) {
  final items = sources.calibration[lang];
  if (items == null || items.isEmpty) {
    report.pending(
      'набор калибровки для $lang не написан — калибровка приходит на M3, '
      'контент к ней на M4',
    );
    return;
  }

  for (final tier in tiers) {
    final count = items.where((i) => i.tier == tier).length;
    if (count < 30) {
      report.error('калибровка $lang, ярус $tier: $count позиций из 30');
    }
  }
  for (final item in items) {
    if (item.conceptId != null &&
        !sources.concepts.containsKey(item.conceptId)) {
      report.error('калибровка ${item.id}: нет концепта ${item.conceptId}');
    }
  }
}

/// У каждой лексемы и фразы языка изучения есть файл озвучки: концепт без
/// аудио не проходит валидацию, потому что звук верного ответа — часть ядра
/// игры.
///
/// Пока каталога озвучки нет вообще (до M4), проверка честно объявляется
/// пропущенной — а не тихо проходит.
void _checkAudio(
  ContentSources sources,
  String lang,
  Directory root,
  _Report report,
) {
  final audioDir = Directory('${root.path}/assets/audio/$lang');
  final manifestFile = File('${audioDir.path}/manifest.json');
  if (!manifestFile.existsSync()) {
    report.pending(
      'нет assets/audio/$lang/manifest.json — запустите '
      'dart run tool/synthesize_audio.dart --lang $lang',
    );
    return;
  }

  final Map<String, Object?> files;
  try {
    final json = jsonDecode(manifestFile.readAsStringSync())
        as Map<String, Object?>;
    files = json['files'] as Map<String, Object?>? ?? const {};
  } catch (e) {
    report.error('манифест озвучки не читается: $e');
    return;
  }

  /// Файл должен быть и в манифесте, и на диске: манифест из чужой ветки
  /// без файлов — ровно та ситуация, которую эта проверка ловит.
  bool present(String audioId) {
    final entry = files[audioId] as Map<String, Object?>?;
    if (entry == null) return false;
    final name = entry['file'] as String?;
    return name != null && File('${audioDir.path}/$name').existsSync();
  }

  final missing = <String>[];
  for (final lex in sources.lexemes[lang]?.values ?? const <LexemeSource>[]) {
    if (!present(audioIdFor(lang, lex.form))) missing.add(lex.form);
  }
  for (final phrase in sources.phrases) {
    if (!present(audioIdForPhrase(lang, phrase.id))) missing.add(phrase.id);
  }

  if (missing.isNotEmpty) {
    // Концепт без озвучки не проходит валидацию: звук верного ответа — часть
    // ядра игры, а не украшение.
    report.error(
      'нет озвучки для ${missing.length} позиций (${_head(missing)})',
    );
  }
}

class _Report {
  final List<String> errors = [];

  /// Сомнительное, но не блокирующее — на ручную вычитку.
  final List<String> reviews = [];

  /// Осознанно не сделанное: приходит с будущей вехой.
  final List<String> pendings = [];

  void error(String message) => errors.add(message);
  void review(String message) => reviews.add(message);
  void pending(String message) => pendings.add(message);

  void print(String lang) {
    for (final p in pendings) {
      stdout.writeln('… $p');
    }
    for (final r in reviews) {
      stdout.writeln('? $r');
    }
    for (final e in errors) {
      stderr.writeln('✗ $e');
    }
    if (errors.isEmpty) {
      stdout.writeln(
        '✓ контент $lang валиден'
        '${reviews.isEmpty ? '' : ' (${reviews.length} на ручную проверку)'}',
      );
    } else {
      stderr.writeln('✗ ошибок: ${errors.length}');
    }
  }
}

int _commonPrefix(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  return i;
}

int _commonSuffix(String a, String b) {
  var i = 0;
  while (i < a.length &&
      i < b.length &&
      a[a.length - 1 - i] == b[b.length - 1 - i]) {
    i++;
  }
  return i;
}

int _levenshtein(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        current[j - 1] + 1,
        previous[j] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}

String _head(List<String> items, [int limit = 5]) {
  final shown = items.take(limit).join(', ');
  return items.length > limit ? '$shown, …' : shown;
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
