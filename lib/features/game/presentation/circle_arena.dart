import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/scoring/balance.dart';
import 'prompt_tag_text.dart';

/// Что произошло с кругом после ответа.
enum CircleOutcome { correct, wrong }

// ── Пределы раскладки ──────────────────────────────────────────────────────
//
// Все они про читаемость и палец, а не про геймдизайн: в `balance.dart` им
// делать нечего — там числа, которые подстраивают на живых игроках, а не те,
// которые меряются шрифтом.

/// Кегль варианта, ниже которого не опускаемся ни при каком содержимом.
///
/// Читаемость важнее вместимости. Если шесть длинных фраз не влезают, круг
/// растит капсулы в высоту и тратит воздух между полосами — но не размер
/// букв: фраза, которую не прочесть, не задание, а помеха.
///
/// Замерено на худшем случае корпуса 1500 фраз: шесть самых длинных немецких
/// (до 118 знаков — прежний максимум был 90) плюс украинский перевод в 97
/// знаков в центре. На телефоне 360dp — арена 324×546 — этот случай
/// укладывается ровно полом, а на аренах меньше места не хватает уже ему.
///
/// **Ниже пола не опускаемся, но и не обрезаем.** Здесь стояло «что не
/// влезло, обрежется, и это осознанный выбор в пользу тех строк, которые
/// прочесть всё-таки можно» — выбор оказался не тем. За низ арены уезжала не
/// строка, а капсула целиком, а `Stack` клипует и hit-test за свои границы не
/// пускает: вариант не подрезался, он **перестал нажиматься**. Достанься
/// нижней полосе верный ответ — круг непроходим, и игрок не понимает, почему
/// его нажатия не считаются. Поэтому пол остался, а на его месте появились
/// два хода: смена кладки ([_ArenaLayout._bands]) и единый масштаб всей арены
/// ([_plan]).
const double _minOptionFont = 13;

/// То же для центральной фразы. Она — само задание, и мельче варианта быть не
/// должна.
const double _minPromptFont = 16;

/// Минимальная высота капсулы. Считается от пальца, а не от текста: строчка
/// в 15 точек попадает в капсулу высотой 29, и целиться в неё на ходу нельзя.
///
/// Под уменьшенной картинкой ([_plan]) она уменьшается вместе со всем
/// остальным, и это сознательно: маленькая, но нажимаемая капсула лучше
/// капсулы пальцевого размера, до которой не доходит нажатие.
const double _minCapsuleHeight = 44;

/// Зазор между полосами, когда места впритык.
const double _minBandGap = 8;

/// Отступ полос от края арены — со всех четырёх сторон.
///
/// Сверху он не косметический: там же идёт полоса окна ответа, и капсула,
/// поставленная в ноль, оказывается под ней.
const double _arenaEdge = 6;

/// Зазор между левым и правым вариантом одной полосы.
const double _columnGap = 10;

/// Внутренние поля капсулы: между рамкой и текстом.
const EdgeInsets _capsulePad = EdgeInsets.symmetric(horizontal: 10, vertical: 7);

/// Расстояние от центральной фразы до пометки под ней.
const double _hintGap = 6;

/// Насколько щедро зона попадания шире капсулы. Палец толще курсора, и промах
/// по варианту читается игроком как своя ошибка, хотя это ошибка интерфейса.
const double _touchSlack = 12;

/// Предел скругления капсулы.
///
/// Пока фраза в одну строку, капсула — пилюля: радиус в половину высоты. С
/// ростом числа строк то же правило превратило бы её в овал, у которого углы
/// съедают начало и конец каждой строки, — а текст в капсуле прямоугольный.
const double _maxCorner = 26;

/// К какой высоте стремится кольцо вариантов: доля от ширины арены.
///
/// Нужно затем, чтобы на коротких фразах (A0 — до 33 знаков) шесть мелких
/// капсул не расползлись по всей высоте экрана в шесть полосок, а собрались в
/// узнаваемое кольцо. Когда содержимому нужно больше — кольцо растёт до
/// высоты арены, и воздух кончается раньше, чем кегль.
const double _ringAspect = 1.15;

/// Круг: в центре фраза или динамик, вокруг — шесть вариантов.
/// Игрок тянет пальцем от центра к нужному.
///
/// Вариантов всегда [ScoreBalance.optionsPerCircle]. Раскладка считает их
/// число из содержимого вопроса и уменьшать не имеет права: новое даётся
/// среди пяти уже известных, и убери одно — знакомство перестанет быть
/// исключением.
///
/// Основной глагол игры — **соединять**, поэтому ответ здесь не «тап по
/// кнопке», а протянутая линия: то же движение, которым соединяют звёзды в
/// созвездие. Тап тоже работает — на маленьком экране тянуть до дальнего
/// варианта неудобно, и запрещать это было бы вредностью.
class CircleArena extends StatefulWidget {
  const CircleArena({
    super.key,
    required this.question,
    required this.onAnswer,
    this.enabled = true,
    this.onReplay,
    this.answerWindow,
  });

  final CircleQuestion question;

  /// Индекс выбранного варианта и время от появления круга до отпускания.
  final void Function(int index, Duration latency) onAnswer;

  /// Сколько времени отсчитывает **хозяин** круга **прямо сейчас**. `null` —
  /// не отсчитывает никто.
  ///
  /// Полоса окна идёт ровно столько и не идёт вообще, если здесь `null`:
  /// решение «торопят или нет» арене не принадлежит. Она его принимала — по
  /// `!question.isNew`, — и разошлась с действительностью на первом же экране
  /// приложения. Круги калибровки приходят с `isNew: false`, потому что
  /// онбординг не знакомит, а мерит; таймера же в онбординге нет ни одного —
  /// `_expireWindow` живёт в забеге. Игрок двадцать раз смотрел, как полоса
  /// добегает до конца и краснеет, и ничего не происходило: это учит **не
  /// смотреть на полосу** ровно перед тем забегом, где она наказывает.
  ///
  /// Поэтому умолчание — «окна нет». Полоса без таймера обманывает; таймер без
  /// полосы всего лишь не предупреждает, и такой круг честнее.
  ///
  /// «Прямо сейчас» — не оговорка, а разница между длиной окна и открытым
  /// окном. Забег передаёт сюда то значение, которым **заведён его таймер**
  /// (`RunState.window`): у круга на слух окно открывается не в кадре
  /// появления, а когда фраза дозвучала, переслушивание заводит его заново, а
  /// уход приложения с экрана снимает вовсе. Спроси арена длину у вопроса —
  /// она получила бы правильное число и неправильное начало.
  final Duration? answerWindow;

  /// Круг заморожен: идёт анимация схлопывания или показывается результат.
  final bool enabled;

  /// Проиграть центр заново. Задан только в механиках на слух: там в центре
  /// динамик вместо текста, и нажатие на него — часть задания, а не помощь.
  final VoidCallback? onReplay;

  /// Ключ капсулы варианта и ключ центральной фразы.
  ///
  /// Единственная причина, по которой они здесь есть: раскладка обещает, что
  /// капсулы не пересекаются и текст в них не обрезан, а проверить это можно
  /// только по прямоугольникам того, что отрисовалось. Без ключей тест мерил
  /// бы абзацы — а капсулы способны налезть друг на друга и тогда, когда
  /// абзацы внутри них ещё не соприкоснулись.
  static ValueKey<String> optionKey(int index) =>
      ValueKey<String>('circle-option-$index');
  static const ValueKey<String> promptKey = ValueKey<String>('circle-prompt');

  @override
  State<CircleArena> createState() => _CircleArenaState();
}

class _CircleArenaState extends State<CircleArena>
    with TickerProviderStateMixin {
  /// Мгновение, с которого игрок **может отвечать** — от него отсчитывается
  /// время отклика.
  ///
  /// Обычно это появление круга, но не всегда: на круге со слухом отвечать не
  /// на что, пока звучит фраза, и хозяин заводит окно только после неё
  /// ([_restartWindow]). Считай отклик от появления — и две-три секунды
  /// озвучки уехали бы в задержку ответа: скоростной множитель терялся бы
  /// всегда, а FSRS получал бы «трудно» за ответ, данный мгновенно. Ровно та
  /// же ошибка, из-за которой окно на слух оказывалось вдвое короче
  /// обещанного.
  late DateTime _shownAt;

  /// Куда сейчас указывает палец, в координатах виджета.
  Offset? _pointer;

  /// Индекс варианта под пальцем.
  int? _hovered;

  /// Индекс выбранного варианта и чем всё кончилось — для подсветки.
  int? _chosen;
  CircleOutcome? _outcome;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  /// Окно на ответ: полоса, которая истекает вместе с отсчётом хозяина круга.
  ///
  /// Своя анимация, а не отсчёт из контроллера, и это осознанно: истина о
  /// том, когда круг закрылся, живёт в `RunController`, а здесь нужна только
  /// картинка. Совпадать они обязаны в двух вещах — начале и длине, — и обе
  /// приходят из одного места: полоса пускается тем кадром, в котором у
  /// хозяина **появилось** окно ([widget.answerWindow]), и длится ровно
  /// столько, сколько это окно, потому что число то же самое, которым заведён
  /// его таймер.
  ///
  /// Прежде здесь стояло «оба отсчёта начинаются в одном кадре — от появления
  /// круга»: полоса брала длину у вопроса, таймер — тоже у вопроса, и
  /// совпадение держалось на том, что круг открывается ровно в кадре
  /// появления. Как только окно перестало открываться в этом кадре (озвучка
  /// центра, переслушивание, возвращение с фона), совпадение кончилось бы
  /// молча.
  ///
  /// Длительность выставляется в [_restartWindow], а не здесь: полоса без
  /// заведённого окна не идёт вовсе, и постоянная длина была бы обещанием
  /// отсчёта, которого может не быть.
  late final AnimationController _window = AnimationController(vsync: this);

  /// Геометрия последней отрисовки вместе с её виртуальной ареной — по ней
  /// ищем вариант под пальцем.
  _ArenaLayout? _layout;

  /// Она же, но с ключом: от чего именно она зависит.
  ///
  /// Замер стоит семи `TextPainter` на кегль, подбор кегля — вчетверо больше,
  /// а выбор кладки и масштаба может повторить подбор до четырёх раз.
  /// Разворачивание круга перестраивает дерево шестьдесят раз в секунду, и
  /// мерить те же семь фраз заново на каждом кадре незачем: пока не сменились
  /// ни размер арены, ни фразы, ни шрифт, раскладка та же.
  _ArenaPlan? _cached;
  _LayoutKey? _cachedKey;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
    _restartWindow();
  }

  /// Запускает полосу окна, если хозяин круга её завёл.
  ///
  /// Условие ровно одно — есть ли отсчёт: полоса не решает, торопить ли
  /// игрока, она показывает чужой отсчёт. Замороженный круг ответов не
  /// принимает, поэтому и окна не тратит.
  ///
  /// Здесь же переставляется начало отсчёта отклика ([_shownAt]): открытое
  /// окно и есть то мгновение, с которого игрок может отвечать. У текстового
  /// круга это тот же кадр, в котором он появился, и ничего не меняется; у
  /// круга на слух — конец озвучки; у переслушанного — конец повтора. Держи
  /// арена своё «появился» отдельно, и один и тот же ответ считался бы быстрым
  /// по окну хозяина и медленным по её отсчёту.
  void _restartWindow() {
    _window.stop();
    final window = widget.answerWindow;
    if (window != null && widget.enabled) {
      _shownAt = DateTime.now();
      _window.duration = window;
      _window.forward(from: 0);
    } else {
      _window.value = 0;
    }
  }

  @override
  void didUpdateWidget(CircleArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      // Новый круг: сбрасываем всё, включая отсчёт времени отклика.
      _shownAt = DateTime.now();
      _pointer = null;
      _hovered = null;
      _chosen = null;
      _outcome = null;
      _reveal.forward(from: 0);
      _restartWindow();
    } else if (oldWidget.answerWindow != widget.answerWindow) {
      // Отсчёт на том же круге появился или пропал. Полоса идёт за ним, а не
      // за собой: иначе она способна доигрывать окно, которое уже отменили.
      _restartWindow();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _window.dispose();
    super.dispose();
  }

  void _onPanUpdate(Offset local) {
    if (!widget.enabled) return;
    setState(() {
      _pointer = local;
      _hovered = _layout?.hitTest(local);
    });
  }

  void _onPanEnd() {
    final index = _hovered;
    setState(() {
      _pointer = null;
      _hovered = null;
    });
    if (index != null) _answer(index);
  }

  void _answer(int index) {
    if (!widget.enabled || _chosen != null) return;
    final latency = DateTime.now().difference(_shownAt);
    _window.stop();
    setState(() {
      _chosen = index;
      _outcome = widget.question.isCorrectOption(index)
          ? CircleOutcome.correct
          : CircleOutcome.wrong;
    });
    widget.onAnswer(index, latency);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final theme = Theme.of(context);

    // Пометка под центром — одна строка, сегодня это регистр фразы.
    //
    // Локализация запрашивается только когда есть что переводить: круг без
    // пометки не должен требовать её наличия в дереве.
    final hint = question.promptTag == null
        ? ''
        : promptTagText(AppLocalizations.of(context), question.promptTag) ?? '';

    // Стили берутся ровно те, которыми `Text` и отрисует: раскладка мерит
    // текст сама, и разойдись замер с отрисовкой хотя бы в межбуквенном
    // интервале — капсула окажется на строку короче, чем нужно. Отсюда и
    // `DefaultTextStyle`: `Text` сливает стиль с окружающим, и мерить надо
    // результат этого слияния, а не тему.
    final ambient = DefaultTextStyle.of(context).style;
    final optionBase = ambient.merge(theme.textTheme.titleMedium);
    final promptBase = ambient.merge(theme.textTheme.titleLarge);
    final tagBase = ambient.merge(theme.textTheme.bodySmall);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final plan = _planFor(
          (
            size: Size(constraints.maxWidth, constraints.maxHeight),
            question: question,
            hint: hint,
            audio: widget.onReplay != null,
            option: optionBase,
            prompt: promptBase,
            tag: tagBase,
            direction: direction,
            scaler: scaler,
          ),
        );
        final layout = plan.layout;
        _layout = layout;

        return Stack(
          children: [
            // Круг рисуется в своей арене и вписывается в настоящую.
            //
            // Пока содержимое влезает, виртуальная арена равна настоящей и
            // `FittedBox` ничего не делает (`plan.scale` == 1). Когда не
            // влезает — геометрия считается для арены пошире, а картинка
            // уменьшается целиком. Уменьшает её именно `FittedBox`, а не
            // арифметика в раскладке, и это главное: жест и тап проходят
            // через то же преобразование, которым нарисована картинка,
            // поэтому попадание не может разойтись с видимым. Своя же
            // арифметика разошлась бы — считать масштаб пришлось бы дважды,
            // в отрисовке и в `hitTest`.
            Positioned.fill(
              child: FittedBox(
                // Целиком и без обрезки: масштаб один на оба измерения,
                // поэтому круг не растягивается в овал.
                fit: BoxFit.contain,
                child: SizedBox.fromSize(
                  size: plan.box,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _onPanUpdate(d.localPosition),
                    onPanUpdate: (d) => _onPanUpdate(d.localPosition),
                    onPanEnd: (_) => _onPanEnd(),
                    onPanCancel: _onPanEnd,
                    child: Stack(
                      children: [
                        // Разворачивание живёт только на канве, и это не лень.
                        //
                        // Место капсулы — часть раскладки, а не картинки: по
                        // нему ищется вариант под пальцем и по нему же тап
                        // попадает в надпись. Сдвинь его на кадр анимации — и
                        // первый кадр круга окажется кругом, в котором все
                        // шесть вариантов лежат в центре друг на друге и не
                        // нажимается ни один. Поэтому вылетают из центра
                        // рамки, а надписи стоят на местах сразу: ровно так
                        // это и работало, когда варианты были звёздами.
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _reveal,
                            builder: (context, _) => CustomPaint(
                              painter: _ArenaPainter(
                                layout: layout,
                                pointer: _pointer,
                                accents: [
                                  for (var i = 0;
                                      i < question.options.length;
                                      i++)
                                    _accent(context, i),
                                ],
                                reveal: Curves.easeOutBack.transform(
                                  _reveal.value.clamp(0, 1).toDouble(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ..._buildCenter(context, layout, hint),
                        for (var i = 0; i < question.options.length; i++)
                          _buildOption(context, layout, i),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Полоса окна — поверх вписанной картинки и не в ней: тонкая
            // черта, уменьшенная вместе с кругом, читалась бы как царапина, а
            // сообщать ей надо о времени. Отступ [_arenaEdge] сверху оставлен
            // капсулам ровно под неё.
            if (widget.answerWindow != null) _buildWindowBar(),
          ],
        );
      },
    );
  }

  /// Раскладка и её арена для этих условий: из памяти, если условия те же.
  _ArenaPlan _planFor(_LayoutKey key) {
    final cached = _cached;
    if (cached != null && _cachedKey == key) return cached;
    final plan = _plan(key);
    _cached = plan;
    _cachedKey = key;
    return plan;
  }

  /// Полоса окна поверх арены.
  ///
  /// Сверху и тонкая: она нужна краем глаза. Круг — главное на экране, и
  /// таймер, который на себя смотрит, отбирает у него внимание ровно тогда,
  /// когда игрок должен читать варианты.
  Widget _buildWindowBar() => Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: AnimatedBuilder(
          animation: _window,
          builder: (context, _) => LinearProgressIndicator(
            value: 1 - _window.value,
            minHeight: 3,
            backgroundColor: Colors.transparent,
            color: _window.value > 0.75
                ? LumenPalette.wrong
                : LumenPalette.starlight,
          ),
        ),
      );

  /// Центр круга: фраза с пометкой или динамик.
  ///
  /// Центр не разворачивается вместе с вариантами — он и есть та точка, из
  /// которой они вылетают.
  List<Widget> _buildCenter(
    BuildContext context,
    _ArenaLayout layout,
    String hint,
  ) {
    final theme = Theme.of(context);
    final replay = widget.onReplay;

    // В механиках на слух в центре нет текста — только динамик. Показать
    // здесь фразу значило бы отдать ответ: задание в том, чтобы узнать её на
    // слух.
    if (replay != null) {
      return [
        Positioned.fromRect(
          rect: layout.core,
          child: Center(
            child: IconButton.filledTonal(
              iconSize: layout.core.shortestSide * 0.5,
              onPressed: widget.enabled ? replay : null,
              icon: const Icon(Icons.volume_up),
              tooltip: AppLocalizations.of(context).audioReplay,
            ),
          ),
        ),
      ];
    }

    return [
      Positioned.fromRect(
        rect: layout.promptRect,
        child: Text(
          widget.question.prompt,
          key: CircleArena.promptKey,
          textAlign: TextAlign.center,
          style: layout.promptStyle.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
      if (!layout.hintRect.isEmpty)
        Positioned.fromRect(
          rect: layout.hintRect,
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: layout.hintStyle
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
    ];
  }

  /// Подсветка варианта: цвет надписи, цвет рамки и сила свечения.
  ///
  /// Одно место на два потребителя — надпись рисует виджет, рамку канва.
  /// Раньше правило «горит верный, горит выбранный» было выписано в обоих, и
  /// расхождение между ними ничем не проверялось: тест читает цвет надписи, а
  /// игрок смотрит на свечение.
  _Accent _accent(BuildContext context, int index) {
    final isChosen = _chosen == index;
    final isAnswer = widget.question.answerIndex == index;

    // Верный вариант подсвечивается и тогда, когда игрок выбрал другой:
    // ошибка должна учить, а не просто отнимать очки.
    if (_outcome != null && isAnswer) {
      return (text: LumenPalette.correct, line: LumenPalette.correct, glow: 0.9);
    }
    if (isChosen && _outcome == CircleOutcome.wrong) {
      return (text: LumenPalette.wrong, line: LumenPalette.wrong, glow: 0.8);
    }
    if (_hovered == index) {
      return (
        text: LumenPalette.starlight,
        line: LumenPalette.starlight,
        glow: 0.7,
      );
    }
    // Надпись читается всегда, даже когда рамка едва видна: приглушать её
    // вместе с рамкой значит сделать невыбранные варианты хуже читаемыми, чем
    // выбранный, — а прочитать нужно все шесть.
    return (
      text: Theme.of(context).colorScheme.onSurface,
      line: LumenPalette.constellationLine,
      glow: 0.35,
    );
  }

  /// Один вариант: надпись в капсуле. Рамку капсулы рисует канва — она
  /// участвует в разворачивании, а надпись стоит на месте с первого кадра.
  Widget _buildOption(BuildContext context, _ArenaLayout layout, int index) {
    final capsule = layout.capsules[index];
    final target = layout.targets[index];

    return Positioned.fromRect(
      rect: target,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _answer(index),
        child: Padding(
          // Зона попадания шире капсулы, и разница уходит в этот отступ:
          // нажимается вся зона, рисуется только капсула.
          padding: EdgeInsets.fromLTRB(
            capsule.left - target.left,
            capsule.top - target.top,
            target.right - capsule.right,
            target.bottom - capsule.bottom,
          ),
          // Ключ — на самой капсуле: её прямоугольник и есть то, что обещает
          // раскладка и что мерит тест.
          child: Padding(
            key: CircleArena.optionKey(index),
            padding: _capsulePad,
            child: Center(
              child: Text(
                widget.question.options[index],
                textAlign: TextAlign.center,
                style: layout.optionStyle
                    .copyWith(color: _accent(context, index).text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Подсветка одного варианта.
typedef _Accent = ({Color text, Color line, double glow});

/// От чего зависит раскладка. Всё, что здесь есть, меняет замер текста; всё,
/// чего здесь нет, — только цвета.
typedef _LayoutKey = ({
  Size size,
  CircleQuestion question,
  String hint,
  bool audio,
  TextStyle option,
  TextStyle prompt,
  TextStyle tag,
  TextDirection direction,
  TextScaler scaler,
});

/// Полоса вариантов: её место по вертикали и индексы слева направо.
typedef _Band = ({double row, List<int> ids});

/// Что круг решил про свою арену: геометрия, арена, для которой она посчитана,
/// и во сколько раз картинку уменьшают при отрисовке.
///
/// [box] равна настоящей арене, пока содержимое влезает, и больше настоящей,
/// когда влезать перестало. [scale] — производная величина (`настоящая /
/// [box]`), и уменьшает картинку по ней не эта запись, а `FittedBox`: нужна
/// она только затем, чтобы сравнить две кладки между собой по тому, каким
/// кегль выйдет **на экране**.
typedef _ArenaPlan = ({_ArenaLayout layout, Size box, double scale});

/// Выбирает кладку и арену, в которой круг помещается целиком.
///
/// Раскладка обязана влезать при любом размере арены. Прежняя не умела не
/// влезать: подбор кегля выходил по достижении предела читаемости, ничего не
/// проверив, и полосы дальше уезжали за низ арены — а уехавшая капсула не
/// подрезается, она перестаёт нажиматься (`Stack` клипует, hit-test за
/// границы не идёт). На арене 284×386 — телефон 320×480 — так пропадали три
/// варианта из шести, на лежащем 604×266 один.
///
/// Порядок попыток идёт от того, что игрок узнаёт, к тому, что он терпит:
///
/// 1. **Привычная кладка в настоящую арену.** Влезла — на этом всё. Ни на
///    одном экране, где круг работал (телефон 360dp и всё, что больше), не
///    меняется ничего.
/// 2. **Широкая кладка.** Шесть углов складываются в полосы, и насколько
///    крупно — решает нужда, а не форма экрана: 1+2+2+1 превращается в 3+3,
///    полос становится две вместо четырёх, и высоты нужно почти вдвое меньше.
///    Метафора цела — центр и шесть вокруг, угол по индексу тот же (см.
///    [_ArenaLayout._bands]).
/// 3. **Единый масштаб.** Не влезло ничто — геометрия считается для арены
///    пошире, а картинка уменьшается целиком. Это и есть «честно уменьшить
///    всё вместе»: зазоры, поперечник, кегль и зона попадания уходят вниз
///    одним множителем, и ни одна фраза не обрезана. Уменьшать один кегль в
///    подборе по-прежнему запрещено ([_minOptionFont]) — читаемость важнее
///    вместимости; но когда выбор стоит между мелким кругом и кругом, часть
///    которого не нажимается, мелкий круг — единственный честный ответ.
_ArenaPlan _plan(_LayoutKey key) {
  final real = key.size;

  _ArenaPlan attempt({required bool wide}) {
    var box = real;
    var layout = _ArenaLayout.of(key, box: box, wide: wide);
    // Пересчёт нужен затем, чтобы не уменьшить круг сильнее, чем требуется: в
    // арене пошире фраза занимает меньше строк, и высота, посчитанная в
    // тесной, взялась бы с запасом.
    //
    // Одного пересчёта достаточно: не влезло — значит кегль уже на полу, а на
    // полу высота содержимого зависит только от ширины полосы и с ростом арены
    // не растёт. Проходов всё же три, и не про запас: сторона центра-динамика
    // считается от арены ([_audioSide]) и с её ростом как раз растёт — пока не
    // упрётся в свой предел.
    for (var pass = 0; pass < 3 && layout.need > box.height; pass++) {
      box = box * (layout.need / box.height);
      layout = _ArenaLayout.of(key, box: box, wide: wide);
    }
    return (layout: layout, box: box, scale: real.height / box.height);
  }

  final classic = attempt(wide: false);
  if (classic.scale >= 1) return classic;

  // Сравниваем то, что увидит глаз: кегль после уменьшения картинки. Мерить
  // логический было бы самообманом — именно он и остаётся на полу.
  final packed = attempt(wide: true);
  double rendered(_ArenaPlan plan) =>
      (plan.layout.optionStyle.fontSize ?? 0) * plan.scale;
  // При равенстве остаётся привычная: смена кладки — заметное для игрока
  // событие, и происходить оно должно только за выигрыш в читаемости.
  return rendered(packed) > rendered(classic) ? packed : classic;
}

/// Геометрия круга: где центральная фраза, где варианты, каким кеглем.
///
/// Вынесена из виджета отдельным значением, потому что её используют трое:
/// раскладка, отрисовка и попадание пальцем. Считать её в трёх местах —
/// верный способ получить расхождение между тем, что видно, и тем, что
/// нажимается.
///
/// ── Почему круги стали капсулами, а окружность — полосами ────────────────
///
/// Прежняя геометрия была построена под **слово**: вариант — круг радиусом в
/// 0.15 короткой стороны, центр — 0.19, орбита — «прижата к краю». Слово в
/// такой круг помещалось, и три строки с многоточием были запасом на самый
/// длинный случай.
///
/// Единицей изучения стала фраза, и та же геометрия перестала работать сразу
/// в трёх местах:
///
/// 1. **Круг — худшая форма под длинный текст.** Полезная ширина в нём
///    сходится к нулю у верха и низа. На арене 328 точек — телефон 360dp —
///    вариант выходил радиусом 49, то есть меньше сотни точек под фразу в 90
///    знаков (максимум корпуса; медиана 33). Многоточие срабатывало не на
///    редком случае, а на большинстве фраз выше A1: «Ich bin bereit, eine
///    alternative …».
/// 2. **Шесть кругов стояли вплотную.** Шаг между соседями по окружности из
///    шести точек равен её радиусу, то есть 0.35 короткой стороны, а вариант
///    занимал 0.30 в поперечнике: между соседями оставалось 0.05 — на той же
///    арене 16 точек. Меньше, чем ореол свечения (18) и чем внутренние поля
///    текста; а зона попадания была шире отрисованной в 1.35 раза и с
///    соседней пересекалась прямо.
/// 3. **Центр налезал на варианты.** 62 точки радиуса центра плюс 49 радиуса
///    варианта против 107 орбиты — пересекались уже сами круги. А ширину
///    центральной фразы не ограничивало ничто: она шла поверх соседних
///    вариантов, и не читалось ни то, ни другое.
///
/// Что осталось неизменным: центр и шесть вокруг, угол по индексу (нулевой
/// сверху, дальше по часовой) и то, что круг — созвездие. Что изменилось:
/// вариант — не точка на окружности, а капсула, и шесть углов складываются в
/// полосы, между которыми по вертикали встаёт центр. Размеры считаются от
/// содержимого: короткие фразы A0 обжимают капсулы до пилюль и кольцо остаётся
/// кольцом, длинные B2 растят их в высоту и съедают воздух.
///
/// Чего эта геометрия не умела — **не влезать**. Считать её от содержимого
/// значит однажды получить содержимое, которое в арену не укладывается ни при
/// каком кегле; тогда полосы просто уезжали за низ арены, а вместе с ними и
/// возможность нажать вариант. Что с этим сделано — в [_plan]; сама сборка
/// по-прежнему только складывает и честно сообщает, сколько высоты ей нужно
/// ([need]).
class _ArenaLayout {
  const _ArenaLayout({
    required this.core,
    required this.promptRect,
    required this.hintRect,
    required this.capsules,
    required this.targets,
    required this.corners,
    required this.optionStyle,
    required this.promptStyle,
    required this.hintStyle,
    required this.need,
  });

  /// Складывает геометрию в арену [box] выбранной кладкой.
  ///
  /// [box] — не обязательно настоящая арена: когда содержимое в настоящую не
  /// влезает, [_plan] считает геометрию для арены пошире и уменьшает готовую
  /// картинку целиком. Поэтому здесь нет ни одной ссылки на размер экрана —
  /// только на [box].
  factory _ArenaLayout.of(
    _LayoutKey key, {
    required Size box,
    required bool wide,
  }) {
    final options = key.question.options;
    final count = options.length;
    final fullW = math.max(0.0, box.width - 2 * _arenaEdge);
    final fullH = math.max(0.0, box.height - 2 * _arenaEdge);
    // Ширина, доступная тексту центра: у него нет капсулы, но подпирать
    // буквами край арены незачем.
    final centerW = math.max(0.0, fullW - _capsulePad.horizontal);

    // Полосы вариантов и место центра между ними.
    final bands = _bands(count, wide: wide);
    var promptAt = bands.indexWhere((b) => b.row >= 0);
    if (promptAt < 0) promptAt = bands.length;
    final rows = <_Band?>[
      ...bands.take(promptAt),
      null, // центр: полосой вариантов не является, а высоту занимает так же
      ...bands.skip(promptAt),
    ];

    Size measure(String text, TextStyle style, double maxWidth) => _measure(
          text,
          style,
          maxWidth,
          scaler: key.scaler,
          direction: key.direction,
        );

    double slotWidth(int columns) =>
        (fullW - (columns - 1) * _columnGap) / columns;

    // ── Подбор кегля ────────────────────────────────────────────────────
    //
    // Сверху вниз: сперва желаемый, дальше на пункт мельче, пока полосы не
    // станут влезать по высоте. На пределе останавливаемся и с ним и
    // остаёмся — дальше жертвовать пришлось бы читаемостью, а капсула в пять
    // строк лучше кегля, который не прочесть.
    //
    // Если и на пределе не влезает, сборка ничего не обрезает и за арену не
    // выходит: она складывает как сложилось и сообщает нужную высоту ([need]).
    // Решение принимает [_plan] — сменой кладки или уменьшением картинки.
    final wantOption = key.option.fontSize ?? 16;
    final wantPrompt = key.prompt.fontSize ?? 22;

    // Предел читаемости меряется в **отрисованном** кегле, а не в логическом.
    //
    // Разница появляется при системном увеличении шрифта: с `textScaler` 1.5
    // логический кегль 13 выходит на экран как 19.5, и раскладка, которая
    // ниже 13 логических не опускается, перестаёт уменьшать фразу и начинает
    // её обрезать — то есть увеличение шрифта делает текст менее читаемым,
    // чем его отсутствие. Поэтому уменьшаемся, пока **на экране** остаётся не
    // меньше предела: игрок, попросивший крупный шрифт, получает его настолько
    // крупным, насколько влезает, и обрезки не получает никогда.
    double logicalFloor(double rendered) {
      var font = rendered;
      while (font > 4 && key.scaler.scale(font - 0.5) >= rendered) {
        font -= 0.5;
      }
      return font;
    }

    final minOption = logicalFloor(_minOptionFont);
    final minPrompt = logicalFloor(_minPromptFont);

    var optionStyle = key.option;
    var promptStyle = key.prompt;
    var hintStyle = key.tag;
    var texts = <int, Size>{};
    var promptSize = Size.zero;
    var hintSize = Size.zero;
    var heights = <double>[];

    for (var font = wantOption;; font -= 1) {
      final optionFont = math.max(font, minOption);
      // Центр уменьшается вместе с вариантами, но по своей шкале: он главный
      // на экране, и обогнать варианты вниз ему нельзя.
      final promptFont = math.max(
        wantPrompt * optionFont / wantOption,
        minPrompt,
      );
      // `height` задаётся явно: у Material-стилей межстрочное расстояние
      // разное (1.5 у титульных), и на пяти строках разница набегает в
      // полстроки — ровно ту, которой не хватит на шестую.
      optionStyle = key.option.copyWith(fontSize: optionFont, height: 1.15);
      promptStyle = key.prompt.copyWith(fontSize: promptFont, height: 1.2);
      hintStyle = key.tag;

      texts = <int, Size>{};
      heights = <double>[];
      for (final band in rows) {
        if (band == null) {
          if (key.audio) {
            heights.add(_audioSide(box));
            continue;
          }
          promptSize = measure(key.question.prompt, promptStyle, centerW);
          hintSize = key.hint.isEmpty
              ? Size.zero
              : measure(key.hint, hintStyle, centerW);
          heights.add(promptSize.height +
              (hintSize.isEmpty ? 0 : _hintGap + hintSize.height));
          continue;
        }
        final slotW = slotWidth(band.ids.length);
        var h = 0.0;
        for (final id in band.ids) {
          final text = measure(
            options[id],
            optionStyle,
            slotW - _capsulePad.horizontal,
          );
          texts[id] = text;
          h = math.max(
            h,
            math.max(_minCapsuleHeight, text.height + _capsulePad.vertical),
          );
        }
        heights.add(h);
      }

      final needed = heights.fold(0.0, (a, h) => a + h) +
          _minBandGap * (heights.length - 1);
      if (needed <= fullH || optionFont <= minOption) break;
    }

    // ── Сборка ──────────────────────────────────────────────────────────
    final content = heights.fold(0.0, (a, h) => a + h);
    final gaps = math.max(1, heights.length - 1);
    // Кольцо тянется к своей высоте, но не дальше арены и не теснее
    // минимального зазора. Остаток высоты уходит в зазоры, а само кольцо
    // встаёт по центру: на коротких фразах это шесть капсул вокруг центра, на
    // длинных — плотная кладка.
    final target = math.min(
      fullH,
      math.max(content + _minBandGap * gaps, box.width * _ringAspect),
    );
    final gap = math.max(_minBandGap, (target - content) / gaps);
    var y = _arenaEdge + math.max(0.0, (fullH - (content + gap * gaps)) / 2);

    final capsules = List<Rect>.filled(count, Rect.zero);
    final targets = List<Rect>.filled(count, Rect.zero);
    final corners = List<double>.filled(count, 0);
    var promptRect = Rect.zero;
    var hintRect = Rect.zero;
    var core = Rect.zero;

    for (var r = 0; r < rows.length; r++) {
      final band = rows[r];
      final h = heights[r];
      if (band == null) {
        if (key.audio) {
          core = Rect.fromCenter(
            center: Offset(box.width / 2, y + h / 2),
            width: h,
            height: h,
          );
        } else {
          promptRect = Rect.fromLTWH(
            (box.width - promptSize.width) / 2,
            y,
            promptSize.width,
            promptSize.height,
          );
          if (!hintSize.isEmpty) {
            hintRect = Rect.fromLTWH(
              (box.width - hintSize.width) / 2,
              promptRect.bottom + _hintGap,
              hintSize.width,
              hintSize.height,
            );
          }
          core = hintRect.isEmpty
              ? promptRect
              : promptRect.expandToInclude(hintRect);
        }
      } else {
        final slotW = slotWidth(band.ids.length);
        for (var c = 0; c < band.ids.length; c++) {
          final id = band.ids[c];
          final text = texts[id] ?? Size.zero;
          final w = math.min(slotW, text.width + _capsulePad.horizontal);
          final boxH = math.max(
            _minCapsuleHeight,
            text.height + _capsulePad.vertical,
          );
          final rect = Rect.fromCenter(
            center: Offset(
              _arenaEdge + c * (slotW + _columnGap) + slotW / 2,
              y + h / 2,
            ),
            width: w,
            height: boxH,
          );
          capsules[id] = rect;
          corners[id] = math.min(math.min(w, boxH) / 2, _maxCorner);
          // Зона попадания растёт до края своего слота, но не больше запаса:
          // соседние зоны не должны сходиться, иначе игрок получал бы ответ
          // соседа, целясь в свой.
          final growX = math.min(_touchSlack, (slotW - w) / 2);
          final growY = math.min(_touchSlack, gap / 2);
          targets[id] = Rect.fromLTRB(
            rect.left - growX,
            rect.top - growY,
            rect.right + growX,
            rect.bottom + growY,
          );
        }
      }
      y += h + gap;
    }

    return _ArenaLayout(
      core: core.isEmpty
          ? Rect.fromCenter(
              center: box.center(Offset.zero),
              width: 1,
              height: 1,
            )
          : core,
      promptRect: promptRect,
      hintRect: hintRect,
      capsules: capsules,
      targets: targets,
      corners: corners,
      optionStyle: optionStyle,
      promptStyle: promptStyle,
      hintStyle: hintStyle,
      // Сколько высоты арены содержимое просит при минимальных зазорах. Ровно
      // то же число, по которому вышел подбор кегля, — иначе [_plan] уменьшал
      // бы картинку по одному замеру, а обрезка приходила бы по другому.
      need: content + _minBandGap * gaps + 2 * _arenaEdge,
    );
  }

  /// Область центра: фраза с пометкой или динамик. Из неё вылетают варианты
  /// при разворачивании, и от неё же идёт линия-соединение.
  final Rect core;

  /// Центральная фраза и пометка под ней. Пустые, когда в центре динамик.
  final Rect promptRect;
  final Rect hintRect;

  /// Капсулы вариантов по индексу вопроса.
  final List<Rect> capsules;

  /// Зоны попадания: шире капсул.
  final List<Rect> targets;

  /// Скругление капсулы по индексу.
  final List<double> corners;

  final TextStyle optionStyle;
  final TextStyle promptStyle;
  final TextStyle hintStyle;

  /// Высота арены, которую просит содержимое: полосы плюс минимальные зазоры
  /// плюс отступы от краёв.
  ///
  /// По ней [_plan] решает, влезла ли раскладка. Само по себе «влезла» из
  /// прямоугольников не читается: капсулы можно поставить и за низ арены, и
  /// прежняя раскладка так и делала — молча, потому что спросить было некого.
  final double need;

  /// Какой вариант под точкой. Ищется по зоне попадания, а не по капсуле:
  /// зона шире отрисованного ровно затем, чтобы палец не промахивался
  /// (см. [_touchSlack]), но с соседней не сходится.
  int? hitTest(Offset point) {
    for (var i = 0; i < targets.length; i++) {
      if (targets[i].contains(point)) return i;
    }
    return null;
  }

  /// Угол варианта по индексу: нулевой сверху, дальше по часовой.
  static double _angle(int index, int count) =>
      -math.pi / 2 + 2 * math.pi * index / count;

  /// Полосы вариантов сверху вниз; индексы внутри полосы — слева направо.
  ///
  /// Полосы считаются из угла, а не выписаны руками, и это важнее, чем
  /// кажется: правило «нулевой сверху, дальше по часовой» остаётся одним —
  /// тем же, по которому вариант стоял на окружности. Изменись число
  /// вариантов, и полосы пересчитаются сами, а порядок не разъедется.
  ///
  /// Кладок две, и различаются они одним: насколько крупно огрублять угол.
  ///
  /// * **Привычная** (`wide: false`) — синус до сотых: шесть углов дают четыре
  ///   полосы, 1 + 2 + 2 + 1, между второй и третьей встаёт центр. Пять рядов
  ///   на высоту.
  /// * **Широкая** (`wide: true`) — от синуса берётся только знак: полосы две,
  ///   3 + 3, центр между ними. Три ряда вместо пяти, и высоты нужно почти
  ///   вдвое меньше — ценой того, что полоса делится на три слота, а не на
  ///   два, и фраза в каждом переносится чаще. Где высоты не хватает, это
  ///   выигрыш; где не хватает ширины — проигрыш. Поэтому выбирает между ними
  ///   не форма экрана, а замер ([_plan]): на лежащей арене 604×266 и на
  ///   стоящей 284×474 выигрывает широкая, на 284×386 — привычная.
  ///
  /// Кольцо в обеих кладках остаётся кольцом: обход 0 → 1 → … → 5 идёт по
  /// выпуклому шестиугольнику и сам себя не пересекает — в широкой это
  /// «середина верха, правый верх, правый низ, середина низа, левый низ, левый
  /// верх». Порядок по часовой сохранён, а значит сохранена и метафора: центр
  /// и шесть вокруг.
  static List<_Band> _bands(int count, {required bool wide}) {
    final rows = <double, List<int>>{};
    for (var i = 0; i < count; i++) {
      // Ключ полосы — синус угла, огрублённый до сотых: у симметричных
      // вариантов он совпадает, а плавающая точка на таком округлении не
      // расходится. Широкая кладка берёт от того же синуса знак — и полос
      // становится ровно вдвое меньше.
      final sin = math.sin(_angle(i, count));
      final key = wide ? (sin < 0 ? -1.0 : 1.0) : (sin * 100).roundToDouble();
      (rows[key] ??= <int>[]).add(i);
    }
    final keys = rows.keys.toList()..sort();
    return [
      for (final key in keys)
        (
          row: key,
          ids: rows[key]!
            ..sort((a, b) => math
                .cos(_angle(a, count))
                .compareTo(math.cos(_angle(b, count)))),
        ),
    ];
  }
}

/// Сторона центра в механиках на слух: мерить там нечего — вместо фразы
/// динамик, и место ему нужно постоянное.
double _audioSide(Size size) =>
    math.min(120, math.max(72, size.shortestSide * 0.22));

/// Размер, который занимает текст в полосе шириной [maxWidth].
///
/// Ширина — самая длинная строка, а не заданная граница: по ней капсула
/// обжимает короткую фразу, и на A0 круг остаётся созвездием мелких капсул, а
/// не грядкой одинаковых плит.
Size _measure(
  String text,
  TextStyle style,
  double maxWidth, {
  required TextScaler scaler,
  required TextDirection direction,
}) {
  if (text.isEmpty) return Size.zero;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: math.max(0, maxWidth));
  var width = 0.0;
  for (final line in painter.computeLineMetrics()) {
    width = math.max(width, line.width);
  }
  final height = painter.height;
  painter.dispose();
  // Плюс точка на округление. Обжать капсулу ровно по замеру значит поставить
  // перенос на границу ошибки округления: строка, влезавшая при замере, при
  // отрисовке уедет вниз, и получится та самая обрезка, от которой всё это
  // считается.
  return Size(width.ceilToDouble() + 1, height.ceilToDouble());
}

/// Кольцо, рамки капсул, свечение центра и линия-соединение.
///
/// Правило подсветки художник не знает — цвет и силу свечения каждой капсулы
/// ему передают готовыми ([accents]). Считалось это правило когда-то дважды: в
/// цвете надписи и в цвете звезды; расхождение двух копий ничем не
/// проверялось, потому что тест читает надпись, а игрок смотрит на свечение.
class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({
    required this.layout,
    required this.pointer,
    required this.accents,
    required this.reveal,
  });

  final _ArenaLayout layout;
  final Offset? pointer;
  final List<_Accent> accents;

  /// 0 → круг разворачивается, 1 → развернулся.
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRing(canvas);
    for (var i = 0; i < layout.capsules.length && i < accents.length; i++) {
      _paintCapsule(canvas, i);
    }
    _paintCore(canvas);
    _paintConnection(canvas);
  }

  /// Рамка капсулы со свечением. Вылетает из центра при разворачивании —
  /// движение осталось тем же, каким вылетали звёзды.
  void _paintCapsule(Canvas canvas, int index) {
    final capsule = layout.capsules[index];
    final accent = accents[index];
    final rect = capsule.shift(
      (layout.core.center - capsule.center) * (1 - reveal),
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(layout.corners[index]),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accent.line.withValues(alpha: accent.glow * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        // Подсвеченная капсула обводится вдвое толще: на шести капсулах, из
        // которых пять приглушены, одного цвета мало — рамка в один пиксель
        // при 0.35 прозрачности читается как та же рамка.
        ..strokeWidth = accent.glow > 0.5 ? 2 : 1
        ..color = accent.line.withValues(alpha: accent.glow),
    );
  }

  /// Кольцо, по которому расставлены варианты.
  ///
  /// Раньше это была окружность, и вариантов на ней не было — были точки
  /// одного радиуса. Теперь кольцо проходит **через центры капсул**: провести
  /// окружность там, где капсулы стоят полосами, значило бы нарисовать линию,
  /// которая ни одной звезды не касается.
  void _paintRing(Canvas canvas) {
    if (layout.capsules.length < 3) return;
    final origin = layout.core.center;
    final path = Path();
    for (var i = 0; i < layout.capsules.length; i++) {
      final point = origin +
          (layout.capsules[i].center - origin) * reveal;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = LumenPalette.constellationLine.withValues(alpha: 0.12),
    );
  }

  /// Свечение под центральной фразой: атмосфера, а не рамка. Рамки у центра
  /// нет нарочно — он не вариант, и выбирать его нельзя.
  void _paintCore(Canvas canvas) {
    final core = layout.core.inflate(10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        core,
        Radius.circular(math.min(core.shortestSide / 2, _maxCorner)),
      ),
      Paint()
        ..color = LumenPalette.starlight.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  /// Сама связь: линия от центра к пальцу. Это главный жест игры, поэтому
  /// она яркая и с ореолом, а не тонкая техническая черта.
  void _paintConnection(Canvas canvas) {
    final target = pointer;
    if (target == null) return;

    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = LumenPalette.starlight.withValues(alpha: 0.85);
    final halo = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..color = LumenPalette.starlight.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(layout.core.center, target, halo);
    canvas.drawLine(layout.core.center, target, line);
  }

  @override
  bool shouldRepaint(_ArenaPainter old) =>
      old.pointer != pointer ||
      old.reveal != reveal ||
      !identical(old.layout, layout) ||
      !listEquals(old.accents, accents);
}
