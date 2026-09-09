import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/audio/speech_service.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/scheduler/level_stage.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/scoring/climb.dart';
import '../../../domain/scoring/score.dart';
import '../../../data/repositories/word_state_repository.dart';

/// Что показывает экран забега прямо сейчас.
enum RunPhase {
  /// Круг открыт, ждём ответа.
  asking,

  /// Ответ принят: подсветка и озвучка, следующий круг разворачивается.
  revealing,

  /// Забег закончен.
  finished,
}

/// Состояние забега.
class RunState {
  const RunState({
    required this.queue,
    required this.index,
    required this.phase,
    required this.score,
    required this.combo,
    required this.correct,
    required this.answered,
    required this.total,
    this.lastCorrect,
    this.summary,
    this.stage,
    this.goal,
  });

  const RunState.empty()
      : queue = const [],
        index = 0,
        phase = RunPhase.finished,
        score = 0,
        combo = const ComboState(),
        correct = 0,
        answered = 0,
        total = 0,
        lastCorrect = null,
        summary = null,
        stage = null,
        goal = null;

  /// Очередь кругов. Ошибочные слова возвращаются в её конец, поэтому она
  /// длиннее исходного плана.
  final List<CircleQuestion> queue;

  final int index;
  final RunPhase phase;
  final int score;
  final ComboState combo;

  /// Верных ответов и всего данных ответов.
  final int correct;
  final int answered;

  /// Кругов в исходном плане — по нему рисуется прогресс.
  final int total;

  /// Итог последнего ответа: для подсветки.
  final bool? lastCorrect;

  final RunSummary? summary;

  /// Этап уровня, на котором идёт забег. `null` у Восхода.
  final LevelStage? stage;

  /// Цель спринта. `null` у обычного забега.
  final SprintGoal? goal;

  /// Спринт: цель достигнута.
  bool get goalReached => goal?.reachedBy(correct) ?? false;

  CircleQuestion? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  bool get isFinished => phase == RunPhase.finished;

  /// Прогресс забега 0..1 — по отвеченным кругам плана, а не по очереди:
  /// иначе полоса ползла бы назад на каждой ошибке.
  ///
  /// У спринта та же формула означает путь к планке: `total` там равен числу
  /// нужных связей, а не длине очереди.
  double get progress => total == 0 ? 0 : (answered / total).clamp(0.0, 1.0);

  RunState copyWith({
    List<CircleQuestion>? queue,
    int? index,
    RunPhase? phase,
    int? score,
    ComboState? combo,
    int? correct,
    int? answered,
    int? total,
    bool? Function()? lastCorrect,
    RunSummary? summary,
    LevelStage? stage,
    SprintGoal? goal,
  }) =>
      RunState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        phase: phase ?? this.phase,
        score: score ?? this.score,
        combo: combo ?? this.combo,
        correct: correct ?? this.correct,
        answered: answered ?? this.answered,
        total: total ?? this.total,
        lastCorrect:
            lastCorrect == null ? this.lastCorrect : lastCorrect(),
        summary: summary ?? this.summary,
        stage: stage ?? this.stage,
        goal: goal ?? this.goal,
      );
}

/// Забег: 10–14 кругов подряд без пауз.
///
/// Три вещи, которые здесь важнее всего:
///
/// 1. **Звук не блокирует переход.** Озвучка запускается и тут же
///    забывается — следующий круг разворачивается поверх неё.
/// 2. **Запись в базу тоже не блокирует.** FSRS-обновление уходит в фон:
///    игрок не должен ждать диск между кругами.
/// 3. **Ошибка не блокирует.** Слово возвращается в конец очереди и теряет
///    яркость, но забег продолжается. Жизней в игре нет.
class RunController extends Notifier<RunState> {
  Timer? _advanceTimer;

  /// Окно на ответ. `null` — окна нет: либо круг новый, либо идёт показ.
  Timer? _windowTimer;

  @override
  RunState build() {
    ref.onDispose(() {
      _advanceTimer?.cancel();
      _windowTimer?.cancel();
    });
    return const RunState.empty();
  }

  /// Начинает забег по готовому списку кругов.
  ///
  /// [maxDuration] ограничивает забег по времени, а не по числу кругов —
  /// так устроен Восход: две минуты повторений, сколько успеется. Круг,
  /// начатый до истечения времени, всегда доигрывается: обрывать человека
  /// на середине ответа — это способ научить его не начинать.
  /// [climb] — уровень захода, на котором идёт забег. `null` для Восхода:
  /// он не про очки, а про то, что часть неба снова горит.
  /// [stage] — этап уровня, на котором идёт забег: от него зависит цена
  /// круга (показ платит меньше проверки). [goal] задан только у спринта: с
  /// ним забег кончается по достигнутой планке или по истечению времени, а не
  /// по концу очереди.
  void start(
    List<CircleQuestion> questions, {
    Duration? maxDuration,
    ClimbState? climb,
    LevelStage? stage,
    SprintGoal? goal,
  }) {
    _advanceTimer?.cancel();
    _lmGained = 0;
    // Флаг переслушивания живёт на круге, а не на забеге: без сброса новый
    // забег наследовал бы его с последнего круга предыдущего.
    _replayed = false;
    // У спринта время своё: планка в связях, а срок — в цели.
    final limit = goal?.duration ?? maxDuration;
    _deadline = limit == null ? null : DateTime.now().add(limit);
    _startedAt = DateTime.now();

    if (questions.isEmpty) {
      state = const RunState.empty();
      return;
    }

    _run = RunScore(
      difficulty: climb?.difficulty,
      climbMultiplier: climb?.multiplier ?? 1.0,
      stageFactor: stage == null ? 1.0 : StageRules.scoreFactorFor(stage),
    );
    state = RunState(
      queue: List.of(questions),
      index: 0,
      phase: RunPhase.asking,
      score: 0,
      combo: const ComboState(),
      correct: 0,
      answered: 0,
      // У спринта полоса прогресса показывает путь к планке, а не к концу
      // очереди: кругов в очереди намеренно вдвое больше, чем нужно связей.
      total: goal?.connections ?? questions.length,
      stage: stage,
      goal: goal,
    );

    ref.read(analyticsProvider).log(AnalyticsEvents.runStarted, {
      'circles': questions.length,
      'climb_level': climb?.level ?? 0,
      'stage': stage?.name ?? '',
    });
    _preloadNext();
    _speakPrompt();
    _openWindow();
  }

  /// Сколько кругов задано — для точности уровня целиком.
  int get circles => _run.circles;

  RunScore _run = RunScore();

  /// Когда забег обязан закончиться; `null` — играем всю очередь.
  DateTime? _deadline;

  DateTime _startedAt = DateTime.now();

  /// Сколько длился забег — уходит в журнал сессий.
  Duration get elapsed => DateTime.now().difference(_startedAt);

  /// Ответ выбором варианта — единственный способ ответить.
  ///
  /// Второй был: `answerSlots` принимал расстановку слов по пропускам фразы.
  /// Вместе с ним ушла и защита от того, чтобы многослотовый вопрос попал
  /// сюда, — она стерегла реальную дыру, в которой фраза с двумя пропусками
  /// засчитывалась бы полностью верной от одного тапа. Слот теперь один, и
  /// стеречь нечего.
  void answerOption(int index, Duration latency) {
    final question = state.current;
    if (question == null || state.phase != RunPhase.asking) return;
    _submit(question, question.isCorrectOption(index), latency);
  }

  /// Открывает окно на ответ: пять секунд, после которых круг закрывается
  /// сам.
  ///
  /// Смысл окна — учить отвечать быстро: ответ, который игрок вспоминал
  /// двадцать секунд, в разговоре ему не поможет.
  ///
  /// **На знакомстве окна нет.** Там вокруг новой фразы стоят пять уже
  /// известных, и к ответу игрок приходит исключением — читает пять знакомых
  /// строчек и понимает, какая шестая. Торопить его в этот момент значит
  /// требовать угадать, а не сообразить. Это же правило записано в проекте
  /// давно и в общем виде: на новом материале таймера нет.
  void _openWindow() {
    _windowTimer?.cancel();
    final question = state.current;
    if (question == null || question.isNew) return;
    _windowTimer = Timer(ScoreBalance.answerWindow, _expireWindow);
  }

  /// Время вышло: круг закрывается неверным ответом.
  ///
  /// Просрочка — это «не вспомнил», а не отдельный третий исход. Слово
  /// тускнеет и возвращается в очередь ровно так же, как после промаха:
  /// не успел значит не вспомнил. Отличие одно — верный вариант при этом
  /// **произносится**, потому что промолчавшему игроку его никто не назвал.
  void _expireWindow() {
    final question = state.current;
    if (question == null || state.phase != RunPhase.asking) return;
    _submit(question, false, ScoreBalance.answerWindow, expired: true);
  }

  void _submit(
    CircleQuestion question,
    bool correct,
    Duration latency, {
    bool expired = false,
  }) {
    _windowTimer?.cancel();

    final result = _run.apply(
      correct: correct,
      latency: latency,
      mode: question.mode,
      lumens: question.lumens,
      replayed: _replayed,
    );

    // Каждое верное соединение озвучивается — во всех режимах, а не только
    // в «Слухе». Играет поверх анимации, не задерживая следующий круг.
    final speech = ref.read(speechServiceProvider);
    if ((correct || expired) && question.answerSpeech != null) {
      // По просрочке звучит верный вариант, и это не поблажка: игрок ничего
      // не выбрал, значит ему не сказали ответ ни выбором, ни подсветкой
      // выбранного. Пауза после промаха для этого и длиннее.
      speech.speak(question.answerSpeech!);
    } else if (!correct) {
      speech.haptic();
    }

    // Память обновляется в фоне: диск между кругами игрок ждать не должен.
    // Уходит исходное время, а не приведённое: приводить его — работа домена,
    // а журнал отзывов хранит то, что было на самом деле.
    unawaited(_persist(question, correct, latency));

    final queue = List.of(state.queue);
    if (!correct) {
      // Слово возвращается в конец забега и теряет яркость.
      //
      // Другим экземпляром, и это не мелочь: арена сбрасывает состояние по
      // смене объекта вопроса. Пока за промахом стояли другие круги, разницы
      // не было — а когда промах последний, следующим показывался он же,
      // арена не сбрасывалась и переставала принимать ответы. Уровень висел.
      queue.add(question.again());
    }

    state = state.copyWith(
      queue: queue,
      phase: RunPhase.revealing,
      score: _run.score,
      combo: result.combo,
      correct: _run.correct,
      answered: state.answered + (correct ? 1 : 0),
      lastCorrect: () => correct,
    );

    _advanceTimer?.cancel();
    _advanceTimer = Timer(_revealDuration(question, correct), _advance);
  }

  /// Пауза перед следующим кругом.
  ///
  /// На ошибке она длиннее: игроку надо успеть увидеть верный вариант, иначе
  /// ошибка ничему не учит. У фразы длиннее всегда — и на верном ответе тоже,
  /// потому что показывать там больше нечего было **только** из-за этой
  /// паузы: собранное предложение проигрывается целиком и под ним проявляется
  /// перевод, а 420 мс не хватало ни на то, ни на другое. Игрок ставил
  /// последнее слово и получал следующий вопрос, так и не увидев, что собрал.
  Duration _revealDuration(CircleQuestion question, bool correct) =>
      RevealBalance.forMode(question.mode, correct: correct);

  /// Досрочно закрывает паузу — игрок нажал по арене.
  ///
  /// Фразовая пауза длинная нарочно: предложение надо услышать и прочитать
  /// перевод. Но заставлять ждать того, кто уже всё прочёл, — это плата за
  /// чужую медлительность. Ждать не обязан никто, пропустить не обязан тоже.
  void skipReveal() {
    if (state.phase != RunPhase.revealing) return;
    _advanceTimer?.cancel();
    _advance();
  }

  void _advance() {
    // Спринт кончается на достигнутой планке, а не на конце очереди:
    // считаются верные связи. Иначе ошибка, возвращающая круг в конец
    // очереди, продлевала бы забег — то есть наказание за промах
    // превращалось бы в лишнее время.
    if (state.goalReached) {
      _finish();
      return;
    }

    final next = state.index + 1;
    if (next >= state.queue.length || _isOutOfTime) {
      _finish();
      return;
    }
    _replayed = false;
    state = state.copyWith(
      index: next,
      phase: RunPhase.asking,
      lastCorrect: () => null,
    );
    _preloadNext();
    _speakPrompt();
    _openWindow();
  }

  /// Время Восхода вышло. Проверяется между кругами, а не по таймеру:
  /// прерывать открытый круг нельзя.
  bool get _isOutOfTime {
    final deadline = _deadline;
    return deadline != null && DateTime.now().isAfter(deadline);
  }

  /// Прогревает синтез между кругами.
  ///
  /// Предзагрузки у синтеза нет — открывать нечего. Но есть платформенный
  /// вызов состояния и ленивая настройка движка, и оба лучше сделать
  /// заранее, чем в момент касания.
  void _preloadNext() {
    unawaited(ref.read(speechServiceProvider).status());
  }

  /// Проигрывает центр сам, как только круг открылся.
  ///
  /// Механика на слух без этого начиналась тишиной: игрок видел динамик и
  /// должен был сообразить, что по нему надо нажать. Задание — узнать слово
  /// на слух, а не догадаться, как его услышать.
  ///
  /// И это же чинит скоростной множитель. `replayPrompt` ставит «переслушал»
  /// на каждом нажатии, включая первое, — а услышать слово иначе было нельзя,
  /// то есть множитель на «Слухе» терялся **всегда**, вопреки собственному
  /// правилу «его снимает переслушивание». Теперь первый раз играет игра, и
  /// снимает множитель только повторное нажатие.
  void _speakPrompt() {
    final text = state.current?.promptSpeech;
    if (text == null) return;
    ref.read(speechServiceProvider).speak(text);
  }

  /// Проигрывает центр заново по нажатию на динамик.
  ///
  /// Переслушивание разрешено, но снимает скоростной множитель — иначе
  /// «Слух» превращался бы в «Круг» с лишним тапом.
  void replayPrompt() {
    final text = state.current?.promptSpeech;
    if (text == null) return;
    _replayed = true;
    ref.read(speechServiceProvider).speak(text);
  }

  /// Переслушивал ли игрок центр на текущем круге.
  ///
  /// Сбрасывается при переходе к следующему кругу, а не при ответе: между
  /// ответом и переходом круг заморожен, и нажать динамик всё равно нельзя.
  bool _replayed = false;

  void _finish() {
    _advanceTimer?.cancel();
    final summary = _run.summary();
    state = state.copyWith(
      phase: RunPhase.finished,
      summary: summary,
      lastCorrect: () => null,
    );
    ref.read(analyticsProvider).log(AnalyticsEvents.runFinished, {
      'score': summary.total,
      'accuracy': summary.accuracy,
      'max_combo': summary.maxCombo,
    });
  }

  Future<void> _persist(
    CircleQuestion question,
    bool correct,
    Duration latency,
  ) async {
    try {
      final now = DateTime.now();
      final update =
          await ref.read(wordStateRepositoryProvider).applyAnswer(
                itemId: question.itemId,
                tier: question.tier,
                mode: question.mode,
                correct: correct,
                latency: latency,
                now: now,
              );

      final gained = update.lumensGained(now);
      if (gained > 0) _lmGained += gained;

      // Сообщаем только о моменте зажигания, а не о каждом быстром ответе
      // на уже горящем слове.
      if (update.justIgnited) {
        ref.read(analyticsProvider).log(AnalyticsEvents.wordBurning, {
          'concept': question.itemId,
        });
      }
    } catch (_) {
      // База недоступна — забег важнее прогресса. Потерянный ответ хуже,
      // чем прерванная игра, но ненамного: следующий круг всё исправит.
    }
  }

  int _lmGained = 0;

  /// Сколько люменов вернулось небу за забег — это и есть основа рейтинга
  /// лиг (M6): фармить повтором лёгкого его нельзя.
  int get lumensGained => _lmGained;
}

final runControllerProvider =
    NotifierProvider<RunController, RunState>(RunController.new);
