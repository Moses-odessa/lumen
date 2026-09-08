import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player.dart';
import '../../domain/entities/tier.dart';
import '../content/content_provider.dart';
import '../local/app_database.dart';
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

    await _sweepIfNeeded(container, db, player);
  } catch (_) {
    // БД недоступна — работаем без персистентности, игра важнее.
  }
}

/// Догоняет работу, которую попросила миграция v6: убрать память о словах,
/// которых в контенте больше нет.
///
/// Делается здесь, а не в `MigrationStrategy`, потому что там это невозможно:
/// `user.db` и `content.db` — отдельные базы, контентную открывают по языку
/// изучения и копируют из ассетов уже после старта. К моменту этого вызова
/// язык игрока известен, и обе базы доступны.
///
/// Ошибка чтения контента не приводит ни к чему: метка остаётся, чистка
/// случится в следующий раз. Хуже пустой очереди повторений только снесённый
/// прогресс.
Future<void> _sweepIfNeeded(
  ProviderContainer container,
  AppDatabase db,
  Player? player,
) async {
  if (!await db.needsItemSweep()) return;

  final lang = player?.targetLang ?? defaultTargetLang;
  final content = container.read(contentDatabaseProvider(lang));

  final known = <String>{
    for (final concept in await content.conceptsUpTo(Tier.b2)) concept.id,
    ...await content.allPhraseIds(),
  };
  final removed = await db.sweepUnknownItems(known);
  if (removed > 0) {
    debugPrint('user.db: убрано $removed единиц памяти без контента');
  }
}
