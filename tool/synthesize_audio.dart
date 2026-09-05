// Синтез озвучки языка изучения.
//
//   dart run tool/synthesize_audio.dart --lang de
//   dart run tool/synthesize_audio.dart --lang de --force   # игнорировать кеш
//
// Кеш по хешу «текст + голос»: пересинтезировать неизменившееся слово дорого
// и бессмысленно. Результат — файлы в assets/audio/<lang>/ и манифест с
// размерами (docs/CONTENT_PIPELINE.md).
//
// Провайдеры TTS подключаются через [TtsProvider]. Сейчас реализован один —
// системный синтезатор Windows (SAPI): он бесплатный, работает офлайн и на
// этой машине умеет немецкий. Этого достаточно, чтобы игра звучала уже
// сейчас; замена на записи носителей — отдельный триггер M8.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'content_schema.dart';
import 'content_sources.dart';
import 'tts/audio_manifest.dart';
import 'tts/sapi_provider.dart';
import 'tts/tts_provider.dart';

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? targetLang;
  final force = args.contains('--force');
  final root = Directory.current;

  final ContentSources sources;
  try {
    sources = ContentSources.load(Directory('${root.path}/content'));
  } on ContentSourceException catch (e) {
    stderr.writeln('Ошибка в исходниках: ${e.message}');
    exitCode = 1;
    return;
  }

  final provider = await resolveProvider(lang);
  if (provider == null) {
    stderr.writeln(
      'Нет доступного TTS для языка $lang.\n'
      'На Windows нужен установленный голос $lang в «Параметры → Время и '
      'язык → Речь». Для других платформ провайдер пока не написан.',
    );
    exitCode = 1;
    return;
  }

  final items = _collectItems(sources, lang);
  stdout.writeln('Синтез $lang: ${items.length} позиций, голос '
      '${provider.voiceName}');

  final outDir = Directory('${root.path}/assets/audio/$lang');
  await outDir.create(recursive: true);

  final encoder = await OpusEncoder.detect();
  if (!encoder.available) {
    stdout.writeln(
      '  ! ffmpeg не найден — файлы останутся в WAV.\n'
      '    На объёме одного языка (~5 000 слов) это примерно вчетверо больше\n'
      '    бюджета из README. Поставьте ffmpeg и перезапустите с --force.',
    );
  }

  final manifest = await AudioManifest.load(outDir) ?? AudioManifest.empty();
  final next = AudioManifest.empty();

  var synthesized = 0;
  var cached = 0;

  for (final item in items) {
    final signature = _signature(item.text, provider.voiceName);
    final existing = manifest.entries[item.audioId];

    if (!force &&
        existing != null &&
        existing.signature == signature &&
        File('${outDir.path}/${existing.file}').existsSync()) {
      next.entries[item.audioId] = existing;
      cached++;
      continue;
    }

    final entry = await _synthesizeOne(
      item: item,
      provider: provider,
      encoder: encoder,
      outDir: outDir,
      signature: signature,
    );
    if (entry == null) {
      stderr.writeln('  ✗ не удалось озвучить ${item.audioId}');
      exitCode = 1;
      continue;
    }
    next.entries[item.audioId] = entry;
    synthesized++;
    if (synthesized % 25 == 0) {
      stdout.writeln('  … $synthesized синтезировано');
    }
  }

  await next.save(outDir);
  _removeOrphans(outDir, next);

  final totalBytes =
      next.entries.values.fold<int>(0, (sum, e) => sum + e.bytes);
  stdout.writeln(
    '  → ${next.entries.length} файлов, '
    '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} МБ '
    '(новых $synthesized, из кеша $cached)',
  );
}

/// Что нужно озвучить: лексемы языка изучения и фразы целиком.
///
/// Подсказки на родном языке не озвучиваются — игрок и так их читает, а
/// вес и время синтеза растут вдвое.
List<SpeechItem> _collectItems(ContentSources sources, String lang) {
  final items = <SpeechItem>[];

  final lexemes = sources.lexemes[lang]?.values ?? const <LexemeSource>[];
  for (final lexeme in lexemes) {
    items.add(SpeechItem(
      audioId: audioIdFor(lang, lexeme.form),
      // Артикль произносится вместе со словом: в немецком род — часть слова,
      // а не пометка в словаре.
      text: lexeme.article == null
          ? lexeme.form
          : '${lexeme.article} ${lexeme.form}',
    ));
  }

  for (final phrase in sources.phrases) {
    items.add(SpeechItem(
      audioId: audioIdForPhrase(lang, phrase.id),
      text: phraseSpeech(phrase.template, phrase.answer),
    ));
  }

  // Дубли возможны: два концепта могут дать одну форму.
  final seen = <String>{};
  return [for (final i in items) if (seen.add(i.audioId)) i];
}

Future<AudioEntry?> _synthesizeOne({
  required SpeechItem item,
  required TtsProvider provider,
  required OpusEncoder encoder,
  required Directory outDir,
  required String signature,
}) async {
  final name = item.audioId.split('/').last;
  final wav = File('${outDir.path}/$name.wav');

  if (!await provider.speakToFile(item.text, wav)) return null;

  if (encoder.available) {
    final opus = File('${outDir.path}/$name.opus');
    if (await encoder.encode(wav, opus)) {
      await wav.delete();
      return AudioEntry(
        file: '$name.opus',
        bytes: opus.lengthSync(),
        signature: signature,
      );
    }
  }

  return AudioEntry(
    file: '$name.wav',
    bytes: wav.lengthSync(),
    signature: signature,
  );
}

/// Удаляет файлы, на которые больше никто не ссылается: иначе переименование
/// слова навсегда оставляет мусор в ассетах и в APK.
void _removeOrphans(Directory outDir, AudioManifest manifest) {
  final keep = {
    ...manifest.entries.values.map((e) => e.file),
    AudioManifest.fileName,
  };
  for (final file in outDir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!keep.contains(name)) file.deleteSync();
  }
}

String _signature(String text, String voice) =>
    sha256.convert(utf8.encode('$voice|$text')).toString().substring(0, 16);

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}
