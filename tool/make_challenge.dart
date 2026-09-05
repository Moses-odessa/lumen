// Генерация ночных вызовов — по одному статическому JSON на день и язык.
//
//   dart run tool/make_challenge.dart --lang de --days 30
//
// Почему статические файлы, а не сервер: ночной вызов — единственное сетевое
// место в игре, и оно обязано стоить около нуля. Файл на CDN раздаётся
// бесплатно и одинаково для всех, а «один и тот же набор для всех игроков
// этого языка в этот день» — это ровно то, что задумано в CONCEPT.md.
//
// Набор детерминирован: сид считается из даты и языка. Пересборка даёт те же
// файлы, а игроки в разных часовых поясах видят один и тот же вызов.

import 'dart:convert';
import 'dart:io';

import 'content_schema.dart';
import 'content_sources.dart';

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? targetLang;
  final days = int.tryParse(_argValue(args, '--days') ?? '') ?? 30;
  final from = _argValue(args, '--from');
  final root = Directory.current;

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

  // Вызов собирается только из запущенных ярусов: он общий для всех, и
  // показывать в нём невычитанное нельзя тем более.
  final pool = sources.concepts.values
      .where((c) => sources.launch.isLaunched(c.tier))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  if (pool.length < challengePairs) {
    stderr.writeln(
      'Мало материала: ${pool.length} концептов на запущенных ярусах, '
      'нужно $challengePairs. Запустите ещё ярус или созвездие.',
    );
    exitCode = 1;
    return;
  }

  final outDir = Directory('${root.path}/build/challenges/$lang');
  await outDir.create(recursive: true);

  final start = from == null ? _today() : DateTime.parse(from);
  for (var i = 0; i < days; i++) {
    final day = start.add(Duration(days: i));
    final file = File('${outDir.path}/${_dayKey(day)}.json');
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(_build(
        pool: pool,
        sources: sources,
        lang: lang,
        day: day,
      ))}\n',
    );
  }

  stdout.writeln('Готово: $days файлов в ${outDir.path}');
  stdout.writeln(
    'Выложите каталог на CDN как <base>/$lang/<YYYY-MM-DD>.json',
  );
}

/// Сколько пар в вызове (docs/CONCEPT.md).
const int challengePairs = 20;

Map<String, Object?> _build({
  required List<ConceptSource> pool,
  required ContentSources sources,
  required String lang,
  required DateTime day,
}) {
  final key = _dayKey(day);
  // Детерминированный сид: один и тот же вызов у всех игроков языка.
  var seed = _hash('$lang/$key');
  int next(int bound) {
    // Линейный конгруэнтный генератор: своя реализация нужна затем, чтобы
    // последовательность не зависела от версии Dart.
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % bound;
  }

  final chosen = <ConceptSource>[];
  final taken = <int>{};
  while (chosen.length < challengePairs && taken.length < pool.length) {
    final index = next(pool.length);
    if (!taken.add(index)) continue;
    chosen.add(pool[index]);
  }

  final target = sources.lexemes[lang] ?? const {};

  return {
    'version': 1,
    'lang': lang,
    'day': key,
    'seconds': 60,
    'pairs': [
      for (final concept in chosen)
        if (target[concept.id] != null)
          {
            'concept': concept.id,
            'target': target[concept.id]!.form,
            'article': target[concept.id]!.article,
            'audio': audioIdFor(lang, target[concept.id]!.form),
            'tier': concept.tier,
          },
    ],
  };
}

DateTime _today() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day);
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

int _hash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}
