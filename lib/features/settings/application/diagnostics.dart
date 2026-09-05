import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/content/content_provider.dart';
import '../../../data/local/database_provider.dart';

/// Что удалось узнать про обе базы. Критерий приёмки M0 — «обе базы
/// открываются», и это должно быть видно из приложения, а не только из логов.
class DatabasesDiagnostics {
  const DatabasesDiagnostics({
    required this.userSchemaVersion,
    required this.userTablesOpened,
    required this.contentLang,
    required this.contentConcepts,
    required this.contentMeta,
    this.contentError,
  });

  final int userSchemaVersion;
  final bool userTablesOpened;

  final String contentLang;
  final int contentConcepts;
  final Map<String, String> contentMeta;

  /// Текст ошибки, если контентная база не открылась: на web это ожидаемо,
  /// на устройстве — значит ассет не собран.
  final String? contentError;

  bool get contentOpened => contentError == null;
}

final databasesDiagnosticsProvider =
    FutureProvider<DatabasesDiagnostics>((ref) async {
  final userDb = ref.watch(appDatabaseProvider);

  // Дешёвый способ убедиться, что схема применилась: запрос по таблице.
  var userTablesOpened = false;
  if (!kIsWeb) {
    try {
      await userDb.loadPlayer();
      userTablesOpened = true;
    } catch (_) {
      userTablesOpened = false;
    }
  }

  final contentDb = ref.watch(currentContentDatabaseProvider);
  try {
    final meta = await contentDb.loadMeta();
    return DatabasesDiagnostics(
      userSchemaVersion: userDb.schemaVersion,
      userTablesOpened: userTablesOpened,
      contentLang: meta['lang'] ?? '—',
      contentConcepts: await contentDb.countConcepts(),
      contentMeta: meta,
    );
  } catch (e) {
    return DatabasesDiagnostics(
      userSchemaVersion: userDb.schemaVersion,
      userTablesOpened: userTablesOpened,
      contentLang: '—',
      contentConcepts: 0,
      contentMeta: const {},
      contentError: e.toString(),
    );
  }
});
