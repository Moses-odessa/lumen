import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/audio/speech_service.dart';
import '../../../domain/entities/circle_question.dart';
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
        summary = null;

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

  CircleQuestion? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  bool get isFinished => phase == RunPhase.finished;

  /// Прогресс забега 0..1 — по отвеченным кругам плана, а не по очереди:
  /// иначе полоса ползла бы назад на каждой ошибке.
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

  @override
  RunState build() {
    ref.onDispose(() => _advanceTimer?.cancel());
    return const RunState.empty();
  }

  /// Начинает забег по готовому списку кругов.
  ///
  /// [maxDuration] ограничивает забег по времени, а не по числу кругов —
  /// так устроен Восход: две минуты повторений, сколько успеется. Круг,
  /// начатый до истечения времени, всегда доигрывается: обрывать человека
  /// на середине ответа — это способ научить его не начинать.
  void start(List<CircleQuestion> questions, {Duration? maxDuration}) {
    _advanceTimer?.cancel();
    _lmGained = 0;
    _deadline = maxDuration == null ? null : DateTime.now().add(maxDuration);
    _startedAt = DateTime.now();

    if (questions.isEmpty) {
      state = const RunState.empty();
      return;
    }

    _run = RunScore();
    state = RunState(
      queue: List.of(questions),
      index: 0,
      phase: RunPhase.asking,
      score: 0,
      combo: const ComboState(),
      correct: 0,
      answered: 0,
      total: questions.length,
    );

    ref.read(analyticsProvider).log(AnalyticsEvents.runStarted, {
      'circles': questions.length,
    });
    _preloadNext();
  }

  RunScore _run = RunScore();

  /// Когда забег обязан закончиться; `null` — играем всю очередь.
  DateTime? _deadline;

  DateTime _startedAt = DateTime.now();

  /// Сколько длился забег — уходит в журнал сессий.
  Duration get elapsed => DateTime.now().difference(_startedAt);

  /// Ответ выбором варианта.
  void answerOption(int index, Duration latency) {
    final question = state.current;
    if (question == null || state.phase != RunPhase.asking) return;
    _submit(question, question.isCorrectOption(index), latency);
  }

  /// Ответ вводом текста.
  void answerInput(String input, Duration latency) {
    final question = state.current;
    if (question == null || state.phase != RunPhase.asking) return;
    _submit(question, question.isCorrectInput(input), latency);
  }

  void _submit(CircleQuestion question, bool correct, Duration latency) {
    final result = _run.apply(
      correct: correct,
      latency: latency,
      mode: question.mode,
      lumens: question.lumens,
    );

    // Каждое верное соединение озвучивается — во всех режимах, а не только
    // в «Слухе». Играет поверх анимации, не задерживая следующий круг.
    final speech = ref.read(speechServiceProvider);
    if (correct && question.answerSpeech != null) {
      speech.speak(question.answerSpeech!);
    } else if (!correct) {
      speech.haptic();
    }

    // Память обновляется в фоне: диск между кругами игрок ждать не должен.
    unawaited(_persist(question, correct, latency));

    final queue = List.of(state.queue);
    if (!correct) {
      // Слово возвращается в конец забега и теряет яркость.
      queue.add(question);
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
    _advanceTimer = Timer(_revealDuration(correct), _advance);
  }

  /// Пауза перед следующим кругом. На ошибке она длиннее: игроку надо
  /// успеть увидеть верный вариант, иначе ошибка ничему не учит.
  Duration _revealDuration(bool correct) => correct
      ? const Duration(milliseconds: 420)
      : const Duration(milliseconds: 1100);

  void _advance() {
    final next = state.index + 1;
    if (next >= state.queue.length || _isOutOfTime) {
      _finish();
      return;
    }
    state = state.copyWith(
      index: next,
      phase: RunPhase.asking,
      lastCorrect: () => null,
    );
    _preloadNext();
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

  /// Проигрывает центр в режиме «Слух».
  ///
  /// Переслушивание разрешено, но снимает скоростной множитель — иначе
  /// «Слух» превращался бы в «Круг» с лишним тапом.
  void replayPrompt() {
    final text = state.current?.promptSpeech;
    if (text != null) ref.read(speechServiceProvider).speak(text);
  }

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
