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
    this.granted,
    this.seeded = 0,
  });

  final CalibrationState calibration;

  /// Круг, который показывается сейчас.
  final CircleQuestion? question;

  final bool loading;
  final String? error;

  /// Ярус, который игрок получил, — уже урезанный до запущенного.
  ///
  /// Отдельно от `calibration.result`, и это не дублирование: замеренный ярус
  /// и выданный — разные числа, и экран результата обязан показать оба.
  /// Иначе игрок, ответивший на B1, видит «A0» без объяснения и делает
  /// единственный доступный вывод: тест его не понял.
  final Tier? granted;

  /// Сколько слов теста уже засеяно в память — те самые звёзды, которые
  /// горят на небе с первой минуты.
  final int seeded;

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

  /// Фразы, которые игрок подтвердил: из них засевается память.
  final Map<String, Tier> _confirmed = {};

  Future<void> start() async {
    _confirmed.clear();
    state = CalibrationUiState(
      calibration: CalibrationState.start(),
      loading: true,
    );
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationStarted);
    await _loadQuestion();
  }

  /// Ответ на текущий круг — выбором варианта.
  ///
  /// Вход один: фразовых кругов со слотами больше нет, и второго способа
  /// ответить тоже. Пока их было два, они успели разойтись — забег сверял
  /// собранное предложение, а калибровка расстановку по слотам, то есть
  /// объявляла бы верную сборку ошибкой при замере уровня.
  Future<void> answer(int index, Duration latency) async {
    final question = state.question;
    if (question == null || state.loading) return;
    await _record(question, question.isCorrectOption(index), latency);
  }

  /// Проигрывает центр сам, как только круг открылся.
  ///
  /// В калибровке это важнее, чем в забеге: тест мерит не только правильность,
  /// но и время ответа. Пока слово надо было сначала добыть нажатием на
  /// динамик, в это время попадала догадка «как вообще услышать задание» — на
  /// первом же экране приложения, у игрока, который видит его впервые.
  void _speakPrompt() {
    final text = state.question?.promptSpeech;
    if (text != null) ref.read(speechServiceProvider).speak(text);
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
      _confirmed[question.itemId] = question.tier;
    }

    final next = Calibration.answer(
      state.calibration,
      correct: correct,
      latency: latency,
    );

    // Круг остаётся на экране, пока идёт пауза, — и это единственное, чего
    // калибровке не хватало, чтобы фраза вообще была играбельной.
    //
    // Здесь стояло `CalibrationUiState(calibration: next, loading: true)`, без
    // `question`. Поле необязательное, так что вопрос становился `null`, и
    // экран — он строится раньше арены, потому что он предок — переставал
    // попадать в свою ветку `question: final question?` и падал в
    // `CircularProgressIndicator`. Арену деактивировали в том же кадре, в
    // котором игрок поставил последнее слово: кадр, где видно собранное
    // предложение и проявившийся перевод, не рисовался **никогда**. В
    // онбординге, то есть на первой же фразе, которую человек видит в игре.
    //
    // Пауза при этом равнялась нулю: у калибровки не было ни фазы показа, ни
    // числа для неё. В забеге такое число было (420 мс), и расхождение двух
    // путей игры именно этого рода и предотвращает правило «все игровые
    // числа в balance.dart».
    state = CalibrationUiState(
      calibration: state.calibration,
      question: question,
      loading: true,
    );
    await Future<void>.delayed(
      RevealBalance.forMode(question.mode, correct: correct),
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
      _speakPrompt();
    } catch (e) {
      state = CalibrationUiState(
        calibration: state.calibration,
        error: '$e',
      );
    }
  }

  /// Круг для шага теста.
  ///
  /// Фраза берётся из **отобранного** набора (`content/calibration/<lang>.yaml`),
  /// а не наугад: набор идёт по кругу через созвездия, и решение о ярусе не
  /// должно зависеть от жеребьёвки. Пока набор читать было некому, правка
  /// файла ни на что не влияла — это уже случалось.
  ///
  /// Пул вариантов здесь свой: игрок ещё не начал играть, знать он ничего не
  /// может, поэтому пять других фраз берутся из того же яруса. Метод
  /// исключения на калибровке и не нужен — тест мерит, а не учит.
  Future<CircleQuestion?> _buildQuestion(CalibrationStep step) async {
    final content = ref.read(currentContentDatabaseProvider);
    final player = ref.read(playerControllerProvider);
    final builder = QuestionBuilder(
      content: content,
      targetLang: player?.targetLang ?? defaultTargetLang,
      nativeLang: player?.nativeLang ?? defaultNativeLang,
      random: _random,
    );

    final onTier = await content.phrasesOn(step.tier);
    if (onTier.isEmpty) return null;

    final curated = (await content.calibrationFor(step.tier))
        .map((i) => i.phraseId)
        .where((id) => onTier.any((p) => p.id == id))
        .toList();

    final itemId = curated.isNotEmpty
        ? curated[_random.nextInt(curated.length)]
        : onTier[_random.nextInt(onTier.length)].id;

    final pool = [for (final row in onTier) row.id]..shuffle(_random);

    return builder.build(
      PlannedCircle(
        itemId: itemId,
        mode: step.mode,
        isNew: false,
        lumens: 0,
      ),
      pool: pool,
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

    // Потолок **дожидается**, а не читается на лету.
    //
    // `maxTierProvider` до ответа метаданных не запрещал ничего, а первым
    // читателем этого потолка была вот эта строка — то есть на первом запуске
    // ограничение не срабатывало никогда, и измеренный B2 записывался игроку
    // насовсем на сборке с одним запущенным A0. Провайдер теперь осторожен по
    // умолчанию, но правильный ответ здесь всё равно один: решение,
    // записываемое в базу, принимается по готовым данным, а не по заглушке.
    final launched = await ref.read(launchedTiersProvider.future);
    final ceiling = launched.isEmpty
        ? Tier.a0
        : launched.reduce((a, b) => a.index >= b.index ? a : b);
    final tier = measured.atMost(ceiling);

    var seeded = 0;
    try {
      await ref.read(wordStateRepositoryProvider).seed(
            confirmed: _confirmed,
            lumens: (CalibrationBalance.seedLmMin +
                    CalibrationBalance.seedLmMax) ~/
                2,
            now: DateTime.now(),
          );
      seeded = _confirmed.length;
    } catch (_) {
      // Засев — оптимизация, а не условие игры.
    }

    // Ярус записывается, а калибровка **не** объявляется пройденной.
    //
    // Здесь стоял `completeCalibration`, и он открывал гейт роутера: тот
    // немедленно уводил игрока с `/onboarding` на карту. Экран результата —
    // следующий шаг онбординга — при этом не показывался вовсе. Он был
    // написан, локализован на шесть языков и недостижим: игрок узнавал свой
    // ярус из бейджа в углу карты, без единого слова о том, откуда он взялся.
    //
    // Теперь гейт открывает кнопка «Открыть небо» на экране результата. Цена
    // — если приложение закрыть на этом экране, тест придётся пройти заново
    // (засев при этом уже сохранён). Плата за то, что игрок вообще увидит
    // результат, а не догадается о нём.
    ref.read(playerControllerProvider.notifier).setTier(tier);
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationCompleted, {
      'tier': tier.code,
      'measured': measured.code,
      'circles': calibration.asked,
      'seeded': seeded,
    });

    state = CalibrationUiState(
      calibration: calibration,
      granted: tier,
      seeded: seeded,
    );
  }
}

final calibrationControllerProvider =
    NotifierProvider<CalibrationController, CalibrationUiState>(
  CalibrationController.new,
);
