import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/player_repository.dart';
import 'content_database.dart';

/// Контентная база открывается по языку изучения: смена языка — это смена
/// базы, а не запрос с другим `WHERE`.
final contentDatabaseProvider =
    Provider.family<ContentDatabase, String>((ref, lang) {
  final db = ContentDatabase.forLanguage(lang);
  ref.onDispose(db.close);
  return db;
});

/// База для текущего языка изучения игрока.
final currentContentDatabaseProvider = Provider<ContentDatabase>((ref) {
  final lang = ref.watch(playerControllerProvider)?.targetLang ??
      defaultTargetLang;
  return ref.watch(contentDatabaseProvider(lang));
});

/// Метаданные сборки контента — что за язык, когда собрано, чем.
final contentMetaProvider = FutureProvider<Map<String, String>>((ref) =>
    ref.watch(currentContentDatabaseProvider).loadMeta());
