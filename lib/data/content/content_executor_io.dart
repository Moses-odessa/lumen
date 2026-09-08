import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Путь к ассету с собранной контентной базой.
String contentAssetPath(String lang) => 'assets/content/$lang.db';

/// Открывает контентную базу языка [lang], скопировав её из ассетов в
/// support-директорию при первом запуске.
///
/// База открывается обычным [NativeDatabase] и на устройстве никогда не
/// мигрируется: read-only здесь — дисциплина, а не флаг файловой системы.
/// Пакет `sqlite3` в `lib/` не появляется намеренно (README: он только для
/// `tool/`), поэтому режим `OpenMode.readOnly` не используется — запись
/// невозможна просто потому, что в [ContentDatabase] нет ни одного метода
/// записи, а миграции падают.
QueryExecutor openContentExecutor(String lang) =>
    LazyDatabase(() async => NativeDatabase(await ensureContentFile(lang)));

/// Копирует ассет в support-директорию, если лежащая там копия отличается от
/// ассета — то есть контент обновился вместе с приложением.
///
/// Сравниваются длина **и первые сто байт**: это заголовок SQLite, в котором
/// лежат версия схемы (`user_version`, смещение 60), счётчик изменений и
/// cookie схемы. Читать сто байт бесплатно, а хешировать мегабайты при каждом
/// старте — нет.
///
/// Одной длины не хватало, и это была не теория. Контентная база на устройстве
/// не мигрируется: если Drift видит версию схемы не ту, которую ждёт
/// приложение, он падает намеренно. Сборка с новой схемой, случайно совпавшая
/// по размеру со старой копией, оставляла бы старый файл на месте — и первый
/// же запрос падал бы с «пересоберите контент» на устройстве, где пересобрать
/// нечего. Версия схемы лежит ровно в этих ста байтах, поэтому проверка стоит
/// столько же, сколько стоила прежняя.
Future<File> ensureContentFile(String lang) async {
  final dir = await getApplicationSupportDirectory();
  final target = File('${dir.path}/content/$lang.db');

  final asset = await rootBundle.load(contentAssetPath(lang));
  final bytes = asset.buffer.asUint8List(
    asset.offsetInBytes,
    asset.lengthInBytes,
  );

  if (await _matches(target, bytes)) return target;

  await target.parent.create(recursive: true);
  await target.writeAsBytes(bytes, flush: true);
  return target;
}

/// Совпадает ли копия с ассетом по длине и заголовку SQLite.
Future<bool> _matches(File target, Uint8List asset) async {
  if (!await target.exists()) return false;
  if (await target.length() != asset.length) return false;
  if (asset.length < _sqliteHeaderBytes) return true;

  final handle = await target.open();
  try {
    final head = await handle.read(_sqliteHeaderBytes);
    for (var i = 0; i < _sqliteHeaderBytes; i++) {
      if (head[i] != asset[i]) return false;
    }
    return true;
  } finally {
    await handle.close();
  }
}

/// Заголовок файла SQLite: сто байт, из которых нам важны версия схемы и
/// счётчики изменений.
const int _sqliteHeaderBytes = 100;
