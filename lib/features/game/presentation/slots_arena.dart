import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/entities/circle_question.dart';
import 'prompt_tag_text.dart';

/// Арена фразы: предложение с пропусками, вокруг вынутые из него слова.
///
/// Одна механика, а не две. Пропусков от двух до всех слов, и сколько именно
/// — шкала сложности; «собери предложение» это она же на максимуме, когда
/// вынуто всё и скелета не осталось. Двух арен и двух сборщиков поэтому
/// больше нет: они расходились, и разошлись бы снова.
///
/// **Вокруг лежат ровно вынутые слова**, ничего постороннего. Шесть раундов
/// вычитки ушло на списки неверных вариантов, и каждый находил в них слово,
/// дающее правильное немецкое предложение: в рамку, куда влезает одно, влезает
/// и второе. Слова самого предложения такого вопроса не ставят —
/// спрашивается порядок, а не выбор.
///
/// Слова лежат сверху и снизу от фразы. Это не украшение раскладки: в круге
/// вариант выбирают один раз, а здесь их несколько и порядок значим, поэтому
/// пул должен быть виден целиком, не перекрывая саму фразу.
///
/// **Слово можно перетащить, а не только нажать.** Нажатие кладёт слово в
/// первый пустой пропуск слева — так было и осталось; перетаскивание кладёт
/// его туда, куда игрок его принёс. Это не два способа сделать одно и то же:
/// пока способ был один, поставить слово во **второй** пропуск, не заполнив
/// первый, было нельзя, и «поставить это слово вот сюда» приходилось
/// выражать порядком нажатий. Задание при этом — расставить слова по местам,
/// то есть ровно то, что делает палец.
///
/// Отсюда же перестановка: слово из пропуска тащится в другой пропуск, и если
/// там кто-то стоит, они меняются местами. Тащить слово обратно в пул —
/// значит снять его.
///
/// **Ответ отправляет кнопка, а не последняя плитка.** Пока отправка уходила
/// из того же жеста, которым игрок ставил последнее слово, заметить ошибку
/// было уже поздно: «отменить» возвращалась раньше времени при полной
/// расстановке, а её кнопка была скрыта тем же условием. Человек видел
/// неверный порядок в момент, когда сделать с ним ничего нельзя.
///
/// Поэтому «заполнено» и «отвечено» — два разных состояния, и почти все
/// условия арены смотрят на второе. На первое смотрит только сама кнопка
/// «Готово»: она включается, когда заполнены все пропуски.
///
/// Отсюда же и перевод: он проявляется по «Готово», а не по заполнению. Пока
/// он появлялся при заполнении, он был подсказкой к смыслу фразы, которую
/// игрок ещё мог переставить, — то есть отдавал ответ тому, кто ещё не
/// ответил.
class SlotsArena extends StatefulWidget {
  const SlotsArena({
    super.key,
    required this.question,
    required this.onAnswer,
    this.enabled = true,
  });

  final CircleQuestion question;

  /// Что игрок поставил в каждый слот — индексы вариантов из пула — и время
  /// от появления задания до последнего **изменения** расстановки.
  ///
  /// До нажатия «Готово», а не до него: между последней плиткой и кнопкой
  /// игрок проверяет себя, и это время не про скорость ответа. Отдавать его
  /// нельзя — домен приводит время к одному размещению
  /// (`ScoreRules.paceFor`) и по нему же ставит оценку памяти, так что
  /// десять секунд раздумий вернули бы ровно тот дефект, из-за которого
  /// всякая верно собранная фраза записывалась как `hard`.
  final void Function(List<int> bySlot, Duration latency) onAnswer;

  final bool enabled;

  @override
  State<SlotsArena> createState() => _SlotsArenaState();
}

/// Что тащит палец: слово из пула или уже поставленное слово из пропуска.
class _DragWord {
  const _DragWord({required this.option, this.fromSlot});

  /// Индекс слова в пуле вариантов.
  final int option;

  /// Из какого пропуска его вынули. `null` — взято из пула.
  final int? fromSlot;
}

class _SlotsArenaState extends State<SlotsArena> {
  late DateTime _shownAt;

  /// Слот → индекс варианта в пуле. Незаполненные отсутствуют.
  final Map<int, int> _placed = {};

  /// Слоты в порядке заполнения — по нему работает «отменить».
  ///
  /// Отдельный список, а не порядок ключей `_placed`: перетаскивание
  /// заполняет пропуски в любом порядке, а повторная запись в уже занятый
  /// ключ не переставляет его в конец. «Отменить» без этого снимало бы не то
  /// слово, которое игрок поставил последним, а то, что правее всех.
  final List<int> _order = [];

  /// Какой слот заполняется следующим: первый пустой слева.
  int? get _nextSlot {
    for (var i = 0; i < widget.question.slotCount; i++) {
      if (!_placed.containsKey(i)) return i;
    }
    return null;
  }

  /// Когда расстановку изменили последний раз.
  ///
  /// Это и есть время ответа: расстановка сложилась тогда, а не когда игрок
  /// дотянулся до кнопки. Штампуется в каждой мутации, а не только при
  /// полноте: игрок может заполнить всё, потом переставить два слова — ответ
  /// сложился на второй перестановке.
  DateTime? _changedAt;

  bool get _complete => _placed.length == widget.question.slotCount;

  /// Ответ отправлен: дальше арена ничего не принимает.
  ///
  /// Производный признак, а не отдельный флаг, и это выбор в пользу того,
  /// чтобы залипшая защёлка была невозможна. [_accepted] обнуляется на смене
  /// вопроса и присваивается ровно в один момент — в [_submit], — так что
  /// «отвечено» не может остаться истинным на новом вопросе. Отдельное поле
  /// пришлось бы сбрасывать вручную, а именно такой несброшенный признак уже
  /// вешал уровень насмерть: промах возвращается в очередь тем же вопросом
  /// (`CircleQuestion.again`), и арена, не принимающая ответов, ждёт вечно.
  ///
  /// Отдельно от [_complete], и это главное разделение в этом виджете.
  /// «Заполнено» больше не значит «отвечено»: заполненную расстановку можно
  /// разбирать, переставлять и отменять, пока не нажата «Готово».
  bool get _answered => _accepted != null;

  /// Приняли ли расстановку — считается здесь же, как в круге.
  ///
  /// Арена держит вопрос, значит может сама спросить у него, верна ли сборка,
  /// и не нуждается для этого в параметре сверху. Нужно это затем, что
  /// длинную паузу после ошибки проект оправдывает словами «игроку надо
  /// успеть увидеть верный вариант» — а фразовая арена не показывала его
  /// никогда. Круг это правило выполняет: там верный вариант подсвечивается,
  /// даже если игрок выбрал другой.
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
  }

  @override
  void didUpdateWidget(SlotsArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _shownAt = DateTime.now();
      _placed.clear();
      _order.clear();
      _accepted = null;
      // Штамп прошлого вопроса с новым `_shownAt` дал бы **отрицательную**
      // длительность ответа: в журнале отзывов отрицательные миллисекунды, а
      // оценка памяти — «легко», потому что любой порог она проходит.
      _changedAt = null;
    }
  }

  /// Кладёт вариант в первый пустой слот — путь нажатия.
  ///
  /// Порядок заполнения слева направо: пропуски заполняются по чтению, а на
  /// максимуме глубины порядок и есть ответ. Выбирать слот нажатием не нужно
  /// — это добавило бы к заданию вторую задачу, вспомнить, какой пропуск ты
  /// уже занял. Кому нужен конкретный пропуск, тот его туда тащит.
  void _place(int optionIndex) {
    if (!widget.enabled || _answered) return;
    final slot = _nextSlot;
    if (slot == null) return;

    setState(() {
      _placed[slot] = optionIndex;
      _order.add(slot);
      _changedAt = DateTime.now();
    });
  }

  /// Кладёт принесённое пальцем слово в конкретный пропуск.
  void _drop(int slot, _DragWord word) {
    if (!widget.enabled || _answered) return;
    if (word.fromSlot == slot) return;

    setState(() {
      final displaced = _placed[slot];
      final from = word.fromSlot;
      if (from != null) {
        // Обмен, а не затирание: прежний жилец уходит туда, откуда пришло
        // принесённое слово. Иначе перестановка двух слов местами стоила бы
        // трёх жестов и одного исчезнувшего слова.
        if (displaced == null) {
          _placed.remove(from);
          _order.remove(from);
        } else {
          _placed[from] = displaced;
        }
      }
      // Слово из пула на занятый пропуск: прежнее просто возвращается в пул —
      // из `_placed` его вытесняет запись ниже, а из порядка убирает `remove`.
      _placed[slot] = word.option;
      _order
        ..remove(slot)
        ..add(slot);
      _changedAt = DateTime.now();
    });
  }

  /// Снимает слово с пропуска — его вытащили обратно в пул или нажали по нему.
  ///
  /// Нажатие по занятому пропуску тоже снимает слово, и это не удобство, а
  /// доступность. При полной расстановке других путей правки не остаётся:
  /// плитки пула все заняты, значит нажимать нечего, а «отменить» снимает
  /// только последнее поставленное — чтобы освободить первый пропуск из трёх,
  /// пришлось бы нажать её трижды. Оставалось одно перетаскивание, а это
  /// самый трудный жест для человека с дрожью в руках или треснувшим экраном.
  /// Правка делается ровно для того, кто заметил ошибку.
  void _pullOut(int slot) {
    if (!widget.enabled || _answered) return;
    if (!_placed.containsKey(slot)) return;
    setState(() {
      _placed.remove(slot);
      _order.remove(slot);
      _changedAt = DateTime.now();
    });
  }

  /// Отправляет расстановку — нажатие «Готово».
  ///
  /// Вердикт считается здесь же, в одном `setState` с флагом «отвечено», и
  /// только потом уходит колбэк. Порядок важен дважды: второе нажатие по
  /// кнопке не должно отправить ответ второй раз (хозяин гасит арену своим
  /// `enabled` только **после** колбэка, то есть кадром позже), а верный
  /// порядок не должен появиться раньше рамки хозяина, которая рисуется по
  /// его же состоянию.
  void _submit() {
    if (!widget.enabled || !_complete || _answered) return;
    final bySlot = [
      for (var i = 0; i < widget.question.slotCount; i++) _placed[i]!,
    ];
    setState(() => _accepted = widget.question.acceptsSlots(bySlot));

    // Время — до последнего изменения расстановки, а не до нажатия. Между
    // последней плиткой и кнопкой игрок проверяет себя, и это время не про
    // скорость ответа: домен приводит его к одному размещению и по нему же
    // ставит оценку памяти и серию «горящего слова». Очков это не касается —
    // фразовый круг приходит с нулевой яркостью нарочно, а скоростной
    // множитель включается только с 40 lm.
    widget.onAnswer(
      bySlot,
      (_changedAt ?? DateTime.now()).difference(_shownAt),
    );
  }

  /// Снимает последнее поставленное слово.
  void _undo() {
    if (!widget.enabled || _order.isEmpty || _answered) return;
    setState(() {
      _placed.remove(_order.removeLast());
      _changedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final used = _placed.values.toSet();
    final live = widget.enabled && !_answered;

    // Пул делится надвое только когда его есть смысл делить.
    //
    // Деление придумано для восьми-девяти плиток: пул должен быть виден
    // целиком, не перекрывая фразу. Но калибровка спрашивает фразу на
    // минимальной глубине, то есть ровно с двумя плитками, — и они уезжали к
    // самому верху и самому низу экрана, разделённые всей фразой. Два слова,
    // между которыми полэкрана, читаются как две не связанные кнопки, а
    // палец проходит это расстояние на каждом ответе. Первая фраза, которую
    // человек видит в игре, выглядела именно так.
    final split = question.options.length > SlotsArenaLayout.splitPoolAbove;
    final half = split ? (question.options.length / 2).ceil() : 0;

    // Регистр фразы (`casual`) — код, а не текст: под каждой из 432 фраз
    // стояло английское служебное слово, независимо от языка интерфейса.
    final hint = [
      question.promptHint,
      promptTagText(l10n, question.promptTag),
    ].nonNulls.join(' · ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (split) ...[
          _Pool(
            options: question.options,
            from: 0,
            to: half,
            used: used,
            onTap: _place,
            onReturn: _pullOut,
            enabled: live,
          ),
          const SizedBox(height: 20),
        ],
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Один рисовальщик на любую глубину пропусков. При
                  // максимуме скелет — строка из одних пропусков, и отдельного
                  // вида центра для неё не нужно. Прежний `_Slots` рисовал её
                  // через `Wrap`, тот самый, из-за которого точка отлетала от
                  // заполненного слова.
                  _Template(
                    question: question,
                    placed: _placed,
                    onDrop: _drop,
                    onPullOut: _pullOut,
                    enabled: live,
                    // Какой пропуск заполнит нажатие. Порядок «слева
                    // направо» игрок должен видеть, а не выводить: пустые
                    // пропуски рисовались одинаково, и на трёх и более
                    // угадать, куда попадёт следующий тап, было нельзя.
                    next: live ? _nextSlot : null,
                  ),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // Перевод проявляется по «Готово», а не по заполнению.
                  //
                  // Условие было «все пропуски заполнены», и собственный
                  // комментарий рядом объяснял его так: показать раньше —
                  // значит отдать ответ. С кнопкой «заполнено» перестало
                  // значить «отвечено», и тот же довод переехал вместе с
                  // условием: задание фразы — порядок, а перевод сообщает
                  // смысл целиком, то есть подтверждает или опровергает
                  // выбранную расстановку до того, как её оценили. Больнее
                  // всего там, где порядок меняет смысл: подлежащее и
                  // дополнение, место отрицания, вопрос против утверждения.
                  //
                  // Не показать вовсе — тоже нельзя: это учит подбирать
                  // форму, не поняв фразы.
                  if (_answered && question.translation != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      question.translation!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: LumenPalette.starlight,
                      ),
                    ),
                  ],
                  // Верный порядок — только после ошибки, и это то самое
                  // «успеть увидеть верный вариант», которым оправдана
                  // длинная пауза. Своя неверная сборка остаётся на месте:
                  // сравнить надо с ней, а не вместо неё.
                  if (_accepted == false) ...[
                    const SizedBox(height: 12),
                    Text(
                      question.assembled,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: LumenPalette.correct,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Ряд управления: «отменить» и «Готово».
        //
        // Вне прокрутки, и это не вкус. «Готово» — единственный способ
        // отправить ответ, и уехавшая за сгиб кнопка означала бы молча
        // зависший забег: игрок видит заполненную фразу и не может ничего
        // сделать. Прокрутке остаётся середина — сама фраза, перевод и
        // верный порядок.
        //
        // Ряд стоит всегда и обе кнопки только выключаются, а не исчезают.
        // Так игрок узнаёт о шаге «отправить» с первого кадра, а не в тот
        // момент, когда шаг уже нужен, — незамеченная кнопка это и есть
        // зависший забег. Заодно исчезает скачок раскладки при заполнении.
        //
        // Ряд съедает прежний отступ, а не добавляется к нему: высоту он
        // отбирает у фразы, а на самой глубокой сборке за сгиб уехал бы уже
        // не элемент управления, а вопрос.
        _Controls(
          onUndo: live && _order.isNotEmpty ? _undo : null,
          // «Готово» включается по заполнению — единственное место, где
          // «заполнено» ещё что-то значит.
          onDone: widget.enabled && _complete && !_answered ? _submit : null,
        ),
        _Pool(
          options: question.options,
          from: half,
          to: question.options.length,
          used: used,
          onTap: _place,
          onReturn: _pullOut,
          enabled: live,
        ),
      ],
    );
  }
}

/// Ряд управления под фразой: «отменить» слева, «Готово» справа.
///
/// «Готово» — заполненная кнопка, а «отменить» — текстовая, и различие тут
/// содержательное. В калибровке в шестнадцати пикселях под ареной стоит
/// постоянная текстовая кнопка «я с нуля», одним нажатием выбрасывающая
/// измеренный ярус: две текстовые кнопки рядом на первой же фразе, которую
/// человек видит в игре, читались бы как пара. Поэтому ряд лежит **над**
/// нижним пулом, а не под ним, и главная кнопка выглядит главной.
class _Controls extends StatelessWidget {
  const _Controls({required this.onUndo, required this.onDone});

  /// `null` — кнопка выключена, но на месте.
  final VoidCallback? onUndo;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // «Отменить» отдана вся оставшаяся ширина, а «Готово» берёт свою
          // естественную. В `Row` нефлексовые дети размеряются первыми, так
          // что главная кнопка целиком есть всегда, а сжимается и обрезается
          // подпись второй.
          //
          // Не запас на будущее: на 360 px ряд из двух кнопок с подписями
          // переполнялся на 12 px по-украински, а по-немецки «Rückgängig»
          // шире ещё на треть. Переполненный ряд — это невидимая часть
          // единственной кнопки, которой отправляют ответ.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('phrase-undo'),
                onPressed: onUndo,
                icon: const Icon(Icons.undo, size: 18),
                label: Text(
                  l10n.commonUndo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('phrase-done'),
            onPressed: onDone,
            icon: const Icon(Icons.check, size: 18),
            label: Text(
              l10n.commonDone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Раскладка арены — то, что зависит от числа плиток, а не от механики.
abstract final class SlotsArenaLayout {
  /// Выше этого числа плиток пул делится надвое: половина над фразой,
  /// половина под ней. До этого числа он лежит одним рядом под фразой.
  ///
  /// Это не игровая цифра, поэтому её место здесь, а не в `balance.dart`:
  /// сложность задания она не меняет, а меняет расстояние, которое проходит
  /// палец.
  static const int splitPoolAbove = 4;
}

/// Половина пула слов-кандидатов.
///
/// Она же — место, куда слово возвращают: пул принимает то, что вытащили из
/// пропуска. «Отменить» снимает последнее поставленное, а вытащить пальцем
/// можно любое.
class _Pool extends StatelessWidget {
  const _Pool({
    required this.options,
    required this.from,
    required this.to,
    required this.used,
    required this.onTap,
    required this.onReturn,
    required this.enabled,
  });

  final List<String> options;
  final int from;
  final int to;
  final Set<int> used;
  final ValueChanged<int> onTap;

  /// Слово принесли обратно из пропуска — снять его оттуда.
  final ValueChanged<int> onReturn;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<_DragWord>(
      onWillAcceptWithDetails: (details) =>
          enabled && details.data.fromSlot != null,
      onAcceptWithDetails: (details) => onReturn(details.data.fromSlot!),
      builder: (context, candidate, rejected) => Container(
        // Пустая половина пула всё равно должна принимать слово, поэтому у
        // неё есть высота даже без детей: иначе вернуть последнее слово было
        // бы некуда.
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: candidate.isEmpty
              ? Colors.transparent
              : LumenPalette.starlight.withValues(alpha: 0.08),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = from; i < to && i < options.length; i++)
              _PoolWord(
                // Ключ адресует слово в пуле: по нему его находит проверка
                // перетаскивания, которой иначе не за что взяться — текст
                // слова в предложении и в пуле один и тот же.
                key: ValueKey('pool-word-$i'),
                label: options[i],
                // Поставленное слово не исчезает, а гаснет: исчезающие слова
                // переставляют пул под пальцем, и следующее нажатие попадает
                // не туда, куда игрок смотрел.
                used: used.contains(i),
                enabled: enabled,
                onTap: () => onTap(i),
                drag: _DragWord(option: i),
                background: theme.colorScheme.surfaceContainerHighest,
              ),
          ],
        ),
      ),
    );
  }
}

/// Одно слово в пуле: его можно нажать и можно потащить.
class _PoolWord extends StatelessWidget {
  const _PoolWord({
    super.key,
    required this.label,
    required this.used,
    required this.enabled,
    required this.onTap,
    required this.drag,
    required this.background,
  });

  final String label;
  final bool used;
  final bool enabled;
  final VoidCallback onTap;
  final _DragWord drag;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final chip = Opacity(
      opacity: used ? 0.25 : 1,
      child: ActionChip(
        label: Text(label),
        onPressed: enabled && !used ? onTap : null,
        backgroundColor: background,
      ),
    );

    if (!enabled || used) return chip;

    return Draggable<_DragWord>(
      data: drag,
      // Под пальцем едет копия слова, а само оно остаётся на месте
      // полупрозрачным: пул не должен переставляться в момент, когда игрок
      // тащит из него слово.
      feedback: _DragChip(label: label),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
    );
  }
}

/// Слово под пальцем.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Chip(
        label: Text(label),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        elevation: 6,
      ),
    );
  }
}

/// Фраза с пропусками: механика **e**.
class _Template extends StatelessWidget {
  const _Template({
    required this.question,
    required this.placed,
    required this.onDrop,
    required this.onPullOut,
    required this.enabled,
    this.next,
  });

  final CircleQuestion question;
  final Map<int, int> placed;
  final void Function(int slot, _DragWord word) onDrop;

  /// Нажали по занятому пропуску — снять слово.
  final ValueChanged<int> onPullOut;

  final bool enabled;

  /// Пропуск, который заполнит нажатие: он подсвечен.
  final int? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = question.prompt.split('_____');

    // Одна строка текста со слотами внутри, а не `Wrap` из отдельных `Text`.
    //
    // `Wrap` расставлял равные отступы между всеми детьми, а точка после
    // пропуска попадала в отдельного ребёнка: игрок видел заполненное слово и
    // отлетевшую от него точку. Задевало 24 шаблона A0 из 36 — все, где
    // пропуск стоит перед знаком без пробела: «Ich trinke {water}.», «Wo ist
    // die {post}? …», «Ich muss zum {doctor}, …».
    //
    // Дело не в контенте: так `Wrap` расставляет любой список детей. Поэтому
    // и лечится это разметкой, а не пробелами в шаблонах.
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
            if (i < parts.length - 1)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _SlotTarget(
                  key: ValueKey('phrase-slot-$i'),
                  slot: i,
                  armed: next == i,
                  text: placed.containsKey(i)
                      ? question.options[placed[i]!]
                      : null,
                  option: placed[i],
                  enabled: enabled,
                  onDrop: onDrop,
                  onPullOut: onPullOut,
                ),
              ),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium,
    );
  }
}

/// Пропуск, который принимает принесённое слово и отдаёт своё.
class _SlotTarget extends StatelessWidget {
  const _SlotTarget({
    super.key,
    required this.slot,
    required this.text,
    required this.option,
    required this.enabled,
    required this.onDrop,
    required this.onPullOut,
    this.armed = false,
  });

  final int slot;
  final String? text;

  /// Сюда встанет слово, если игрок нажмёт на плитку, а не принесёт её.
  final bool armed;

  /// Что здесь стоит — чтобы это можно было потащить дальше.
  final int? option;

  final bool enabled;
  final void Function(int slot, _DragWord word) onDrop;
  final ValueChanged<int> onPullOut;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragWord>(
      onWillAcceptWithDetails: (details) =>
          enabled && details.data.fromSlot != slot,
      onAcceptWithDetails: (details) => onDrop(slot, details.data),
      builder: (context, candidate, rejected) {
        final slotWidget = _Slot(
          text: text,
          highlight: candidate.isNotEmpty,
          armed: armed,
        );
        final filled = option;
        if (!enabled || filled == null) return slotWidget;

        // Поставленное слово можно унести в другой пропуск или обратно в
        // пул — и просто снять нажатием. Нажатие тут не дубль
        // перетаскивания: при полной расстановке других путей правки не
        // остаётся вовсе, потому что все плитки пула заняты, а «отменить»
        // снимает только последнее поставленное.
        return Draggable<_DragWord>(
          data: _DragWord(option: filled, fromSlot: slot),
          feedback: _DragChip(label: text ?? ''),
          childWhenDragging: const _Slot(),
          child: GestureDetector(
            onTap: () => onPullOut(slot),
            child: slotWidget,
          ),
        );
      },
    );
  }
}

/// Одно место под слово: пустое или заполненное.
class _Slot extends StatelessWidget {
  const _Slot({this.text, this.highlight = false, this.armed = false});

  final String? text;

  /// Над пропуском держат слово: он должен показать, что примет его.
  final bool highlight;

  /// Пропуск на очереди у нажатия — подсвечен слабее, чем под пальцем.
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = text != null;

    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: highlight
            ? LumenPalette.starlight.withValues(alpha: 0.24)
            : filled
                ? LumenPalette.starlight.withValues(alpha: 0.12)
                : Colors.transparent,
        border: Border.all(
          color: LumenPalette.constellationLine.withValues(
            alpha: highlight
                ? 0.9
                : armed
                    ? 0.65
                    : filled
                        ? 0.5
                        : 0.3,
          ),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Text(
        text ?? '',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: filled ? LumenPalette.starlight : null,
        ),
      ),
    );
  }
}
