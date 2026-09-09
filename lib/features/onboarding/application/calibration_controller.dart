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

    // Тем же способом, что забег: сравнивается собранное предложение, а не
    // расстановка по слотам. Сверка по слотам игнорировала заявленные
    // порядки слов и объявила бы верную сборку ошибкой — при замере уровня,
    // где ошибка стоит яруса.
    await _record(question, question.acceptsSlots(bySlot), latency);
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
      // Засевается только слово, и это не мелочь в двух местах сразу.
      //
      // Во-первых, у фразового круга `itemId` — концепт, который фраза учит,
      // а если фраза не привязана ни к одному концепту, то **её собственный
      // id**. Такая строка памяти не соответствует ни одной звезде: на карте
      // она невидима, круг из неё не собирается, отзыв по ней не пишется —
      // значит она просрочена навсегда и вечно занимает место в начале
      // очереди повторений.
      //
      // Во-вторых, доказательство слабое и без этого. Калибровочная фраза
      // спрашивается на минимальной глубине: два пропуска, две плитки, то
      // есть выбор из двух порядков. Верная сборка говорит о порядке слов, а
      // не о том, что игрок знает вот это слово.
      if (!question.mode.isPhrase) {
        _confirmedConcepts[question.itemId] = question.tier;
      }
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
      // Фраза берётся из **отобранного** набора, а не наугад.
      //
      // `content/calibration/de.yaml` несёт по четыре фразы на ярус,
      // выбранные по кругу через созвездия, и они отгружались в базу — а
      // читать их было некому: эта ветка брала случайное созвездие и
      // случайную фразу, а `phrase_id` из набора не спрашивал никто. Правка
      // файла ни на что не влияла.
      //
      // Это не косметика: финальная проверка фразами решает, оставить игроку
      // измеренный ярус или спустить на один. Решение, принятое по четырём
      // случайным фразам вместо четырёх отобранных, зависит от жеребьёвки —
      // а фразы разной длины теперь и разной трудности.
      final curated = (await content.calibrationFor(step.tier))
          .where((i) => i.phraseId != null)
          .map((i) => i.phraseId!)
          .toList();

      if (curated.isNotEmpty) {
        final phrase = await content
            .phrase(curated[_random.nextInt(curated.length)]);
        if (phrase != null) {
          // Калибровка спрашивает фразу на самой лёгкой глубине: она измеряет
          // уровень игрока, а не его выносливость.
          return builder.buildPhraseQuestion(
            phrase: phrase,
            lumens: 0,
            gaps: SessionBalance.phraseGapsMin,
          );
        }
      }

      // Набора нет — берём любую фразу яруса. Прежнее поведение осталось
      // запасным путём, а не основным.
      final constellations = await content.constellations();
      if (constellations.isEmpty) return null;
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
            confirmed: _confirmedConcepts,
            lumens: (CalibrationBalance.seedLmMin +
                    CalibrationBalance.seedLmMax) ~/
                2,
            now: DateTime.now(),
          );
      seeded = _confirmedConcepts.length;
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
