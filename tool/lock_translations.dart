// Записывает замок переводов: с какого немецкого текста снят каждый перевод.
//
//   dart run tool/lock_translations.dart --lang uk
//   dart run tool/lock_translations.dart --lang uk --check
//
// Запускается после того, как переводы сделаны или обновлены. Без `--check`
// перезаписывает замок целиком: это заявление «всё, что переведено, переведено
// с текущего текста». С `--check` только сообщает о расхождениях и ничего не
// пишет — тот же ответ, что даёт валидатор, но без остальных проверок.
//
// Правило простое и важное: замок обновляется **вместе с переводом**, а не
// вместо него. Обновить замок, не тронув перевод, значит заявить неправду.

import 'dart:io';

import 'content_schema.dart';
import 'content_sources.dart';
import 'translation_lock.dart';

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang');
  if (lang == null) {
    stderr.writeln('нужен --lang <код родного языка>');
    exitCode = 64;
    return;
  }
  final check = args.contains('--check');
  final root = '${Directory.current.path}/content';

  final ContentSources sources;
  try {
    sources = ContentSources.load(
      Directory(root),
      lang: _argValue(args, '--target') ?? defaultTargetLang,
    );
  } on ContentSourceException catch (e) {
    stderr.writeln('✗ исходники: ${e.message}');
    exitCode = 1;
    return;
  }

  final language = sources.languages[lang];
  if (language == null) {
    stderr.writeln('✗ нет языка $lang в content/lang/');
    exitCode = 1;
    return;
  }

  final byId = {for (final p in sources.phrases) p.id: p};
  final file = translationLockFile(root, lang);
  final existing = readTranslationLock(file);

  final current = <String, String>{};
  final stale = <String>[];
  final fresh = <String>[];

  for (final id in language.phraseTranslations.keys) {
    final phrase = byId[id];
    if (phrase == null) continue;
    final fingerprint = phraseFingerprint(phrase);
    current[id] = fingerprint;

    final locked = existing[id];
    if (locked == null) {
      fresh.add(id);
    } else if (locked != fingerprint) {
      stale.add(id);
    }
  }

  stdout.writeln('переводов на $lang: ${current.length}');
  if (fresh.isNotEmpty) {
    stdout.writeln('  без записи в замке: ${fresh.length}');
  }
  if (stale.isNotEmpty) {
    stdout.writeln('  немецкий текст изменился после перевода: '
        '${stale.length}');
    for (final id in stale..sort()) {
      stdout.writeln('    $id');
    }
  }

  if (check) {
    if (stale.isNotEmpty) exitCode = 1;
    return;
  }

  writeTranslationLock(file, lang, current);
  stdout.writeln('→ ${file.path}');
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
