import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/audio/speech_service.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/word_state_repository.dart';
import '../../../domain/calibration/calibration.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scheduler/session_planner.dart';
import '../../../domain/scoring/balance.dart';
import '../../game/application/question_builder.dart';

/// Состояние экрана калибровки.
class CalibrationUiState {
  const CalibrationUiState({
    required this.calibration,
    this.question,
    this.loading = false,
    this.error,
  });

  final CalibrationState calibration;

  /// Круг, который показывается сейчас.
  final CircleQuestion? question;

  final bool loading;
  final String? error;

  bool get isDone => calibration.isDone;
  double get progress => calibration.progress;
}

/// Ведёт калибровку: спрашивает у домена, что показать, и достаёт это из
/// контентной базы.
///
/// Домен ничего не знает про базы, база ничего не знает про алгоритм — эта
/// прослойка существует ровно затем, чтобы так и осталось.
class CalibrationController extends Notifier<CalibrationUiState> {
  @override
  CalibrationUiState build() =>
      CalibrationUiState(calibration: CalibrationState.start());

  final _random = Random();

  /// Слова, которые игрок подтвердил: из них засевается память.
  final Map<String, Tier> _confirmedConcepts = {};

  Future<void> start() async {
    _confirmedConcepts.clear();
    state = CalibrationUiState(
      calibration: CalibrationState.start(),
      loading: true,
    );
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationStarted);
    await _loadQuestion();
  }

  /// Ответ на текущий круг — выбором варианта.
  Future<void> answer(int index, Duration latency) async {
    final question = state.question;
    if (question == null || state.loading) return;
    if (!question.isSingleSlot) return;
    await _record(question, question.isCorrectOption(index), latency);
  }

  /// Ответ на фразовый вопрос — заполнением всех слотов.
  Future<void> answerSlots(List<int> bySlot, Duration latency) async {
    final question = state.question;
    if (question == null || state.loading) return;

    final correct = bySlot.length == question.slotCount &&
        List.generate(question.slotCount, (i) => i)
            .every((i) => question.isCorrectFor(i, bySlot[i]));
    await _record(question, correct, latency);
  }

  /// Проигрывает центр заново — механики на слух.
  void replayPrompt() {
    final text = state.question?.promptSpeech;
    if (text != null) ref.read(speechServiceProvider).speak(text);
  }

  Future<void> _record(
    CircleQuestion question,
    bool correct,
    Duration latency,
  ) async {
    if (correct) {
      // Верный ответ озвучивается и здесь: калибровка — это уже игра.
      if (question.answerSpeech != null) {
        ref.read(speechServiceProvider).speak(question.answerSpeech!);
      }
      _confirmedConcepts[question.itemId] = question.tier;
    }

    final next = Calibration.answer(
      state.calibration,
      correct: correct,
      latency: latency,
    );

    state = CalibrationUiState(calibration: next, loading: true);

    if (next.isDone) {
      await _finish(next);
      return;
    }
    await _loadQuestion();
  }

  /// Кнопка «я с нуля»: A0 без теста.
  Future<void> skip() async {
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationSkipped);
    final done = Calibration.fromScratch();
    state = CalibrationUiState(calibration: done);
    ref.read(playerControllerProvider.notifier).completeCalibration(Tier.a0);
  }

  Future<void> _loadQuestion() async {
    try {
      final step = state.calibration.step;
      final question = await _buildQuestion(step);

      if (question == null) {
        // Контента на этом ярусе нет. Считаем круг непройденным и идём
        // дальше: остановить онбординг из-за нехватки контента — худшее,
        // что можно сделать с первым впечатлением.
        final next = Calibration.answer(
          state.calibration,
          correct: false,
          latency: const Duration(seconds: 5),
        );
        if (next.isDone) {
          await _finish(next);
          return;
        }
        state = CalibrationUiState(calibration: next, loading: true);
        await _loadQuestion();
        return;
      }

      state = CalibrationUiState(
        calibration: state.calibration,
        question: question,
      );
    } catch (e) {
      state = CalibrationUiState(
        calibration: state.calibration,
        error: '$e',
      );
    }
  }

  /// Круг для шага теста.
  ///
  /// Набор калибровки из `content.db` используется, если он написан; пока
  /// его нет — берём обычные концепты яруса. Тест от этого чуть менее
  /// точен, но работает, а не падает.
  Future<CircleQuestion?> _buildQuestion(CalibrationStep step) async {
    final content = ref.read(currentContentDatabaseProvider);
    final player = ref.read(playerControllerProvider);
    final builder = QuestionBuilder(
      content: content,
      targetLang: player?.targetLang ?? defaultTargetLang,
      nativeLang: player?.nativeLang ?? defaultNativeLang,
      random: _random,
    );

    if (step.mode.isPhrase) {
      final constellations = await content.constellations();
      if (constellations.isEmpty) return null;
      // Калибровка спрашивает фразу на самой лёгкой глубине: она измеряет
      // уровень игрока, а не его выносливость. Глубже — уже проверка, а не
      // замер.
      return builder.buildPhrase(
        constellation: constellations[_random.nextInt(constellations.length)],
        tier: step.tier,
        lumens: 0,
        gaps: SessionBalance.phraseGapsMin,
      );
    }

    final items = await content.calibrationFor(step.tier);
    final conceptIds = items
        .where((i) => i.conceptId != null)
        .map((i) => i.conceptId!)
        .toList();

    if (conceptIds.isEmpty) {
      final concepts = await content.conceptsUpTo(step.tier);
      final onTier =
          concepts.where((c) => c.tier == step.tier.code).toList();
      if (onTier.isEmpty) return null;
      conceptIds.add(onTier[_random.nextInt(onTier.length)].id);
    }

    return builder.build(
      PlannedCircle(
        itemId: conceptIds[_random.nextInt(conceptIds.length)],
        mode: step.mode,
        isNew: false,
        lumens: 0,
        // Вид дистракторов приходит из шага, а не выводится из механики.
        // На подтверждении границы он созвучный: шесть тематических дают
        // 17 % случайного попадания, и подтверждать ярус на них дёшево.
        distractorKind: step.distractorKind,
      ),
    );
  }

  /// Тест не выдаёт лицензию — он засевает память.
  ///
  /// Подтверждённые слова стартуют с 50–60 lm и сразу попадают в очередь
  /// повторений. Игрок видит небо, где часть звёзд уже горит, а планировщик
  /// с первого дня работает с реальным словарём человека.
  Future<void> _finish(CalibrationState calibration) async {
    // Замеренный ярус может оказаться выше запущенного: гребёнка нарочно
    // спрашивает выше текущего уровня, иначе не найдёт потолок. Но выдать
    // игроку ярус, который не вычитан и не озвучен, нельзя — правило
    // «ярус не запускается без вычитки» касается и калибровки.
    final measured = calibration.result ?? Tier.a0;
    final tier = measured.atMost(ref.read(maxTierProvider));

    try {
      await ref.read(wordStateRepositoryProvider).seed(
            confirmed: _confirmedConcepts,
            lumens: (CalibrationBalance.seedLmMin +
                    CalibrationBalance.seedLmMax) ~/
                2,
            now: DateTime.now(),
          );
    } catch (_) {
      // Засев — оптимизация, а не условие игры.
    }

    ref.read(playerControllerProvider.notifier).completeCalibration(tier);
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationCompleted, {
      'tier': tier.code,
      'circles': calibration.asked,
      'seeded': _confirmedConcepts.length,
    });

    state = CalibrationUiState(calibration: calibration);
  }
}

final calibrationControllerProvider =
    NotifierProvider<CalibrationController, CalibrationUiState>(
  CalibrationController.new,
);
