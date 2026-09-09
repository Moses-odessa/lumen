// Сборка набора калибровки из написанного контента.
//
//   dart run tool/make_calibration.dart --lang de
//
// Калибровка спрашивает по 30 позиций на ярус (docs/CONCEPT.md «Онбординг»).
// Набирать их руками бессмысленно: правило отбора важнее конкретного списка,
// а руками оно каждый раз получается разным.
//
// Правило:
//
// 1. Спрашивают только фразы. Раньше двадцать шесть позиций из тридцати были
//    словами, и четыре — фразами, чтобы тест отличал «знаю слова» от «умею
//    собрать предложение». Отдельного слова в игре больше нет, значит и
//    мерить владение словом бессмысленно: игрок его никогда не увидит.
// 2. Внутри созвездия фразы берутся в авторском порядке — том же, в котором
//    они лежат в файле. Прежний отбор шёл по частотности слова, а у фразы
//    частотности нет; авторский порядок — это и есть заявленная
//    последовательность знакомства, то есть от обиходного к редкому.
// 3. Отбор идёт по кругу через созвездия. Иначе весь тест окажется про одну
//    тему, и человек, знающий медицину, но не кухню, получит завышенный ярус.
//
// Файл создаётся один раз и дальше правится руками: генератор нужен, чтобы
// начать с осмысленного набора, а не чтобы владеть им вечно.

import 'dart:io';

import 'content_schema.dart';
import 'content_sources.dart';

const _phrasesPerTier = 30;

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? defaultTargetLang;
  final root = Directory.current;

  final ContentSources sources;
  try {
    // Прежний набор не читается: генератор его перезаписывает, а набор,
    // собранный по устаревшим правилам, чтением отвергается — и починить его
    // можно только этим генератором.
    sources = ContentSources.load(
      Directory('${root.path}/content'),
      lang: lang,
      withCalibration: false,
    );
  } on ContentSourceException catch (e) {
    stderr.writeln('Ошибка в исходниках: ${e.message}');
    exitCode = 1;
    return;
  }

  final buffer = StringBuffer()
    ..writeln('# Набор калибровки — собран `tool/make_calibration.dart`.')
    ..writeln('#')
    ..writeln('# Отбор: по 30 фраз на ярус, по кругу через созвездия, внутри')
    ..writeln('# созвездия — в авторском порядке. Правило целиком описано')
    ..writeln('# в шапке генератора.')
    ..writeln('#')
    ..writeln('# Править руками можно и нужно: генератор даёт осмысленную')
    ..writeln('# отправную точку, а не окончательный список.')
    ..writeln('lang: $lang')
    ..writeln('items:');

  var total = 0;
  for (final tier in tiers) {
    final phrases = _pickPhrases(sources, tier);
    if (phrases.isEmpty) continue;

    buffer.writeln('  # ── ${tier.toUpperCase()} '
        '(${phrases.length} фраз) ──');
    for (final phrase in phrases) {
      buffer.writeln('  - { id: cal_${tier}_${phrase.id}, tier: $tier, '
          'phrase: ${phrase.id} }');
      total++;
    }
  }

  final dir = Directory('${root.path}/content/calibration');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$lang.yaml');
  await file.writeAsString(buffer.toString());

  stdout.writeln('Набор калибровки $lang: $total позиций → ${file.path}');
  for (final tier in tiers) {
    final count = _pickPhrases(sources, tier).length;
    final mark = count >= _phrasesPerTier ? '✓' : '…';
    stdout.writeln('  $mark $tier: $count фраз');
  }
}

/// Фразы яруса: по кругу через созвездия, внутри созвездия — по порядку в
/// файле. Иначе тридцать позиций окажутся из двух тем.
List<PhraseSource> _pickPhrases(ContentSources sources, String tier) {
  final byConstellation = <String, List<PhraseSource>>{};
  for (final phrase in sources.phrases) {
    if (phrase.tier != tier) continue;
    byConstellation.putIfAbsent(phrase.constellation, () => []).add(phrase);
  }
  for (final list in byConstellation.values) {
    list.sort((a, b) => a.idx.compareTo(b.idx));
  }

  return _roundRobin(byConstellation, _phrasesPerTier);
}

/// По одному из каждого созвездия, пока не наберётся [limit].
///
/// Созвездия обходятся в алфавитном порядке — иначе набор менялся бы от
/// порядка чтения файлов, и diff шумел бы на каждой пересборке.
List<T> _roundRobin<T>(Map<String, List<T>> byConstellation, int limit) {
  final names = byConstellation.keys.toList()..sort();
  final result = <T>[];
  var index = 0;
  while (result.length < limit) {
    var added = false;
    for (final name in names) {
      final list = byConstellation[name]!;
      if (index >= list.length) continue;
      result.add(list[index]);
      added = true;
      if (result.length == limit) break;
    }
    if (!added) break;
    index++;
  }
  return result;
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
