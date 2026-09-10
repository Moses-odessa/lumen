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
    this.recognised = 0,
  });

  final CalibrationState calibration;

  /// Круг, который показывается сейчас.
  final CircleQuestion? question;

  final bool loading;
  final String? error;

  /// Ярус, который игрок получил, — уже урезанный до запущенного.
  ///
  /// Само число считает домен (`CalibrationState.granted`), и потолок стоит
  /// там же — в чистой функции, под тестом. Поле осталось здесь, и не ради
  /// дублирования — оно означает не «сколько получилось», а «решение
  /// записано»: экран калибровки уходит на итог именно по его появлению,
  /// потому что до записи показывать разбор нечем.
  final Tier? granted;

  /// Сколько фраз засеяно в память — те самые звёзды, которые горят на небе с
  /// первой минуты.
  ///
  /// Меньше [recognised] на всё, что игрок узнал выше выданного яруса: такая
  /// фраза лежит на закрытом ярусе, в память не попадает и не светит нигде.
  /// Пока число было одно на две строки экрана итога, вторая обещала
  /// «5 слів із тесту вже світять на вашому небі» — при том, что светила одна.
  final int seeded;

  /// Сколько разных фраз игрок узнал за тест — на любом ярусе.
  final int recognised;

  bool get isDone => calibration.isDone;
  double get progress => calibration.progress;
}

/// Ведёт калибровку: спрашивает у домена, что показать, и достаёт это из
/// контентной базы.
///
/// Домен ничего не знает про базы, база ничего не знает про алгоритм — эта
/// прослойка существует ровно затем, чтобы так и осталось.
class CalibrationController extends Notifier<CalibrationUiState> {
  /// До [start] тест не начат, и потолок здесь самый строгий: A0.
  ///
  /// Настоящий потолок читается из метаданных в [start] — асинхронно, а
  /// `build()` синхронен. Заглушка обязана быть строгой, а не щедрой: щедрая
  /// в этом самом месте уже стоила игроку невычитанного яруса, записанного в
  /// базу насовсем.
  @override
  CalibrationUiState build() => CalibrationUiState(
        calibration: CalibrationState.start(ceiling: Tier.a0),
        loading: true,
      );

  final _random = Random();

  /// Фразы, которые игрок узнал: `id → ярус`. Из них засевается память.
  final Map<String, Tier> _confirmed = {};

  /// Фразы, уже показанные в этом тесте.
  ///
  /// Без этой памяти повторы были бы не редкостью, а правилом: жеребьёвка по
  /// тридцати отобранным вариантам яруса даёт совпадение уже к седьмому кругу
  /// чаще, чем не даёт. А повторённая фраза в тесте — это круг, который ничего
  /// не измерил и ничего не засеял: ответ на неё игрок помнит с прошлого раза.
  ///
  /// Запаса хватает с большим излишком, и это считается: с одного яруса
  /// спрашивается не больше `quotaFor(ярус) + maxRepeats` кругов — десять на
  /// A0 в самом худшем случае, — а отобрано на каждый ярус тридцать
  /// (`tool/make_calibration.dart`, `_phrasesPerTier`). Домен эту границу
  /// охраняет тестом «одна фраза дважды за тест не выпадет».
  final Set<String> _asked = {};

  Future<void> start() async {
    _confirmed.clear();
    _asked.clear();
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationStarted);

    // Потолок читается **до первого круга**, а не после последнего.
    //
    // Он нужен тесту самому: хвост засева спрашивает фразы выданного яруса и
    // ниже, а выданный ярус — это измеренный, урезанный потолком. Пока зажим
    // стоял в конце, в засев пришлось бы отдавать измеренный ярус, то есть
    // засевать фразами, которых игрок не увидит.
    //
    // `launchedTiersProvider` именно **дожидается**: `maxTierProvider` до
    // ответа метаданных отдаёт A0, и решение по заглушке выдало бы A0 игроку,
    // ответившему на B1.
    final launched = await ref.read(launchedTiersProvider.future);
    // Пустой набор означает сборку, в которой не запущено ничего. Играть по
    // ней нельзя вовсе, и щедрость тут была бы не милосердием, а
    // невычитанным текстом: ярус остаётся нижним.
    final ceiling = launched.isEmpty
        ? Tier.a0
        : launched.reduce((a, b) => a.index >= b.index ? a : b);

    state = CalibrationUiState(
      calibration: CalibrationState.start(ceiling: ceiling),
      loading: true,
    );
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
  /// исключения на калибровке и не нужен — тест мерит, а потом засевает то,
  /// из чего исключение заработает на первом же уровне игры.
  ///
  /// Одна и та же фраза дважды за тест не выпадает: спрошенное копится в
  /// [_asked] и из жеребьёвки уходит. Отобранных фраз на ярус тридцать, а
  /// квота яруса — от двух до шести кругов плюс переспросы — без этого повтор
  /// был бы правилом, а не случайностью.
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
        .where((id) => !_asked.contains(id))
        .where((id) => onTier.any((p) => p.id == id))
        .toList();

    // Три ступени, и порядок в них не случаен. Отобранный набор идёт первым:
    // решение о ярусе не должно зависеть от жеребьёвки. Кончился набор
    // (засев на одном ярусе способен выбрать его целиком) — берётся ярус
    // целиком, но по-прежнему без повторов. И только если непоказанного не
    // осталось вовсе, повтор разрешается: остановить онбординг из-за
    // нехватки контента хуже, чем спросить фразу дважды.
    final fresh = [
      for (final row in onTier)
        if (!_asked.contains(row.id)) row.id,
    ];
    final pick = curated.isNotEmpty
        ? curated
        : fresh.isNotEmpty
            ? fresh
            : [for (final row in onTier) row.id];
    final itemId = pick[_random.nextInt(pick.length)];
    _asked.add(itemId);

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
  /// Узнанные фразы стартуют с 50–60 lm и сразу попадают в очередь
  /// повторений. Игрок видит небо, где часть звёзд уже горит, планировщик с
  /// первого дня работает с реальным словарём человека, — а главное, у
  /// знакомства исключением появляется, из чего исключать
  /// ([CalibrationBalance.seedLmMin]).
  ///
  /// Сколько именно засевается — вопрос квоты, а не этого метода: на сборке с
  /// одним запущенным A0 засеять можно только верно отвеченное на A0, то есть
  /// не больше шести фраз. Знакомству нужно пять
  /// ([ScoreBalance.optionsPerCircle] минус верный ответ), и запас измерен:
  /// в среднем 5,5 засеянных у игрока, который A0 знает, — см.
  /// `calibration_diagnostic_test.dart`.
  Future<void> _finish(CalibrationState calibration) async {
    // Оба яруса приходят из состояния, и потолок в нём стоял ещё до первого
    // круга. Прежде зажим жил здесь, в трёх строчках поверх
    // `launchedTiersProvider`, не проверялся ничем и не срабатывал вовсе:
    // провайдер до чтения метаданных отдавал все ярусы, а первым его
    // читателем была та самая строка зажима.
    final measured = calibration.result ?? Tier.a0;
    final tier = calibration.granted ?? Tier.a0;

    // Засевается только выданный ярус и ниже.
    //
    // План нарочно спрашивает выше того, что игрок получит, — иначе замерять
    // было бы нечего, — и узнанное там честно попадает в счёт
    // «сколько фраз вы узнали». Но звезда на закрытом ярусе не светит нигде:
    // игрок туда не попадёт, планировщик её не выдаст, и запись о ней
    // означала бы только одно — что экран итога считает её горящей. Он это и
    // обещал: «5 слів із тесту вже світять на вашому небі», при том, что
    // светила одна.
    final seedable = {
      for (final entry in _confirmed.entries)
        if (entry.value.index <= tier.index) entry.key: entry.value,
    };

    var seeded = 0;
    try {
      await ref.read(wordStateRepositoryProvider).seed(
            confirmed: seedable,
            lumens: (CalibrationBalance.seedLmMin +
                    CalibrationBalance.seedLmMax) ~/
                2,
            now: DateTime.now(),
          );
      seeded = seedable.length;
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
      // Показанные круги, а не зачётные: длина теста — обещание игроку, и
      // мерить его выполнение надо тем же, что видит игрок.
      'circles': calibration.circles,
      'recognised': _confirmed.length,
      'seeded': seeded,
    });

    state = CalibrationUiState(
      calibration: calibration,
      granted: tier,
      seeded: seeded,
      recognised: _confirmed.length,
    );
  }
}

final calibrationControllerProvider =
    NotifierProvider<CalibrationController, CalibrationUiState>(
  CalibrationController.new,
);
