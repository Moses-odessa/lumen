import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/retention/sparks.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/scoring/climb.dart';
import '../../../domain/scheduler/level_stage.dart';
import '../../game/application/run_controller.dart';
import '../../game/application/session_loader.dart';
import '../../settings/application/reminder_scheduler.dart';
import '../../sky/application/sky_controller.dart';

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

  /// Новый уровень: новые фразы и повторы, разложенные по четырём этапам.
  ///
  /// Босс-фразы в конце нет: этапы её заменили, и последний забег уровня —
  /// «напоминание», обычные тусклые повторы. Числа новых фраз здесь тоже
  /// больше нет («шесть») — оно живёт в [SessionBalance.newWordsPerLevel] и
  /// растёт, когда игрок включил свой темп.
  level,

  /// Итог уровня.
  levelResult,

  /// Спринт: финальная проверка пройденной темы на время.
  sprint,

  /// Итог попытки спринта.
  sprintResult,

  /// Ритуал пройден целиком.
  done,
}

class RitualState {
  const RitualState({
    this.phase = RitualPhase.idle,
    this.lumensReturned = 0,
    this.score = 0,
    this.climb = const ClimbState(),
    this.playedLevel = 0,
    this.newWords = 0,
    this.reviewed = 0,
    this.stage,
    this.levelCorrect = 0,
    this.levelAnswered = 0,
    this.sprintAttempt = 0,
    this.sprintGoal,
    this.sprintDone = 0,
    this.error,
  });

  final RitualPhase phase;

  /// Люмены, вернувшиеся небу за Восход, — единственная цифра, которую
  /// показывает его итог. Не очки: Восход не про очки.
  final int lumensReturned;

  final int score;

  /// Заход, в котором идёт игра: уровень, множитель, накопленная сумма.
  final ClimbState climb;

  /// Уровень захода, на котором сыгран последний уровень.
  ///
  /// Отдельно от `climb.level`, потому что после перехода тот показывает
  /// уже следующий уровень, а похвала на экране итога должна относиться к
  /// сделанному. И отдельно от `climb.levelsPlayed`: тот считает уровни, а
  /// после сброса счётчик расходится с номером сложности.
  final int playedLevel;
  final int newWords;
  final int reviewed;

  /// Этап, который идёт сейчас. `null` вне уровня.
  final LevelStage? stage;

  /// Верных ответов и всего ответов **за уровень целиком**.
  ///
  /// Раньше заход поднимался или сбрасывался по точности последнего забега —
  /// то есть босса, одного круга. С этапами это стало прямо неверно: уровень
  /// из тридцати кругов оценивался бы по последним четырём (этап
  /// «напоминание»), а «слабый уровень» означал бы «промахнулся на одном
  /// повторе».
  final int levelCorrect;
  final int levelAnswered;

  /// Какая попытка спринта идёт, считая с нуля.
  final int sprintAttempt;

  /// Планка текущей попытки. `null` вне спринта.
  final SprintGoal? sprintGoal;

  /// Сколько связей набрано в последней попытке.
  final int sprintDone;

  final String? error;

  /// Планка взята.
  bool get sprintReached => sprintGoal?.reachedBy(sprintDone) ?? false;

  /// Есть ли ещё попытка. Планка растёт, время — нет.
  bool get hasNextSprint =>
      sprintReached && sprintAttempt + 1 < StageBalance.sprintAttempts;

  bool get isPlaying =>
      phase == RitualPhase.sunrise ||
      phase == RitualPhase.level ||
      phase == RitualPhase.sprint;

  /// Точность уровня целиком. Пустой уровень — ноль, а не деление на ноль.
  double get levelAccuracy =>
      levelAnswered == 0 ? 0 : levelCorrect / levelAnswered;

  RitualState copyWith({
    RitualPhase? phase,
    int? lumensReturned,
    int? score,
    ClimbState? climb,
    int? playedLevel,
    int? newWords,
    int? reviewed,
    LevelStage? Function()? stage,
    int? levelCorrect,
    int? levelAnswered,
    int? sprintAttempt,
    SprintGoal? Function()? sprintGoal,
    int? sprintDone,
    String? Function()? error,
  }) =>
      RitualState(
        phase: phase ?? this.phase,
        lumensReturned: lumensReturned ?? this.lumensReturned,
        score: score ?? this.score,
        climb: climb ?? this.climb,
        playedLevel: playedLevel ?? this.playedLevel,
        newWords: newWords ?? this.newWords,
        reviewed: reviewed ?? this.reviewed,
        stage: stage == null ? this.stage : stage(),
        levelCorrect: levelCorrect ?? this.levelCorrect,
        levelAnswered: levelAnswered ?? this.levelAnswered,
        sprintAttempt: sprintAttempt ?? this.sprintAttempt,
        sprintGoal: sprintGoal == null ? this.sprintGoal : sprintGoal(),
        sprintDone: sprintDone ?? this.sprintDone,
        error: error == null ? this.error : error(),
      );
}

/// Ведёт игрока по ритуалу: Восход → уровень → ночной вызов.
class RitualController extends Notifier<RitualState> {
  @override
  RitualState build() => const RitualState();

  DateTime _startedAt = DateTime.now();

  /// Забеги уровня, которые ещё не сыграны.
  ///
  /// Уровень — это четыре забега, по одному на этап
  /// (`StageRules.levelOrder`): комбо сбрасывается между ними, и темп
  /// задаётся именно так. Стояло «три забега и босс» — босса нет, а число
  /// забегов не задано нигде: его даёт расписание этапов, и длинный этап
  /// загрузчик режет ещё, если кругов больше, чем влезает в забег.
  final List<LoadedRun> _pendingRuns = [];

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
            session.runs.first.questions,
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
      final now = DateTime.now();
      final climb = await _resumeClimb(now);
      final session = await ref
          .read(sessionLoaderProvider)
          .level(now, difficulty: climb.difficulty);

      if (session.isEmpty) {
        state = state.copyWith(phase: RitualPhase.done);
        return;
      }

      _pendingRuns
        ..clear()
        ..addAll(session.runs);
      _totalRuns = _pendingRuns.length;

      final first = _pendingRuns.removeAt(0);
      ref.read(runControllerProvider.notifier).start(
            first.questions,
            climb: climb,
            stage: first.stage,
            goal: first.goal,
          );
      state = state.copyWith(
        phase: RitualPhase.level,
        newWords: session.newWords,
        climb: climb,
        stage: () => first.stage,
        levelCorrect: 0,
        levelAnswered: 0,
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
        // Точность копится по уровню целиком, а не берётся у последнего
        // забега: этапов четыре, и оценивать тридцать кругов по четырём
        // последним — это оценивать уровень по хвосту повторов.
        final finished = ref.read(runControllerProvider);
        state = state.copyWith(
          score: state.score + (summary?.total ?? 0),
          lumensReturned: state.lumensReturned + run.lumensGained,
          levelCorrect: state.levelCorrect + finished.correct,
          levelAnswered: state.levelAnswered + run.circles,
        );

        if (_pendingRuns.isNotEmpty) {
          // Следующий забег того же уровня: комбо начинается заново, а
          // сложность и множитель захода те же — уровень ещё не кончился.
          final next = _pendingRuns.removeAt(0);
          run.start(
            next.questions,
            climb: state.climb,
            stage: next.stage,
            goal: next.goal,
          );
          state = state.copyWith(stage: () => next.stage);
          return;
        }

        // Заход поднимается или сбрасывается по точности **уровня**.
        final climbed = ClimbRules.afterLevel(
          state.climb,
          score: state.score,
          accuracy: state.levelAccuracy,
          at: DateTime.now(),
        );
        ref.read(analyticsProvider).log(AnalyticsEvents.levelCompleted, {
          'score': state.score,
          'accuracy': summary?.accuracy ?? 0,
          'climb_level': state.climb.level,
        });
        state = state.copyWith(
          phase: RitualPhase.levelResult,
          climb: climbed,
          playedLevel: state.climb.level,
        );
        await _saveSession();
      case _:
        break;
    }
  }

  /// Есть ли смысл предлагать спринт.
  ///
  /// Два условия, и оба обязательны. Тема пройдена — иначе гонка идёт по
  /// материалу, который ещё учат; и ярких слов достаточно — иначе планировщик
  /// вернёт пустоту, и кнопка окажется обманом.
  ///
  /// Читается прямо из неба, а не из отдельного флага: «тема пройдена» это
  /// зажжённое созвездие, и второе определение того же самого рано или поздно
  /// разошлось бы с первым.
  bool get canSprint {
    final sky = ref.read(skySnapshotProvider).value;
    return (sky?.litConstellations ?? 0) > 0;
  }

  /// Начинает спринт: первую попытку или следующую.
  Future<void> startSprint() async {
    final attempt = state.phase == RitualPhase.sprintResult
        ? state.sprintAttempt + 1
        : 0;
    state = state.copyWith(phase: RitualPhase.loading, error: () => null);

    try {
      final session = await ref.read(sessionLoaderProvider).sprintRun(
            DateTime.now(),
            attempt: attempt,
            difficulty: state.climb.difficulty,
          );

      if (session.isEmpty) {
        // Ярких слов не нашлось. Это не ошибка: гонка на незнакомом
        // материале учит панике, и отказаться от неё честнее, чем провести.
        state = state.copyWith(phase: RitualPhase.done);
        return;
      }

      final run = session.runs.first;
      ref.read(runControllerProvider.notifier).start(
            run.questions,
            climb: state.climb,
            stage: run.stage,
            goal: run.goal,
          );
      state = state.copyWith(
        phase: RitualPhase.sprint,
        stage: () => run.stage,
        sprintAttempt: attempt,
        sprintGoal: () => run.goal,
        sprintDone: 0,
      );
    } catch (e) {
      state = state.copyWith(phase: RitualPhase.levelResult, error: () => '$e');
    }
  }

  /// Переход к следующей фазе с экрана итога.
  Future<void> next() async {
    switch (state.phase) {
      case RitualPhase.sunriseResult:
        await _startLevel();
      case RitualPhase.levelResult:
        state = state.copyWith(phase: RitualPhase.done);
      case RitualPhase.sprintResult:
        // Следующая попытка есть только у взятой планки: расти можно
        // вверх, а не вниз. Не взятая планка просто заканчивает спринт.
        if (state.hasNextSprint) {
          await startSprint();
        } else {
          state = state.copyWith(phase: RitualPhase.done);
        }
      case _:
        break;
    }
  }

  /// Ритуал закрывается: начатое прервано или пройдено до конца.
  ///
  /// Одна дверь на оба выхода, потому что снаружи они и есть одно: экран
  /// возвращается на домашнюю страницу ритуала, а игра больше ничего не
  /// отсчитывает. Звалось это `reset`, и имя было честным, пока метод трогал
  /// только своё состояние; теперь он закрывает и забег, а «сбросить» про это
  /// не говорит.
  ///
  /// **Порядок здесь обязателен, и это не стиль.** Сперва обнуляется ритуал и
  /// только потом кончается забег: о конце забега узнаёт экран (он слушает
  /// `runControllerProvider`) и приносит его назад, в [onRunFinished]. Кончи
  /// забег первым — и прерывание уровня, у которого остались этапы, запустило
  /// бы следующий этап вместо выхода. Обнулённый ритуал на то же сообщение не
  /// отвечает ничем.
  ///
  /// **Забег заканчивается пустым стартом, и это не хитрость.**
  /// `RunController.start` с пустым списком — единственное «забега больше нет»
  /// в его словаре: он отменяет таймеры круга и кладёт пустое состояние. Без
  /// этого прерывание оставляло бы забег живым — экран забега уходит из дерева,
  /// а окно ответа продолжает истекать, просрочки уходят в память ответами «не
  /// вспомнил», и озвучка читает верные варианты в пустоту. Ровно это крестик
  /// и делал.
  void close() {
    _pendingRuns.clear();
    _totalRuns = 0;
    state = const RitualState();
    ref.read(runControllerProvider.notifier).start(const []);
    // Небо пересобирается: ответы уходили в базу по ходу забега, поэтому
    // яркость изменилась и у прерванного.
    ref.invalidate(skySnapshotProvider);
  }

  /// Идентификатор захода, в котором идёт игра. Хранится здесь, а не в
  /// состоянии: экранам он не нужен, а записи в базе — нужен.
  String? _climbId;

  /// Возобновляет заход или начинает новый.
  ///
  /// Решает база, а не память процесса: игрок мог закрыть приложение между
  /// уровнями, и «полчаса без игры» должны считаться от последней игры, а
  /// не от последнего запуска.
  Future<ClimbState> _resumeClimb(DateTime now) async {
    final last = await ref.read(appDatabaseProvider).lastPlayed();
    if (last != null && ClimbRules.continues(last.at, now)) {
      _climbId ??= last.climbId;
      // Уровень берётся из базы, если процесс перезапускался: состояние
      // контроллера тогда пустое, а заход продолжается.
      if (state.climb.isEmpty && last.climbId != null) {
        return ClimbState(level: last.level, startedAt: last.at);
      }
      return state.climb;
    }
    _climbId = 'c${now.microsecondsSinceEpoch}';
    return const ClimbState();
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
              // Заход и уровень, на котором СЫГРАНО. `climb.level` к этому
              // моменту уже показывает следующий: переход случился раньше
              // записи, и записать его значило бы завысить историю.
              climbId: Value(_climbId),
              climbLevel: Value(state.playedLevel),
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
