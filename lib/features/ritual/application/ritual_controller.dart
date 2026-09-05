import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/retention/sparks.dart';
import '../../../domain/scoring/balance.dart';
import '../../settings/application/reminder_scheduler.dart';
import '../../game/application/run_controller.dart';
import '../../game/application/session_loader.dart';

/// Фазы дневного ритуала.
///
/// Ритуал — это не «ещё один экран», а причина, по которой у сессии есть
/// начало и конец. Без него игра превращается в бесконечную ленту, из которой
/// невозможно выйти с чувством, что дело сделано (docs/CONCEPT.md).
enum RitualPhase {
  /// Ещё не начали.
  idle,

  /// Готовим материал.
  loading,

  /// Восход: две минуты только повторений, первыми самые тусклые.
  sunrise,

  /// Сколько люменов вернулось небу.
  sunriseResult,

  /// Новый уровень: шесть новых слов, забеги, босс-фраза.
  level,

  /// Итог уровня.
  levelResult,

  /// Ночной вызов — приходит на M5.
  challenge,

  /// Ритуал пройден целиком.
  done,
}

class RitualState {
  const RitualState({
    this.phase = RitualPhase.idle,
    this.lumensReturned = 0,
    this.score = 0,
    this.newWords = 0,
    this.reviewed = 0,
    this.error,
  });

  final RitualPhase phase;

  /// Люмены, вернувшиеся небу за Восход, — единственная цифра, которую
  /// показывает его итог. Не очки: Восход не про очки.
  final int lumensReturned;

  final int score;
  final int newWords;
  final int reviewed;

  final String? error;

  bool get isPlaying =>
      phase == RitualPhase.sunrise || phase == RitualPhase.level;

  RitualState copyWith({
    RitualPhase? phase,
    int? lumensReturned,
    int? score,
    int? newWords,
    int? reviewed,
    String? Function()? error,
  }) =>
      RitualState(
        phase: phase ?? this.phase,
        lumensReturned: lumensReturned ?? this.lumensReturned,
        score: score ?? this.score,
        newWords: newWords ?? this.newWords,
        reviewed: reviewed ?? this.reviewed,
        error: error == null ? this.error : error(),
      );
}

/// Ведёт игрока по ритуалу: Восход → уровень → ночной вызов.
class RitualController extends Notifier<RitualState> {
  @override
  RitualState build() => const RitualState();

  DateTime _startedAt = DateTime.now();

  /// Забеги уровня, которые ещё не сыграны. Уровень — это три забега и
  /// босс: комбо сбрасывается между ними, и темп задаётся именно так.
  final List<List<CircleQuestion>> _pendingRuns = [];

  /// Сколько забегов в уровне всего и какой идёт сейчас — для полосы
  /// прогресса уровня.
  int _totalRuns = 0;
  int get currentRun => _totalRuns - _pendingRuns.length;
  int get totalRuns => _totalRuns;

  /// Полный ритуал с начала.
  Future<void> startRitual() async {
    _startedAt = DateTime.now();
    ref.read(analyticsProvider).log(AnalyticsEvents.ritualStarted);
    await _startSunrise();
  }

  /// Только уровень — для тех, кто уже сделал Восход или хочет ещё.
  Future<void> startLevelOnly() async {
    _startedAt = DateTime.now();
    await _startLevel();
  }

  Future<void> _startSunrise() async {
    state = state.copyWith(phase: RitualPhase.loading, error: () => null);
    try {
      final session =
          await ref.read(sessionLoaderProvider).sunrise(DateTime.now());

      if (session.isEmpty) {
        // Повторять нечего — это не ошибка, а хорошая новость. Идём сразу
        // к новому материалу.
        await _startLevel();
        return;
      }

      ref.read(runControllerProvider.notifier).start(
            session.runs.first,
            maxDuration: SessionBalance.sunriseDuration,
          );
      state = state.copyWith(
        phase: RitualPhase.sunrise,
        reviewed: session.reviews,
      );
    } catch (e) {
      state = state.copyWith(
        phase: RitualPhase.idle,
        error: () => '$e',
      );
    }
  }

  Future<void> _startLevel() async {
    state = state.copyWith(phase: RitualPhase.loading, error: () => null);
    try {
      final session =
          await ref.read(sessionLoaderProvider).level(DateTime.now());

      if (session.isEmpty) {
        state = state.copyWith(phase: RitualPhase.done);
        return;
      }

      _pendingRuns
        ..clear()
        ..addAll(session.runs);
      _totalRuns = _pendingRuns.length;

      ref
          .read(runControllerProvider.notifier)
          .start(_pendingRuns.removeAt(0));
      state = state.copyWith(
        phase: RitualPhase.level,
        newWords: session.newWords,
      );
    } catch (e) {
      state = state.copyWith(phase: RitualPhase.idle, error: () => '$e');
    }
  }

  /// Забег закончился — двигаем ритуал дальше.
  Future<void> onRunFinished() async {
    final run = ref.read(runControllerProvider.notifier);
    final summary = ref.read(runControllerProvider).summary;

    switch (state.phase) {
      case RitualPhase.sunrise:
        ref.read(analyticsProvider).log(AnalyticsEvents.sunriseCompleted, {
          'lumens': run.lumensGained,
        });
        state = state.copyWith(
          phase: RitualPhase.sunriseResult,
          lumensReturned: run.lumensGained,
          score: state.score + (summary?.total ?? 0),
        );
      case RitualPhase.level:
        state = state.copyWith(
          score: state.score + (summary?.total ?? 0),
          lumensReturned: state.lumensReturned + run.lumensGained,
        );

        if (_pendingRuns.isNotEmpty) {
          // Следующий забег того же уровня: комбо начинается заново.
          run.start(_pendingRuns.removeAt(0));
          return;
        }

        ref.read(analyticsProvider).log(AnalyticsEvents.levelCompleted, {
          'score': state.score,
          'accuracy': summary?.accuracy ?? 0,
        });
        state = state.copyWith(phase: RitualPhase.levelResult);
        await _saveSession();
      case _:
        break;
    }
  }

  /// Переход к следующей фазе с экрана итога.
  Future<void> next() async {
    switch (state.phase) {
      case RitualPhase.sunriseResult:
        await _startLevel();
      case RitualPhase.levelResult:
        state = state.copyWith(phase: RitualPhase.challenge);
      case RitualPhase.challenge:
        state = state.copyWith(phase: RitualPhase.done);
      case _:
        break;
    }
  }

  void reset() {
    _pendingRuns.clear();
    _totalRuns = 0;
    state = const RitualState();
  }

  /// Журнал сессий: из него растут орбита, статистика и рейтинг лиг.
  Future<void> _saveSession() async {
    try {
      await ref.read(appDatabaseProvider).saveSession(
            SessionsCompanion.insert(
              startedAt: _startedAt,
              durationMs: DateTime.now().difference(_startedAt).inMilliseconds,
              // Прирост яркости, а не XP: перепроходить лёгкое бессмысленно,
              // у горящих слов прирост близок к нулю.
              lmGained: state.lumensReturned,
              score: state.score,
              newWords: state.newWords,
            ),
          );
      // Орбита и искры начисляются здесь и только здесь: сессия — это
      // единица, за которую игра платит.
      final player = ref.read(playerControllerProvider);
      if (player != null) {
        final now = DateTime.now();
        final orbit = Orbit.play(
          OrbitState(
            level: player.orbit,
            missedInRow: player.missedInRow,
            lastPlayedAt: player.lastPlayedAt,
            eclipseUntil: player.eclipseUntil,
          ),
          now,
        );
        final earned = Sparks.forLevel(
          lumensGained: state.lumensReturned,
          newWords: state.newWords,
        );

        ref.read(playerControllerProvider.notifier).replace(
              player.copyWith(
                orbit: orbit.level,
                missedInRow: orbit.missedInRow,
                lastPlayedAt: () => now,
                sparks: player.sparks + earned,
                // Час игры запоминается для напоминания: «удобно ему»,
                // а не «удобно нам».
                preferredHour: () => now.hour,
              ),
            );
      }

      // Небо изменилось — напоминание должно говорить о новом состоянии.
      unawaited(ref.read(reminderSchedulerProvider).reschedule());
    } catch (_) {
      // Журнал — не игра: его потеря не повод показывать ошибку.
    }
  }
}

final ritualControllerProvider =
    NotifierProvider<RitualController, RitualState>(RitualController.new);
