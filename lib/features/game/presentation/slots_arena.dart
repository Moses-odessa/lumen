import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/game_mode.dart';

/// Арена со слотами: механики **e** (заполни пропуски) и **f** (собери
/// предложение).
///
/// Одна арена на две механики, потому что задача у них одна и та же —
/// расставить слова по местам. Различие только в том, что показано вокруг
/// слотов: в **e** это фраза с пропусками, в **f** пустых мест столько же,
/// сколько слов, и текста нет вовсе.
///
/// Слова-кандидаты лежат сверху и снизу от фразы. Это не украшение раскладки:
/// в круге вариант выбирают один раз, а здесь их несколько и порядок значим,
/// поэтому пул должен быть виден целиком, не перекрывая саму фразу.
class SlotsArena extends StatefulWidget {
  const SlotsArena({
    super.key,
    required this.question,
    required this.onAnswer,
    this.enabled = true,
  });

  final CircleQuestion question;

  /// Что игрок поставил в каждый слот — индексы вариантов из пула — и время
  /// от появления задания до последнего заполнения.
  final void Function(List<int> bySlot, Duration latency) onAnswer;

  final bool enabled;

  @override
  State<SlotsArena> createState() => _SlotsArenaState();
}

class _SlotsArenaState extends State<SlotsArena> {
  late DateTime _shownAt;

  /// Слот → индекс варианта в пуле. Незаполненные отсутствуют.
  final Map<int, int> _placed = {};

  /// Какой слот заполняется следующим: первый пустой слева.
  int? get _nextSlot {
    for (var i = 0; i < widget.question.slotCount; i++) {
      if (!_placed.containsKey(i)) return i;
    }
    return null;
  }

  bool get _complete => _placed.length == widget.question.slotCount;

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
    }
  }

  /// Кладёт вариант в первый пустой слот.
  ///
  /// Порядок заполнения — слева направо, и выбирать слот игроку не нужно:
  /// в **f** порядок и есть ответ, а в **e** пропуски заполняются по чтению.
  /// Дать выбирать слот значило бы добавить к заданию вторую задачу —
  /// вспомнить, какой пропуск ты уже занял.
  void _place(int optionIndex) {
    if (!widget.enabled || _complete) return;
    final slot = _nextSlot;
    if (slot == null) return;

    setState(() => _placed[slot] = optionIndex);

    if (_placed.length == widget.question.slotCount) {
      final bySlot = [
        for (var i = 0; i < widget.question.slotCount; i++) _placed[i]!,
      ];
      widget.onAnswer(bySlot, DateTime.now().difference(_shownAt));
    }
  }

  /// Снимает последнее поставленное слово.
  void _undo() {
    if (!widget.enabled || _placed.isEmpty || _complete) return;
    final last = _placed.keys.reduce((a, b) => a > b ? a : b);
    setState(() => _placed.remove(last));
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Пул делится надвое: половина сверху, половина снизу.
    final used = _placed.values.toSet();
    final half = (question.options.length / 2).ceil();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pool(
          options: question.options,
          from: 0,
          to: half,
          used: used,
          onTap: _place,
          enabled: widget.enabled && !_complete,
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (question.mode == GameMode.fillGaps)
                    _Template(question: question, placed: _placed)
                  else
                    _Slots(question: question, placed: _placed),
                  if (question.promptHint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      question.promptHint!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // Перевод проявляется только когда всё заполнено. Показать
                  // его раньше — значит отдать ответ; не показать вовсе —
                  // значит научить подбирать форму, не поняв фразы.
                  if (_complete && question.translation != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      question.translation!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: LumenPalette.starlight,
                      ),
                    ),
                  ],
                  if (_placed.isNotEmpty && !_complete) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _undo,
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text(l10n.commonUndo),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Pool(
          options: question.options,
          from: half,
          to: question.options.length,
          used: used,
          onTap: _place,
          enabled: widget.enabled && !_complete,
        ),
      ],
    );
  }
}

/// Половина пула слов-кандидатов.
class _Pool extends StatelessWidget {
  const _Pool({
    required this.options,
    required this.from,
    required this.to,
    required this.used,
    required this.onTap,
    required this.enabled,
  });

  final List<String> options;
  final int from;
  final int to;
  final Set<int> used;
  final ValueChanged<int> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = from; i < to && i < options.length; i++)
          // Поставленное слово не исчезает, а гаснет: исчезающие слова
          // переставляют пул под пальцем, и следующее нажатие попадает не
          // туда, куда игрок смотрел.
          Opacity(
            opacity: used.contains(i) ? 0.25 : 1,
            child: ActionChip(
              label: Text(options[i]),
              onPressed: enabled && !used.contains(i) ? () => onTap(i) : null,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
      ],
    );
  }
}

/// Фраза с пропусками: механика **e**.
class _Template extends StatelessWidget {
  const _Template({required this.question, required this.placed});

  final CircleQuestion question;
  final Map<int, int> placed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = question.prompt.split('_____');

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (parts[i].trim().isNotEmpty)
            Text(
              parts[i].trim(),
              style: theme.textTheme.titleMedium,
            ),
          if (i < parts.length - 1)
            _Slot(
              text: placed.containsKey(i)
                  ? question.options[placed[i]!]
                  : null,
            ),
        ],
      ],
    );
  }
}

/// Пустые места по числу слов: механика **f**.
class _Slots extends StatelessWidget {
  const _Slots({required this.question, required this.placed});

  final CircleQuestion question;
  final Map<int, int> placed;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          for (var i = 0; i < question.slotCount; i++)
            _Slot(
              text: placed.containsKey(i)
                  ? question.options[placed[i]!]
                  : null,
            ),
        ],
      );
}

/// Одно место под слово: пустое или заполненное.
class _Slot extends StatelessWidget {
  const _Slot({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = text != null;

    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: filled
            ? LumenPalette.starlight.withValues(alpha: 0.12)
            : Colors.transparent,
        border: Border.all(
          color: LumenPalette.constellationLine.withValues(
            alpha: filled ? 0.5 : 0.3,
          ),
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
