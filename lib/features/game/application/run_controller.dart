import 'dart:async';

// Из Flutter нужны ровно две вещи, и обе про жизненный цикл: слушатель и его
// состояния. `show` держит границу слоя — забег остаётся состоянием, а не
// виджетом, и случайно затащить сюда дерево нельзя.
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/audio/speech_service.dart';
import '../../../domain/entities/circle_question.dart';
// `balance.dart` отсюда ушёл, и это не уборка импортов, а следствие: числа
// темпа круга забег больше не читает сам. Длину окна даёт вопрос
// ([CircleQuestion.answerWindow]), а паузы после ответа нет вовсе — её
// закрывает игрок кнопкой (см. [RunController.next]).
import '../../../domain/scheduler/level_stage.dart';
import '../../../domain/scoring/climb.dart';
import '../../../domain/scoring/score.dart';
import '../../../data/repositories/word_state_repository.dart';

/// Что показывает экран забега прямо сейчас.
enum RunPhase {
  /// Круг открыт, ждём ответа.
  asking,

  /// Ответ принят: подсветка и озвучка. Следующий круг открывает игрок
  /// кнопкой «Дальше» — сам собой он больше не разворачивается.
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
    this.window,
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
        goal = null,
        window = null;

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

  /// Окно на ответ, открытое **прямо сейчас**; `null` — окна нет.
  ///
  /// Это то самое значение, которым заведён таймер забега, и лежит оно в
  /// состоянии затем, чтобы полоса окна над ареной брала длину отсюда. Прежде
  /// полоса завела свою анимацию на `ScoreBalance.answerWindow`, а таймер —
  /// свой `Timer` на то же число: совпадали они случайно и разошлись бы от
  /// любой правки. Теперь длину считает один геттер
  /// ([CircleQuestion.answerWindow]), заводит таймер один метод, и полоса
  /// показывает его, а не себя.
  ///
  /// `null` бывает по четырём причинам, и во всех четырёх полосы нет тоже:
  /// знакомство (торопить нельзя), пауза после ответа (отвечать уже нечего),
  /// круг на слух, пока фраза звучит (отвечать ещё нечего), и приложение не на
  /// экране (забег замер целиком).
  final Duration? window;

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
    Duration? Function()? window,
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
        window: window == null ? this.window : window(),
      );
}

/// Забег: 10–14 кругов подряд, темп которых задаёт игрок.
///
/// Четыре вещи, которые здесь важнее всего:
///
/// 1. **Звук не блокирует переход.** Озвучка запускается и тут же
///    забывается — следующий круг разворачивается поверх неё. Единственное
///    исключение — центр круга на слух: его окно ждёт тишины, потому что до
///    неё отвечать не на что ([_beginCircle]).
/// 2. **Запись в базу тоже не блокирует.** FSRS-обновление уходит в фон:
///    игрок не должен ждать диск между кругами.
/// 3. **Ошибка не блокирует.** Слово возвращается в конец очереди и теряет
///    яркость, но забег продолжается. Жизней в игре нет.
/// 4. **Забег не идёт без игрока.** Ни один таймер круга не бежит, пока
///    приложения нет на экране, и время вне экрана забегу не принадлежит
///    ([leaveScreen]).
class RunController extends Notifier<RunState> {
  /// Окно на ответ. `null` — окна нет: знакомство, пауза, звучащий центр или
  /// приложение вне экрана.
  Timer? _windowTimer;

  /// Кто сообщает, что приложение ушло с экрана и вернулось.
  ///
  /// Слушатель живёт в контроллере, а не в виджете, и это не вкус.
  /// `AppLifecycleListener` виджета не требует, а таймеры круга живут здесь —
  /// значит здесь и место тому, кто их останавливает. Посредник-виджет добавил
  /// бы третье место, в котором забег способен оказаться живым, пока игрок на
  /// него не смотрит: экран сняли с дерева, а таймер тикает.
  AppLifecycleListener? _lifecycle;

  /// Приложение на экране. Пока `false`, забег не заводит ни таймеров, ни
  /// озвучки.
  bool _onScreen = true;

  /// Когда ушли с экрана — чтобы вернуть забегу его срок.
  DateTime? _leftAt;

  @override
  RunState build() {
    _lifecycle = AppLifecycleListener(onStateChange: _screenChanged);
    ref.onDispose(() {
      _windowTimer?.cancel();
      _lifecycle?.dispose();
      _lifecycle = null;
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
    _windowTimer?.cancel();
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
    _beginCircle();
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

  // ── Темп круга ───────────────────────────────────────────────────────────

  /// Открывает круг: озвучка центра и окно на ответ.
  ///
  /// Порядок здесь и есть починка «на ответ дают две секунды вместо пяти».
  /// Прежде в этом месте подряд стояли `_speakPrompt()` и `_openWindow()`, и на
  /// круге со слухом часы начинали тикать вместе с озвучкой. Фраза существует
  /// там только как звук: пока она произносится — две-три секунды на
  /// предложение, — отвечать физически не на что, и от пяти секунд игроку
  /// оставалось две. Просрочка при этом считается «не вспомнил».
  ///
  /// Поэтому у текстового центра окно открывается сразу (отвечать можно с
  /// первого кадра), а у звучащего — по сигналу окончания озвучки.
  ///
  /// Первое проигрывание делает игра, а не игрок: без этого механика на слух
  /// начиналась тишиной — игрок видел динамик и должен был сообразить, что по
  /// нему надо нажать, хотя задание в том, чтобы узнать фразу, а не догадаться,
  /// как её услышать. И это же держит скоростной множитель: «переслушал» ставит
  /// только [replayPrompt], то есть повторное нажатие.
  void _beginCircle() {
    // Вне экрана круг не открывается вовсе: ни звука, ни отсчёта.
    if (!_onScreen) return;
    _preloadNext();
    final prompt = state.current?.promptSpeech;
    if (prompt == null) {
      _openWindow();
      return;
    }
    unawaited(_speakThenOpen(prompt));
  }

  /// Произносит центр и открывает окно, когда он дозвучал.
  ///
  /// Круг за это время мог кончиться: игрок ответил, ушёл с экрана или забег
  /// закрылся по сроку. Тогда окно открывать некуда, и проверяется это по
  /// **тому же объекту** вопроса: два круга по одной фразе — два разных
  /// вопроса, и окно второго не должно заводиться озвучкой первого.
  ///
  /// Ждать бесконечно нельзя, и этого не случится: у сервиса на одно
  /// произнесение стоит потолок (`DeviceSpeechService._speakCeiling`), а
  /// молчащее устройство отвечает сигналом сразу. Иначе круг со слухом на
  /// телефоне без голоса не открыл бы окно никогда — то есть повис бы.
  Future<void> _speakThenOpen(String text) async {
    final circle = state.current;
    await ref.read(speechServiceProvider).speakAndWait(text);
    if (!_onScreen ||
        state.phase != RunPhase.asking ||
        !identical(state.current, circle)) {
      return;
    }
    _openWindow();
  }

  /// Открывает окно на ответ: столько времени, сколько просит текст круга.
  ///
  /// Длину даёт [CircleQuestion.answerWindow] — там же, где записано и правило
  /// «на знакомстве окна нет». Здесь оно больше не повторяется: пока условие
  /// `question.isNew` жило и тут, у правила было две согласные копии, а копия,
  /// которую никто не сверяет, однажды перестаёт быть копией. Ровно так арена
  /// и разошлась с забегом в онбординге.
  void _openWindow() {
    _windowTimer?.cancel();
    final window = state.current?.answerWindow;
    if (window == null) {
      _showWindow(null);
      return;
    }
    // Таймер знает свою длину: она же уходит в журнал как время ответа, и
    // спрашивать её потом заново было бы вторым источником одного числа.
    _windowTimer = Timer(window, () => _expireWindow(window));
    _showWindow(window);
  }

  /// Снимает окно: ответ дан, круг ушёл или игрок ушёл с экрана.
  void _closeWindow() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _showWindow(null);
  }

  /// Единственное место, которое пишет [RunState.window]: полоса окна и таймер
  /// обязаны появляться и исчезать вместе.
  void _showWindow(Duration? window) {
    if (state.window == window) return;
    state = state.copyWith(window: () => window);
  }

  /// Время вышло: круг закрывается неверным ответом.
  ///
  /// Просрочка — это «не вспомнил», а не отдельный третий исход. Слово
  /// тускнеет и возвращается в очередь ровно так же, как после промаха:
  /// не успел значит не вспомнил. Отличие одно — верный вариант при этом
  /// **произносится**, потому что промолчавшему игроку его никто не назвал.
  void _expireWindow(Duration window) {
    final question = state.current;
    if (question == null || state.phase != RunPhase.asking) return;
    // В журнал уходит длина окна: игрок думал ровно столько, сколько ему
    // дали, и запись об этом не должна выглядеть мгновенным ответом.
    _submit(question, false, window, expired: true);
  }

  void _submit(
    CircleQuestion question,
    bool correct,
    Duration latency, {
    bool expired = false,
  }) {
    _closeWindow();

    final result = _run.apply(
      correct: correct,
      latency: latency,
      mode: question.mode,
      lumens: question.lumens,
      replayed: _replayed,
    );

    // Каждое верное соединение озвучивается — во всех режимах, а не только
    // в «Слухе». Играет поверх анимации, не задерживая показ.
    final speech = ref.read(speechServiceProvider);
    if ((correct || expired) && question.answerSpeech != null) {
      // По просрочке звучит верный вариант, и это не поблажка: игрок ничего
      // не выбрал, значит ему не сказали ответ ни выбором, ни подсветкой
      // выбранного.
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
  }

  /// Следующий круг — по кнопке «Дальше» или нажатием по арене.
  ///
  /// **Автоперехода больше нет**, и вместе с ним ушли `_advanceTimer` и
  /// `_revealDuration`. Что они охраняли: круг стоял открытым 420 мс после
  /// верного ответа и 1100 мс после промаха, и разница была нужна затем, чтобы
  /// игрок успел увидеть и услышать верный вариант — иначе промах ничему не
  /// учит. Правило живо, но исполняет его теперь сам игрок: круг стоит
  /// открытым, пока он не нажмёт, и ровно столько, сколько ему нужно. Числа
  /// для этого не требуется ни одного (они остались у калибровки, где кнопки
  /// нет, — см. `RevealBalance`).
  ///
  /// Второе, что держал автопереход, — забег в фоне. Истёкшее окно вызывало
  /// переход, переход произносил вопрос нового круга и открывал новое окно, и
  /// так по кругу без игрока: за минуту в закрытом окне отыгрывалось десять
  /// кругов, каждый просрочкой «не вспомнил» (см. [leaveScreen]).
  ///
  /// Способ этот был досрочным (`skipReveal` — «пропустить паузу») и стал
  /// основным. Нажатие по арене оставлено: у него та же цена, что у кнопки, и
  /// отбирать привычное движение ради единственности пути незачем.
  ///
  /// **У спринта кнопка та же.** Часы там идут независимо от игрока — срок
  /// поставлен в момент старта и в связях не считается, — поэтому промедление
  /// между кругами тратит его собственное время: кнопка спринтера не спасает,
  /// но и не обманывает. Автопереход только для спринта означал бы два разных
  /// правила темпа на одном экране и одну лишнюю ветку в состоянии, а спасти
  /// он всё равно не может.
  void next() {
    if (state.phase != RunPhase.revealing) return;
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
    _beginCircle();
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

  /// Проигрывает центр заново по нажатию на динамик.
  ///
  /// Переслушивание разрешено, но снимает скоростной множитель — иначе
  /// «Слух» превращался бы в «Круг» с лишним тапом.
  ///
  /// Окно при этом **перезапускается**: на время повтора его нет вовсе (пока
  /// фраза звучит, отвечать не на что), а после — заводится с полного времени.
  /// Часы, идущие сквозь повтор, были бы платой за чужую медлительность:
  /// игрок попросил повторить, а не отказался от половины своего окна. Цену
  /// переслушивания берёт скоростной множитель, а не отобранные секунды.
  void replayPrompt() {
    final text = state.current?.promptSpeech;
    if (text == null || state.phase != RunPhase.asking) return;
    _replayed = true;
    _closeWindow();
    unawaited(_speakThenOpen(text));
  }

  /// Переслушивал ли игрок центр на текущем круге.
  ///
  /// Сбрасывается при переходе к следующему кругу, а не при ответе: между
  /// ответом и переходом круг заморожен, и нажать динамик всё равно нельзя.
  bool _replayed = false;

  // ── Экран и фон ──────────────────────────────────────────────────────────

  void _screenChanged(AppLifecycleState state) {
    // На экране — только `resumed`. Всё остальное, включая `inactive`
    // (входящий звонок, шторка уведомлений, окно без фокуса на десктопе), —
    // это «игрок не смотрит»: ответить он не может, а значит и торопить его
    // нельзя.
    if (state == AppLifecycleState.resumed) {
      returnToScreen();
    } else {
      leaveScreen();
    }
  }

  /// Приложение ушло с экрана: забег замирает целиком.
  ///
  /// Что было без этого — жалоба владельца дословно: «когда я закрыл окно с
  /// игрой — она продолжает работать в фоне — я слышу текст». Игра не
  /// доигрывала звук, она **продолжала играть сама**: окно ответа истекало по
  /// таймеру, просрочка уходила в память ответом «не вспомнил», звучал верный
  /// вариант, срабатывал автопереход, новый круг произносил свой вопрос и
  /// открывал новое окно. Игрок слышал не остаток фразы, а забег, который шёл
  /// без него и тратил его звёзды: каждая просрочка роняла яркость и
  /// отправляла фразу в конец очереди.
  ///
  /// Останавливаются здесь **таймеры**, потому что они принадлежат забегу.
  /// Голос принадлежит приложению — он один на забег и калибровку, — и молчит
  /// он по сигналу из корня (`SilenceOffScreen` в `main.dart`).
  void leaveScreen() {
    if (!_onScreen) return;
    _onScreen = false;
    _leftAt = DateTime.now();
    _closeWindow();
  }

  /// Приложение вернулось: круг открывается заново, а не с остатка.
  ///
  /// С остатка было бы наказанием за то, чего игрок не видел: ни фразы, ни
  /// полосы, ни того, сколько времени уже съедено. Поэтому окно открывается с
  /// полного времени, а круг на слух заново произносит центр — и это не
  /// считается переслушиванием: звук отобрала игра, а не игрок попросил
  /// повторить.
  ///
  /// Срок забега сдвигается на время отсутствия. Время вне экрана забегу не
  /// принадлежит — ни его срок, ни его длительность, — иначе спринт, чьи часы
  /// идут независимо от игрока, умирал бы от входящего звонка, а Восход
  /// заканчивался бы, ни разу не показав круг.
  void returnToScreen() {
    if (_onScreen) return;
    _onScreen = true;
    final left = _leftAt;
    if (left != null) {
      final away = DateTime.now().difference(left);
      _deadline = _deadline?.add(away);
      _startedAt = _startedAt.add(away);
    }
    _leftAt = null;
    if (state.phase == RunPhase.asking) _beginCircle();
  }

  void _finish() {
    _closeWindow();
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
