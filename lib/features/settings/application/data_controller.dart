import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';

/// Полное удаление данных и обслуживание журнала.
///
/// Удаление — не «фича приватности для галочки», а следствие обещания из
/// README: ни рекламы, ни трекеров, данные принадлежат игроку. Значит, он
/// должен уметь стереть их, не спрашивая разрешения.
///
/// Экспорта здесь нет намеренно. Переносимость данных имеет смысл вместе с
/// облаком: файл, который некуда загрузить, — это иллюзия сохранности, а не
/// сохранность. Появится облако — вернётся и экспорт, одним форматом.
class DataController {
  const DataController(this._ref);

  final Ref _ref;

  /// Полное удаление. Возврата нет — и это честно сказано в интерфейсе.
  Future<void> wipe() async {
    await _ref.read(appDatabaseProvider).wipe();
    _ref.read(playerControllerProvider.notifier).clear();
    _ref.read(analyticsProvider).log(AnalyticsEvents.dataDeleted);
  }

  /// Схлопывание журнала: он растёт неограниченно, и раз в месяц его надо
  /// подрезать (docs/DATA_MODEL.md).
  Future<int> pruneJournal() =>
      _ref.read(appDatabaseProvider).pruneReviews(DateTime.now());
}

final dataControllerProvider =
    Provider<DataController>(DataController.new);
