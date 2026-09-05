import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tier.dart';
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

/// Метаданные сборки контента — что за язык, из чего собрано.
final contentMetaProvider = FutureProvider<Map<String, String>>((ref) =>
    ref.watch(currentContentDatabaseProvider).loadMeta());

/// Ярусы, которые можно играть: вычитанные и запущенные.
///
/// Выше этого приложение не предлагает подниматься ни калибровкой, ни
/// ручной сменой яруса. Лучше играть меньше, чем играть по невычитанному.
final launchedTiersProvider = FutureProvider<Set<Tier>>((ref) =>
    ref.watch(currentContentDatabaseProvider).launchedTiers());

/// Самый высокий доступный ярус.
final maxTierProvider = Provider<Tier>((ref) {
  final tiers = switch (ref.watch(launchedTiersProvider)) {
    AsyncData(:final value) => value,
    // Пока метаданные не прочитаны, ничего не запрещаем: мигающий запрет
    // хуже, чем запрет, появившийся на полсекунды позже.
    _ => Tier.values.toSet(),
  };
  if (tiers.isEmpty) return Tier.b2;
  return tiers.reduce((a, b) => a.index >= b.index ? a : b);
});
