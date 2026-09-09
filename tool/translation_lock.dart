/// Замок переводов: с какого немецкого текста снят каждый перевод фразы.
///
/// Зачем он нужен. Перевод фразы делается по конкретному предложению. Потом
/// предложение правят — и перевод молча начинает описывать не тот текст.
/// Отсутствующий перевод валидатор видит; устаревший — нет, потому что с
/// точки зрения данных он на месте.
///
/// Ошибка не гипотетическая: в этом проекте 432 украинских перевода были
/// сделаны, а через час двадцать семь немецких фраз изменились — в том числе
/// одна («Die Rechnungsadresse steht auf der Rechnung» → «… kann von der
/// Lieferadresse abweichen») сменила смысл целиком. Перевод остался прежним и
/// ни одна проверка на это не указала.
///
/// Это тот же приём, которым PLAN.md предлагает привязывать вычитку яруса к
/// содержимому: запись о проверке несёт хеш того, что проверяли. Здесь он
/// применён к отдельной фразе, и файл генерируется, а не пишется руками —
/// иначе он был бы 432 строками ручной работы, то есть ещё одним источником
/// расхождения.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'content_sources.dart';

/// Отпечаток фразы: её готовый текст.
///
/// Считается по **предложению**, а не по шаблону и ответам отдельно: перевод
/// делается с предложения, и правка, которая предложение не меняет (порядок
/// ключей в YAML, комментарий рядом), устаревания не значит.
///
/// Раньше подстановка делалась здесь же, потому что у фразы был шаблон с
/// пропуском. Теперь готовый текст собирает чтение исходников
/// (`phraseSpeech`), и здесь остаётся только хеш — от той же самой строки,
/// поэтому уже записанные замки остались в силе.
String phraseFingerprint(PhraseSource phrase) => sha256
    .convert(utf8.encode(phrase.text))
    .toString()
    .substring(0, 12);

/// Файл замка для языка: `content/lang/<код>.lock`.
File translationLockFile(String root, String lang) =>
    File('$root/lang/$lang.lock');

/// Читает замок: phrase_id → отпечаток немецкого текста на момент перевода.
Map<String, String> readTranslationLock(File file) {
  if (!file.existsSync()) return const {};
  final result = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final at = trimmed.indexOf(' ');
    if (at <= 0) continue;
    result[trimmed.substring(0, at)] = trimmed.substring(at + 1).trim();
  }
  return result;
}

/// Записывает замок. Порядок — по идентификатору, чтобы файл не шумел в diff.
void writeTranslationLock(
  File file,
  String lang,
  Map<String, String> fingerprints,
) {
  final ids = fingerprints.keys.toList()..sort();
  final out = StringBuffer()
    ..writeln('# Отпечатки немецких фраз на момент перевода на $lang.')
    ..writeln('#')
    ..writeln('# Генерируется: dart run tool/lock_translations.dart --lang $lang')
    ..writeln('# Руками не правится. Строка «id отпечаток»; отпечаток берётся')
    ..writeln('# от собранного предложения, а не от шаблона с ответами')
    ..writeln('# по отдельности.')
    ..writeln('#')
    ..writeln('# Расхождение означает, что немецкую фразу изменили после')
    ..writeln('# перевода: перевод на месте, но описывает не тот текст.')
    ..writeln('# Валидатор выносит такие фразы на перевод заново.');
  for (final id in ids) {
    out.writeln('$id ${fingerprints[id]}');
  }
  file.writeAsStringSync(out.toString());
}
