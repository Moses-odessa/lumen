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

/// Копирует ассет в support-директорию, если файла ещё нет или он отличается
/// по размеру от ассета — то есть контент обновился вместе с приложением.
///
/// Сравнение по размеру, а не по хешу: хешировать десятки мегабайт при каждом
/// старте дороже, чем пересобрать файл в редком случае совпадения размеров.
/// TODO(data): когда появится `package_info_plus`, сверять версию сборки из
/// таблицы `content_meta` — это надёжнее размера.
Future<File> ensureContentFile(String lang) async {
  final dir = await getApplicationSupportDirectory();
  final target = File('${dir.path}/content/$lang.db');

  final asset = await rootBundle.load(contentAssetPath(lang));
  final bytes = asset.buffer.asUint8List(
    asset.offsetInBytes,
    asset.lengthInBytes,
  );

  if (await target.exists() && await target.length() == bytes.length) {
    return target;
  }

  await target.parent.create(recursive: true);
  await target.writeAsBytes(bytes, flush: true);
  return target;
}
