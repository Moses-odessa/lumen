import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/palette.dart';
import '../../../domain/entities/circle_question.dart';

/// Что произошло с кругом после ответа.
enum CircleOutcome { correct, wrong }

/// Круг: в центре слово или фраза, вокруг 5–6 вариантов. Игрок тянет пальцем
/// от центра к нужному.
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
  });

  final CircleQuestion question;

  /// Индекс выбранного варианта и время от появления круга до отпускания.
  final void Function(int index, Duration latency) onAnswer;

  /// Круг заморожен: идёт анимация схлопывания или показывается результат.
  final bool enabled;

  @override
  State<CircleArena> createState() => _CircleArenaState();
}

class _CircleArenaState extends State<CircleArena>
    with SingleTickerProviderStateMixin {
  /// Момент появления круга — от него отсчитывается время отклика.
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

  /// Геометрия последней отрисовки — по ней ищем вариант под пальцем.
  _ArenaLayout? _layout;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
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
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = _ArenaLayout.of(size, question.options.length);
        _layout = layout;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanUpdate(d.localPosition),
          onPanUpdate: (d) => _onPanUpdate(d.localPosition),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ArenaPainter(
                      layout: layout,
                      pointer: _pointer,
                      hovered: _hovered,
                      chosen: _chosen,
                      outcome: _outcome,
                      answerIndex: question.answerIndex,
                      reveal: _reveal.value,
                    ),
                  ),
                ),
                _buildCenter(context, layout),
                for (var i = 0; i < question.options.length; i++)
                  _buildOption(context, layout, i),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenter(BuildContext context, _ArenaLayout layout) {
    final question = widget.question;
    final theme = Theme.of(context);

    return Positioned(
      left: layout.center.dx - layout.centerRadius,
      top: layout.center.dy - layout.centerRadius,
      width: layout.centerRadius * 2,
      height: layout.centerRadius * 2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
              if (question.promptHint != null) ...[
                const SizedBox(height: 6),
                Text(
                  question.promptHint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, _ArenaLayout layout, int index) {
    final theme = Theme.of(context);
    final position = layout.optionCenter(index);
    final isChosen = _chosen == index;
    final isAnswer = widget.question.answerIndex == index;

    // Верный вариант подсвечивается и тогда, когда игрок выбрал другой:
    // ошибка должна учить, а не просто отнимать очки.
    final Color color;
    if (_outcome != null && isAnswer) {
      color = LumenPalette.correct;
    } else if (isChosen && _outcome == CircleOutcome.wrong) {
      color = LumenPalette.wrong;
    } else if (_hovered == index) {
      color = LumenPalette.starlight;
    } else {
      color = theme.colorScheme.onSurface;
    }

    return Positioned(
      left: position.dx - layout.optionRadius,
      top: position.dy - layout.optionRadius,
      width: layout.optionRadius * 2,
      height: layout.optionRadius * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _answer(index),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              widget.question.options[index],
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Геометрия круга: где центр, где варианты, какого они размера.
///
/// Вынесена из виджета отдельным значением, потому что её используют трое:
/// раскладка, отрисовка и попадание пальцем. Считать её в трёх местах —
/// верный способ получить расхождение между тем, что видно, и тем, что
/// нажимается.
class _ArenaLayout {
  const _ArenaLayout({
    required this.center,
    required this.orbit,
    required this.centerRadius,
    required this.optionRadius,
    required this.count,
  });

  factory _ArenaLayout.of(Size size, int count) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    // Орбита прижата к краю, но не вплотную: варианту нужно место под текст.
    final optionRadius = shortest * 0.15;
    final orbit = shortest / 2 - optionRadius - 8;
    return _ArenaLayout(
      center: center,
      orbit: math.max(orbit, optionRadius),
      centerRadius: shortest * 0.19,
      optionRadius: optionRadius,
      count: count,
    );
  }

  final Offset center;
  final double orbit;
  final double centerRadius;
  final double optionRadius;
  final int count;

  /// Первый вариант — сверху, дальше по часовой стрелке.
  Offset optionCenter(int index) {
    if (count == 0) return center;
    final angle = -math.pi / 2 + 2 * math.pi * index / count;
    return center + Offset(math.cos(angle), math.sin(angle)) * orbit;
  }

  /// Какой вариант под точкой. Зона попадания шире отрисованной: палец
  /// толще курсора, и промах по варианту читается как ошибка игрока, хотя
  /// это ошибка интерфейса.
  int? hitTest(Offset point) {
    final slack = optionRadius * 1.35;
    for (var i = 0; i < count; i++) {
      if ((optionCenter(i) - point).distance <= slack) return i;
    }
    return null;
  }
}

/// Линия-соединение, орбита и свечение вариантов.
class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({
    required this.layout,
    required this.pointer,
    required this.hovered,
    required this.chosen,
    required this.outcome,
    required this.answerIndex,
    required this.reveal,
  });

  final _ArenaLayout layout;
  final Offset? pointer;
  final int? hovered;
  final int? chosen;
  final CircleOutcome? outcome;
  final int answerIndex;

  /// 0 → круг разворачивается, 1 → развернулся.
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = Curves.easeOutBack.transform(reveal.clamp(0, 1));

    // Орбита: едва заметная окружность, по которой расставлены варианты.
    canvas.drawCircle(
      layout.center,
      layout.orbit * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = LumenPalette.constellationLine.withValues(alpha: 0.12),
    );

    for (var i = 0; i < layout.count; i++) {
      _paintStar(canvas, i, scale);
    }

    _paintCenterStar(canvas, scale);
    _paintConnection(canvas);
  }

  void _paintStar(Canvas canvas, int index, double scale) {
    final position = layout.center +
        (layout.optionCenter(index) - layout.center) * scale;

    final Color color;
    var glow = 0.35;
    if (outcome != null && index == answerIndex) {
      color = LumenPalette.correct;
      glow = 0.9;
    } else if (outcome == CircleOutcome.wrong && index == chosen) {
      color = LumenPalette.wrong;
      glow = 0.8;
    } else if (index == hovered) {
      color = LumenPalette.starlight;
      glow = 0.7;
    } else {
      color = LumenPalette.constellationLine;
    }

    canvas.drawCircle(
      position,
      layout.optionRadius,
      Paint()
        ..color = color.withValues(alpha: glow * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      position,
      layout.optionRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = index == hovered ? 2 : 1
        ..color = color.withValues(alpha: glow),
    );
  }

  void _paintCenterStar(Canvas canvas, double scale) {
    canvas.drawCircle(
      layout.center,
      layout.centerRadius * scale,
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

    canvas.drawLine(layout.center, target, halo);
    canvas.drawLine(layout.center, target, line);
  }

  @override
  bool shouldRepaint(_ArenaPainter old) =>
      old.pointer != pointer ||
      old.hovered != hovered ||
      old.chosen != chosen ||
      old.outcome != outcome ||
      old.reveal != reveal ||
      old.layout.count != layout.count;
}
