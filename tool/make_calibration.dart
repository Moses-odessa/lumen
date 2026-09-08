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
// 1. Внутри яруса концепты сортируются по частотности — калибровка должна
//    мерить владение обиходным словарём, а не знание редких слов.
// 2. Отбор идёт по кругу через созвездия. Иначе весь тест окажется про одну
//    тему, и человек, знающий медицину, но не кухню, получит завышенный ярус.
// 3. Четыре позиции из тридцати — фразы: тест обязан отличать «знаю слова» от
//    «умею собрать предложение», это отдельная фаза онбординга.
//
// Файл создаётся один раз и дальше правится руками: генератор нужен, чтобы
// начать с осмысленного набора, а не чтобы владеть им вечно.

import 'dart:io';

import 'content_schema.dart';
import 'content_sources.dart';

const _wordsPerTier = 26;
const _phrasesPerTier = 4;

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? defaultTargetLang;
  final root = Directory.current;

  final ContentSources sources;
  try {
    sources = ContentSources.load(Directory('${root.path}/content'), lang: lang);
  } on ContentSourceException catch (e) {
    stderr.writeln('Ошибка в исходниках: ${e.message}');
    exitCode = 1;
    return;
  }

  final buffer = StringBuffer()
    ..writeln('# Набор калибровки — собран `tool/make_calibration.dart`.')
    ..writeln('#')
    ..writeln('# Отбор: внутри яруса по частотности, по кругу через созвездия,')
    ..writeln('# четыре позиции из тридцати — фразы. Правило целиком описано')
    ..writeln('# в шапке генератора.')
    ..writeln('#')
    ..writeln('# Править руками можно и нужно: генератор даёт осмысленную')
    ..writeln('# отправную точку, а не окончательный список.')
    ..writeln('lang: $lang')
    ..writeln('items:');

  var total = 0;
  for (final tier in tiers) {
    final words = _pickWords(sources, tier);
    final phrases = _pickPhrases(sources, tier);
    if (words.isEmpty && phrases.isEmpty) continue;

    buffer.writeln('  # ── ${tier.toUpperCase()} '
        '(${words.length} слов, ${phrases.length} фраз) ──');
    for (final concept in words) {
      buffer.writeln('  - { id: cal_${tier}_${concept.id}, tier: $tier, '
          'concept: ${concept.id} }');
      total++;
    }
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
    final words = _pickWords(sources, tier).length;
    final phrases = _pickPhrases(sources, tier).length;
    final sum = words + phrases;
    final mark = sum >= 30 ? '✓' : '…';
    stdout.writeln('  $mark $tier: $sum (слов $words, фраз $phrases)');
  }
}

/// Слова яруса: по частотности, по кругу через созвездия.
List<ConceptSource> _pickWords(ContentSources sources, String tier) {
  final byConstellation = <String, List<ConceptSource>>{};
  for (final concept in sources.concepts.values) {
    if (concept.tier != tier) continue;
    byConstellation.putIfAbsent(concept.constellation, () => []).add(concept);
  }
  for (final list in byConstellation.values) {
    list.sort((a, b) => (a.freqRank ?? 1 << 30).compareTo(b.freqRank ?? 1 << 30));
  }

  return _roundRobin(byConstellation, _wordsPerTier);
}

/// Фразы яруса — так же по кругу, чтобы четыре фразы не оказались из одной темы.
List<PhraseSource> _pickPhrases(ContentSources sources, String tier) {
  final byConstellation = <String, List<PhraseSource>>{};
  for (final phrase in sources.phrases) {
    if (phrase.tier != tier) continue;
    byConstellation.putIfAbsent(phrase.constellation, () => []).add(phrase);
  }
  for (final list in byConstellation.values) {
    list.sort((a, b) => a.id.compareTo(b.id));
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
