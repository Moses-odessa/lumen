// Сборка аудио-паков для докачки.
//
//   dart run tool/pack_audio.dart --lang de
//   dart run tool/pack_audio.dart --lang de --bundled a0
//
// Появился ровно на M8 и ровно по своему триггеру: второй язык изучения.
// Один язык целиком помещается в ассеты (~25 МБ в Opus), два — уже под
// сотню мегабайт, и дальше линейно хуже.
//
// Что делает: делит озвучку языка на «ту, что едет в приложении» и «ту, что
// докачивается», и собирает вторую в архивы по ярусам. Манифест содержит
// размер и SHA-256 каждого пака — без хеша докачка не может отличить
// обрыв связи от испорченного файла.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'content_schema.dart';
import 'content_sources.dart';
import 'tts/audio_manifest.dart';

/// Ярусы, которые едут в самом приложении.
///
/// A0 остаётся в ассетах всегда: свежая установка обязана быть играбельной
/// сразу, без сети и без ожидания (критерий приёмки M8).
const List<String> defaultBundledTiers = ['a0'];

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? targetLang;
  final bundled = (_argValue(args, '--bundled') ?? defaultBundledTiers.join(','))
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

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

  final audioDir = Directory('${root.path}/assets/audio/$lang');
  final manifest = await AudioManifest.load(audioDir);
  if (manifest == null) {
    stderr.writeln(
      'Нет манифеста озвучки для $lang — сначала '
      'dart run tool/synthesize_audio.dart --lang $lang',
    );
    exitCode = 1;
    return;
  }

  // Ярус каждой позиции: у слова — ярус его концепта, у фразы — её
  // собственный.
  final tierByAudioId = <String, String>{};
  for (final lexeme in sources.lexemes[lang]?.values ?? const <LexemeSource>[]) {
    final tier = sources.concepts[lexeme.conceptId]?.tier;
    if (tier != null) tierByAudioId[audioIdFor(lang, lexeme.form)] = tier;
  }
  for (final phrase in sources.phrases) {
    tierByAudioId[audioIdForPhrase(lang, phrase.id)] = phrase.tier;
  }

  final byTier = <String, List<MapEntry<String, AudioEntry>>>{};
  var bundledCount = 0;

  for (final entry in manifest.entries.entries) {
    final tier = tierByAudioId[entry.key];
    if (tier == null) continue;
    if (bundled.contains(tier)) {
      bundledCount++;
      continue;
    }
    byTier.putIfAbsent(tier, () => []).add(entry);
  }

  stdout.writeln('Паки $lang: в приложении остаётся $bundledCount позиций '
      '(${bundled.join(', ')})');

  if (byTier.isEmpty) {
    stdout.writeln(
      '  Паковать нечего: вся озвучка запущенных ярусов едет в ассетах.\n'
      '  Паки появятся, как только будет запущен ярус выше '
      '${bundled.join(', ')}.',
    );
    // Пустой манифест всё равно пишем: приложение должно уметь прочитать его
    // и честно сказать «докачивать нечего», а не спотыкаться об отсутствие.
  }

  final outDir = Directory('${root.path}/build/packs/$lang');
  await outDir.create(recursive: true);

  final packs = <Map<String, Object?>>[];
  for (final tier in tiers) {
    final items = byTier[tier];
    if (items == null || items.isEmpty) continue;

    final archive = Archive();
    // Манифест внутри пака: после распаковки приложение должно знать, какой
    // файл какому audioId соответствует, не пересобирая это заново.
    final inner = <String, Object?>{};

    for (final item in items) {
      final file = File('${audioDir.path}/${item.value.file}');
      if (!file.existsSync()) {
        stderr.writeln('  ✗ нет файла ${item.value.file}');
        exitCode = 1;
        continue;
      }
      final bytes = file.readAsBytesSync();
      archive.addFile(
        ArchiveFile(item.value.file, bytes.length, bytes),
      );
      inner[item.key] = {
        'file': item.value.file,
        'bytes': item.value.bytes,
        'signature': item.value.signature,
      };
    }

    archive.addFile(
      _jsonFile(AudioManifest.fileName, {'version': 1, 'files': inner}),
    );

    final encoded = ZipEncoder().encode(archive);
    final packFile = File('${outDir.path}/$tier.zip');
    await packFile.writeAsBytes(encoded);

    final digest = sha256.convert(encoded).toString();
    packs.add({
      'tier': tier,
      'file': '$tier.zip',
      'bytes': encoded.length,
      'sha256': digest,
      'items': items.length,
    });

    stdout.writeln(
      '  → $tier.zip: ${items.length} позиций, '
      '${(encoded.length / 1024 / 1024).toStringAsFixed(2)} МБ',
    );
  }

  final index = File('${outDir.path}/packs.json');
  await index.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'lang': lang,
          'bundled': bundled.toList()..sort(),
          'packs': packs,
        })}\n',
  );

  stdout.writeln('  → ${index.path}');
  stdout.writeln(
    'Выложите каталог как <base>/$lang/packs.json и <base>/$lang/<ярус>.zip',
  );
}

ArchiveFile _jsonFile(String name, Map<String, Object?> json) {
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
  return ArchiveFile(name, bytes.length, bytes);
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}
