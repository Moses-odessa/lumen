import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_provider.dart';
import '../../../domain/scoring/records.dart';

/// Стена рекордов игрока.
///
/// Считается из журнала сессий целиком, а не из последних записей: рекорд
/// месяца по девяноста строкам не посчитать. Читается на экране профиля, а
/// не в забеге, поэтому линейный проход по истории здесь уместен.
final recordWallProvider = FutureProvider<RecordWall>((ref) async {
  final levels = await ref.watch(appDatabaseProvider).loadScoredLevels();
  return RecordWall.from(levels, DateTime.now());
});
