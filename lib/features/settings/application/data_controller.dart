import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';

/// Экспорт и полное удаление данных.
///
/// Не «фича приватности для галочки», а следствие обещания из README: ни
/// рекламы, ни трекеров, данные принадлежат игроку. Значит, он должен уметь
/// их забрать и стереть, не спрашивая разрешения.
class DataController {
  const DataController(this._ref);

  final Ref _ref;

  /// Весь прогресс одним JSON.
  ///
  /// Формат совпадает с облачным снимком из docs/DATA_MODEL.md — тем самым,
  /// который появится на M6. Это не совпадение: экспорт и синхронизация
  /// должны говорить об одних и тех же данных, иначе одно из двух сломается
  /// незаметно.
  Future<String> export() async {
    final db = _ref.read(appDatabaseProvider);
    final player = _ref.read(playerControllerProvider);

    final snapshot = <String, Object?>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'player': player == null
          ? null
          : {
              'targetLang': player.targetLang,
              'nativeLang': player.nativeLang,
              'uiLang': player.uiLang,
              'tier': player.tier.code,
              'calibrated': player.calibrated,
              'orbit': player.orbit,
              'sparks': player.sparks,
              'lastPlayedAt': player.lastPlayedAt?.toIso8601String(),
              'missedInRow': player.missedInRow,
              'freePace': player.freePace,
              'soundEnabled': player.soundEnabled,
            },
      'wordStates': [
        for (final row in await db.loadWordStates())
          {
            'conceptId': row.conceptId,
            'tier': row.tier,
            'difficulty': row.difficulty,
            'stability': row.stability,
            'lastReview': row.lastReview?.toIso8601String(),
            'due': row.due?.toIso8601String(),
            'reps': row.reps,
            'lapses': row.lapses,
            'burning': row.burning,
          },
      ],
      'sessions': [
        for (final row in await db.loadSessions(limit: 1000))
          {
            'startedAt': row.startedAt.toIso8601String(),
            'durationMs': row.durationMs,
            'lmGained': row.lmGained,
            'score': row.score,
            'newWords': row.newWords,
          },
      ],
      'challenges': [
        for (final row in await db.loadChallengeHistory(limit: 365))
          {
            'day': row.day,
            'correct': row.correct,
            'total': row.total,
            'timeMs': row.timeMs,
          },
      ],
      'customConcepts': [
        for (final row in await db.loadCustomConcepts())
          {
            'id': row.id,
            'target': row.target,
            'native': row.native,
            'deck': row.deck,
          },
      ],
      // Журнал ответов не выгружается: он большой, нужен только локально
      // для дообучения FSRS и ничего не говорит игроку о его прогрессе.
    };

    _ref.read(analyticsProvider).log(AnalyticsEvents.dataExported);
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

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
