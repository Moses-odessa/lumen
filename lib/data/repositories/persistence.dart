import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_provider.dart';
import 'player_repository.dart';

/// Загружает сохранённое состояние в контроллеры до первого кадра и включает
/// write-through: изменения контроллеров пишутся в Drift сразу.
///
/// Загрузка именно до первого кадра — чтобы не мигал онбординг у игрока,
/// который уже прошёл калибровку (инвариант из README).
///
/// Best-effort: если БД недоступна, игра продолжает работать в памяти. На web
/// персистентности нет (нужны wasm-ассеты SQLite), поэтому там сразу выходим.
Future<void> bootstrapPersistence(ProviderContainer container) async {
  if (kIsWeb) return;
  try {
    final db = container.read(appDatabaseProvider);

    final player = await db.loadPlayer().timeout(const Duration(seconds: 5));
    if (player != null) {
      container.read(playerControllerProvider.notifier).replace(player);
    }

    container.listen(playerControllerProvider, (_, next) {
      if (next == null) return;
      db.savePlayer(next).catchError((_) {});
    });
  } catch (_) {
    // БД недоступна — работаем без персистентности, игра важнее.
  }
}
